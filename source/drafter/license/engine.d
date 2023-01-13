/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * drafter.license.engine
 *
 * License detection engine
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module drafter.license.engine;

import drafter : Drafter;
import drafter.license : License;
import moss.deps.analysis;
import std.algorithm : each, filter, map, mean, multiSort;
import std.array : array, split, join;
import std.container.rbtree;
import std.conv : to;
import std.exception : enforce;
import std.experimental.logger;
import std.file : dirEntries, DirEntry, exists, SpanMode;
import std.mmfile;
import std.parallelism : taskPool;
import std.path : baseName, dirName;
import std.range : take, chunks, zip, lockstep, Take, empty, front, enumerate;
import std.string : startsWith, toLower, endsWith, format;
import std.uni : byCodePoint, isAlphaNum;

/**
 * Minimum confidence level is 88%
 */
static private enum ConfidenceLimit = 0.88;

static private enum MaxReadSize = 1800;

/**
 * Anything under 350 characters is likely bullshit
 */
static private enum MinimumScanThreshold = 350;

/**
 * This helper sanitizes license texts for proper comparison.
 *
 * We iterate the unicode input and drop anything that isn't an
 * alphanumeric codepoint, convert to lower case and allow a
 * maximum comparison length of 500 characters.
 *
 * This allows the bulk of the license to be compared and yield
 * a high level of confidence.
 */
static private string sanitizeLicense(in string path)
{
    scope auto mmapped = new MmFile(path);
    auto rawData = cast(ubyte[]) mmapped[0 .. $];
    auto wideString = cast(string) rawData;
    return wideString.byCodePoint
        .filter!((c) => c.isAlphaNum)
        .map!((c) => c.toLower)
        .take(MaxReadSize).to!string;
}

/**
 * Much like our initial license loader
 *
 * We convert the input data into some usable text for comparison
 * and dispatch to our check function
 */
static private AnalysisReturn scanLicenseFile(scope Analyser an, ref FileInfo fi)
{
    if (fi.type != FileType.Regular)
    {
        return AnalysisReturn.NextHandler;
    }

    auto dr = an.userdata!Drafter;
    auto bn = fi.path.baseName.toLower;
    /**
     * copying\.?.*
     * license\.?.*
     */
    static bool isTraditionalLicense(in string licensePath)
    {
        immutable auto bn = licensePath.baseName.toLower;
        return bn.startsWith("copying") || bn.startsWith("license") || bn.startsWith("licence");
    }

    /**
     * REUSE compliance?
     */
    static bool isREUSE(in string licensePath)
    {
        immutable auto bn = licensePath.baseName.toLower;
        auto dd = licensePath.dirName.baseName.toLower;
        return dd == "licenses" && bn.endsWith(".txt");
    }

    if (!isTraditionalLicense(fi.fullPath) && !isREUSE(fi.fullPath))
    {
        return AnalysisReturn.NextHandler;
    }

    string text = sanitizeLicense(fi.fullPath);
    if (text.length < MinimumScanThreshold)
    {
        return AnalysisReturn.NextHandler;
    }

    auto detectedLicenses = dr.licenseEngine.checkLicenses(bn, text)
        .filter!((l) => l.confidence >= ConfidenceLimit).array;
    /* HAX: Ensure "or-later" is before "only" (compliance) */
    detectedLicenses.multiSort!("a.confidence > b.confidence", "a.id > b.id");
    if (detectedLicenses.empty)
    {
        warningf("Unknown license for: %s", fi.path);
        return AnalysisReturn.NextHandler;
    }
    auto top = detectedLicenses.front;
    tracef("[LICENSE] %s: %s (Confidence: %.2f)", fi.path, top.id, top.confidence);
    dr.insertLicense(top.id);
    return AnalysisReturn.IncludeFile;
}

/**
 * Incorporate licenseChain into analyzer to gain automatic license scanning
 */
public static AnalysisChain licenseChain = AnalysisChain("licenseFiles", [
        &scanLicenseFile
        ], 10);

