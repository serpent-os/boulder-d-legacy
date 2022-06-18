/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - License engine
 *
 * Preloading and comparison of licenses
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.license.engine;

import std.exception : enforce;
import std.file : dirEntries, SpanMode, exists, DirEntry;
import std.path : baseName;
import std.algorithm : map, filter, each;
import std.uni : isAlphaNum, byCodePoint;
import std.array : array;
import std.string : startsWith, toLower;
import std.experimental.logger;
import std.parallelism : taskPool;
import drafter : Drafter;
import drafter.license : License;
import std.mmfile;
import std.container.rbtree;
import moss.deps.analysis;
import std.conv : to;
import std.range : take;

/**
 * Don't scan past this length in any file.
 */
private auto MaxScanLength = 500;

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
        .take(MaxScanLength).to!string;
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
    if (bn.startsWith("copying") || bn.startsWith("license") || bn.startsWith("licence"))
    {
        tracef("Analysing license: %s", fi.path);
        string text = sanitizeLicense(fi.fullPath);
        auto detectedLicense = dr.licenseEngine.checkLicense(text);
        tracef("License of %s: %s (Confidence: %.2f)", fi.path,
                detectedLicense.id, detectedLicense.confidence);
    }
    return AnalysisReturn.NextHandler;
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
static private License* loadLicense(DirEntry entry)
{
    string text = sanitizeLicense(entry.name);
    auto bn = entry.name.baseName;
    auto licenseName = bn[0 .. $ - 4];
    return new License(licenseName, text, false);
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
        enforce(directory.exists);
        trace("Preloading license data");

        auto entries = dirEntries(directory, "*.txt", SpanMode.shallow, false).array;
        auto data = taskPool.amap!loadLicense(entries);
        data.each!((d) => licenses ~= d);
    }

    /**
     * Find out what license this is.
     */
    const LicenseResult checkLicense(in string transformedInput)
    {
        import std.algorithm : levenshteinDistance;
        import std.parallelism : parallel;

        double record = 0.0;
        string id = null;
        foreach (comp; licenses.parallel)
        {
            auto distance = comp.textBody.levenshteinDistance(transformedInput);
            auto lensum = cast(double)(comp.textBody.length + transformedInput.length);
            double ratio = 1.0;
            if (lensum != 0)
            {
                ratio = (cast(double)(lensum - distance)) / lensum;
            }
            if (ratio > record)
            {
                record = ratio;
                id = comp.identifier;
            }
        }
        return LicenseResult(id, record);
    }

private:

    License*[] licenses;
}
