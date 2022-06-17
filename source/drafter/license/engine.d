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
private static enum MaxScanLength = 500;

/**
 * Bake the licenses directly into the binary
 */
static private auto buildLicenses()
{
    License[] licensesRet;

    import std.string : splitLines;
    import std.path : baseName;

    enum licenseFiles = import("licenses.list").splitLines();
    pragma(msg, "Begin baking licenses..");
    static foreach (l; licenseFiles)
    {
        {
            enum licenseText = import(l).byCodePoint
                    .filter!((c) => c.isAlphaNum)
                    .map!((c) => c.toLower)
                    .take(MaxScanLength)
                    .to!string;
            /* Remove .txt suffix, etc. */
            enum licenseName = l.baseName[0 .. $ - 4];
            enum tmpLicense = License(licenseName, licenseText, false);
            licensesRet ~= tmpLicense;
        }
    }

    return licensesRet;
}

__gshared private License[] builtinLicenses;

shared static this()
{
    builtinLicenses = buildLicenses();
}

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
        .take(MaxScanLength)
        .to!string;
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
 * Licensing engine performs preloading and computation of
 * license specifics.
 */
public final class Engine
{

    static struct ContextWrap
    {
        License l;
        string input;
    }

    /**
     * Find out what license this is.
     */
    static auto checkLicense(in string transformedInput)
    {
        import std.parallelism : parallel;
        import std.algorithm : maxElement, map;

        auto resultsIn = builtinLicenses.map!((l) => ContextWrap(l, transformedInput));
        auto results = taskPool.amap!findMatch(resultsIn);
        return results.maxElement!((e) => e.confidence);
    }

    static LicenseResult findMatch(in ContextWrap t)
    {
        import std.algorithm : levenshteinDistance;

        auto reference = t.l;
        auto input = t.input;

        auto distance = reference.textBody.levenshteinDistance(input);
        auto lensum = cast(double)(reference.textBody.length + input.length);
        double ratio = 1.0;
        if (lensum != 0)
        {
            ratio = (cast(double)(lensum - distance)) / lensum;
        }
        return LicenseResult(reference.identifier, ratio);
    }
}
