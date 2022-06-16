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
import std.uni : isWhite;
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

/**
 * Don't scan past this length in any file.
 */
private auto MaxScanLength = 600;

static private AnalysisReturn scanLicenseFile(scope Analyser an, ref FileInfo fi)
{
    import std.file : read;
    import std.string : replace;

    if (fi.type != FileType.Regular)
    {
        return AnalysisReturn.NextHandler;
    }

    auto dr = an.userdata!Drafter;
    auto bn = fi.path.baseName.toLower;
    if (bn.startsWith("copying") || bn.startsWith("license") || bn.startsWith("licence"))
    {
        string text = cast(string) fi.fullPath.read();
        if (text.length > MaxScanLength)
        {
            text = text[0 .. MaxScanLength];
        }
        text = text.toLower.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "");
        tracef("Detected license for %s: %s", fi.path, dr.licenseEngine.checkLicense(text));
    }
    return AnalysisReturn.NextHandler;
}

public static AnalysisChain licenseChain = AnalysisChain("licenseFiles", [
        &scanLicenseFile
        ], 10);

private struct LicenseResult
{
    string id;
    double confidence;
}

/**
 * Load SPDX license data from disk
 */
static private License* loadLicense(DirEntry entry)
{
    import std.file : read;
    import std.string : replace;

    string text = cast(string) entry.name.read();
    if (text.length > MaxScanLength)
    {
        text = text[0 .. MaxScanLength];
    }
    import std.string : replace;

    text = text.toLower.replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "");
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
        trace("done");
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
            //tracef("Comparison to %s: %g", comp.identifier, ratio);
        }
        return LicenseResult(id, record);
    }

private:

    License*[] licenses;
}