/**
 * Used internally as a return type for license matching
 */
private struct LicenseResult
{
    /* SPDX Identifier */
    string id;

    /* How confident are we in this? */
    double confidence;
}

/**
 * Load SPDX license data from disk
 */
private static void loadLicense(DirEntry entry, License* l)
{
    string text = sanitizeLicense(entry.name);
    auto bn = entry.name.baseName;
    auto licenseName = bn[0 .. $ - 4];
    *l = License(licenseName, text, false);
}

/**
 * Licensing engine performs preloading and computation of
 * license specifics.
 */
public final class Engine
{

    /**
     * Preload all of our licenses
     */
    void loadFromDirectory(in string directory)
    {
        enforce(directory.exists, format!"Directory '%s' does not appear to exist?"(directory));
        trace("Preloading license data");

        /* Deliberately do NOT load deprecated licenses! */
        auto entries = dirEntries(directory, "*.txt", SpanMode.shallow, false).filter!(
                (o) => !o.name.baseName.startsWith("deprecated_")).array;
        licenses.reserve(entries.length);
        licenses.length = entries.length;
        ulong idx = 0;
        foreach (entry; entries)
        {
            License* l = &licenses[idx];
            loadLicense(entry, l);
            idx++;
        }
    }

    /**
     * Find out what license this is.
     */
    LicenseResult[] checkLicenses(in string path, in string transformedInput)
    {
        import std.parallelism : taskPool;

        /* If we hae COPYING.$SPDX, use the id up front. */
        auto ppath = path.baseName.toLower;
        auto splits = ppath.split(".").array;

        /* If we have a .SUFFIX, check it */
        if (splits.length > 1)
        {
            auto nom = splits[1];
            auto matchingLicenses = licenses.filter!((m) => m.identifier.toLower == nom)
                .map!((l) => LicenseResult(l.identifier, 1.0));
            if (!matchingLicenses.empty)
            {
                return matchingLicenses.array;
            }
        }

        /* Do we have a valid match for the first field ($SPDX.txt) ? (i.e. REUSE) */
        const auto baseToSuffix = join(splits.length > 1 ? splits[0 .. $ - 1] : [
                splits[0]
                ], ".");
        auto identicalIDs = licenses.filter!((m) => m.identifier.toLower == baseToSuffix);
        if (!identicalIDs.empty)
        {
            return identicalIDs.map!((m) => LicenseResult(m.identifier, 1.0)).array;
        }

        /* Map to eliminate dual context limitation in LDC */
        auto matchers = licenses.enumerate.map!((tup) => MatchContext(&licenses[tup.index],
                transformedInput));

        /* Match all licenses in parallel, return as LicenseResult */
        return taskPool.amap!computeLeven(matchers).array;
    }

private:

    /**
     * Compute the levenshtein difference for two input string ranges
     *
     * Params:
     *      r1 = First range
     *      r2 = Second range
     * Returns: Clamped double (0.0-1.0) for similarity
     */
    static double levenCount(Take!string r1, Take!string r2)
    {
        import std.algorithm : levenshteinDistance;

        immutable double distance = r1.levenshteinDistance(r2);
        immutable double lenSum = r1.maxLength + r2.maxLength;
        return (lenSum - distance) / lenSum;
    }

    /**
     * Main entry into levenshtein diff calculation pre chunk
     *
     * Params:
     *      context = Matching context
     * Returns: License result
     */
    static LicenseResult computeLeven(MatchContext context)
    {
        static enum ChunkSize = 600;

        double[] chunkCounts;
        context.license.textBody.chunks(ChunkSize)
            .lockstep(context.input.chunks(ChunkSize)).each!((a,
                    b) => chunkCounts ~= levenCount(a, b));
        auto avg = mean!double(chunkCounts);
        return LicenseResult(context.license.identifier, avg);
    }

    static struct MatchContext
    {
        License* license;
        string input;
    }

    License[] licenses;
}
