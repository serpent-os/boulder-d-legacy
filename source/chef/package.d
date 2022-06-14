/* SPDX-License-Identifier: Zlib */

/**
 * Chef - Recipe Manipulation
 *
 * Generation and manipulation of source recipe files that can then be consumed
 * by boulder.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module chef;

import std.sumtype;
import moss.core.ioutil;
import moss.core.util : computeSHA256;
import moss.fetcher;
import moss.deps.analysis;
import std.exception : enforce;
import std.path : baseName;
import std.range : empty;
import moss.core.logging;
import std.process;
import chef.metadata;

public import moss.format.source.upstream_definition;

/** 
 * Map our downloads into something *usable* so we can remember
 * things about it.
 */
private struct RemoteAsset
{
    string sourceURI;
    string localPath;
}

/**
 * We really don't care about the vast majority of files.
 */
static private AnalysisReturn silentDrop(scope Analyser an, ref FileInfo info)
{
    return AnalysisReturn.IgnoreFile;
}

/**
 * Main class for analysis of incoming sources to generate an output recipe
 */
public final class Chef
{
    /**
     * Construct a new Chef
     */
    this()
    {
        controller = new FetchController();
        analyser = new Analyser();
        analyser.addChain(AnalysisChain("drop", [&silentDrop], 0));
        controller.onFail.connect(&onFail);
        controller.onComplete.connect(&onComplete);
    }

    /**
     * Dull handler for failure
     */
    void onFail(in Fetchable f, in string msg)
    {
        errorf("Failed to download %s: %s", f.sourceURI, msg);
        fetchedDownloads = false;
    }

    /**
     * Handle completion of downloads, validate them
     */
    void onComplete(in Fetchable f, long code)
    {
        tracef("Download of %s finished [code: %s]", f.sourceURI.baseName, code);

        if (code == 200)
        {
            processPaths ~= RemoteAsset(f.sourceURI, f.destinationPath);
            infof("Downloaded: %s", f.destinationPath);
            return;
        }
        onFail(f, "Server returned non-200 status code");
    }

    /**
     * Run Chef lifecycle to completion
     */
    void run()
    {
        info("Beginning download");

        scope (exit)
        {
            import std.file : remove, rmdirRecurse;
            import std.algorithm : each;

            processPaths.each!((p) {
                tracef("Removing: %s", p.localPath);
                p.localPath.remove();
            });
            directories.each!((d) { tracef("Removing: %s", d); d.rmdirRecurse(); });
        }

        while (!controller.empty)
        {
            controller.fetch();
        }

        if (!fetchedDownloads)
        {
            error("Exiting due to abnormal downloads");
            return;
        }

        if (processPaths.empty)
        {
            error("Nothing for us to process, exiting");
            return;
        }

        exploreAssets();
        info("Analysing source trees");
        analyser.process();

        trace(meta);
    }

    /**
     * Add some kind of input URI into chef for ... analysing
     */
    void addSource(string uri, UpstreamType type = UpstreamType.Plain)
    {
        enforce(type == UpstreamType.Plain, "Chef only supports plain sources");
        auto f = Fetchable(uri, "/tmp/boulderChefURI-XXXXXX", 0, FetchType.TemporaryFile, null);
        controller.enqueue(f);
    }

private:

    void exploreAssets()
    {
        import std.file : dirEntries, SpanMode;
        import std.path : relativePath;

        foreach (const p; processPaths)
        {
            infof("Extracting: %s", p.localPath);
            auto location = IOUtil.createTemporaryDirectory("/tmp/boulderChefExtraction.XXXXXX");
            auto directory = location.match!((string s) => s, (err) {
                errorf("Error creating tmpdir: %s", err.toString);
                return null;
            });
            if (directory is null)
            {
                return;
            }
            directories ~= directory;

            /* Capture an upstream definition */
            infof("Computing hash for %s", p.localPath);
            auto hash = computeSHA256(p.localPath, true);
            auto ud = UpstreamDefinition(UpstreamType.Plain);
            ud.plain = PlainUpstreamDefinition(hash);
            ud.uri = p.sourceURI;
            meta.upstreams ~= ud;

            /* Attempt extraction. For now, we assume everything is a tarball */
            auto cmd = ["tar", "xf", p.localPath, "-C", directory,];

            /* Perform the extraction now */
            auto result = execute(cmd, null, Config.none, size_t.max, directory);
            if (result.status != 0)
            {
                errorf("Extraction of %s failed with code %s", p.localPath, result.status);
                trace(result.output);
            }

            infof("Scanning sources under %s", directory);
            foreach (string path; dirEntries(directory, SpanMode.depth, false))
            {
                auto fi = FileInfo(path.relativePath(directory), path);
                fi.target = p.sourceURI.baseName;
                analyser.addFile(fi);
            }
        }
    }

    FetchController controller;
    Analyser analyser;
    RemoteAsset[] processPaths;
    string[] directories;
    bool fetchedDownloads = true;
    Metadata meta;
}
