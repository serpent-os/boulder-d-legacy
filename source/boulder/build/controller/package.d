/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.build.controller;

import moss.core.download.store;
import moss.core.util : computeSHA256;
import moss.fetcher;
import boulder.build.builder;
import boulder.build.context;

import std.algorithm : each, filter;
import std.exception : enforce;
import std.file : exists, mkdirRecurse;
import std.path : dirName, absolutePath;
import std.string : format, endsWith;
import moss.format.source.spec;
import std.path : buildPath, baseName;
import std.parallelism : TaskPool, totalCPUs;

/**
 * The BuildController is responsible for the main execution cycle of Boulder,
 * and as such, the main entry point for actual builds. It should be noted that
 * as the build process can be one that hangs execution, it is run on a separate
 * thread.
 */
public final class BuildController
{

    /**
     * Construct a new BuildController
     */
    this()
    {
        /* bound to max 4 fetches, or 2 for everyone else. */
        fetchController = new FetchController(totalCPUs >= 4 ? 3 : 1);
        fetchController.onComplete.connect(&onComplete);

        downloadStore = new DownloadStore(StoreType.User);
    }

    void onComplete(in Fetchable f, long code)
    {
        import std.stdio : writefln;

        writefln!"Downloaded: %s"(f.sourceURI);
    }

    /**
     * Request that we begin building the given path
     */
    void build(const(string) path)
    {
        enforce(path.exists,
                "BuildController.build(): Cannot build %s as it does not exist".format(path));
        enforce(path.endsWith(".yml"),
                "BuildController.build(): Path does not look like a valid YML file: %s".format(
                    path));

        if (builder !is null)
        {
            builder.destroy();
        }

        /* Set up the new builder */
        auto s = new Spec(File(path, "r"));
        s.parse();

        buildContext.spec = s;
        buildContext.specDir = path.dirName.absolutePath;

        builder = new Builder();

        runTimed(&stageFetch, "Fetch");
        runTimed(&stagePrepare, "Prepare");
        runTimed(&stageBuild, "Build");
        runTimed(&stageAnalyse, "Analyse");
        runTimed(&stageEmit, "Emit packages");
        runTimed(&stageManifest, "Emit manifest");
    }

    /**
     * Run preparation for the package
     */
    void stagePrepare()
    {
        builder.prepareRoot();
        builder.preparePkgFiles();
        promoteSources();
    }

    /**
     * Fetch upstreams for the package
     */
    void stageFetch()
    {
        fetchUpstreams();
    }

    /**
     * Build the package profiles
     */
    void stageBuild()
    {
        running = builder.buildProfiles();
    }

    /**
     * Analyse + collect
     */
    void stageAnalyse()
    {
        builder.collectAssets();
    }

    /**
     * Emit packages
     */
    void stageEmit()
    {
        builder.emitPackages();
    }

    /**
     * Product manifest files
     */
    void stageManifest()
    {
        builder.produceManifests();
    }

private:

    void runTimed(void delegate() dg, in string label)
    {
        import std.datetime.stopwatch : StopWatch, AutoStart;
        import std.stdio : writefln;

        if (!running)
        {
            return;
        }

        auto sw = StopWatch(AutoStart.yes);
        dg();
        writefln("[%s] Finished: %s", label, sw.peek);
    }

    /**
     * Fetch all upstreams
     */
    void fetchUpstreams()
    {
        auto upstreams = buildContext.spec.upstreams.values;
        if (upstreams.length < 1)
        {
            return;
        }

        Fetchable[] failedDownloads;

        /**
         * Validate the checksum!
         */
        void validateChecksum(immutable(Fetchable) fe, long statusCode)
        {
            if (statusCode != 200)
            {
                synchronized (this)
                {
                    failedDownloads ~= fe;
                }
                return;
            }

            auto inpHash = computeSHA256(fe.destinationPath, true);
            auto expectedHash = upstreams.filter!((u) => u.uri == fe.sourceURI).front;
            if (inpHash != expectedHash.plain.hash)
            {
                synchronized (this)
                {
                    failedDownloads ~= fe;
                }
            }
        }

        upstreams.filter!((u) => u.type == UpstreamType.Plain)
            .each!((u) {
                const auto finalPath = downloadStore.fullPath(u.plain.hash);
                auto pathDir = finalPath.dirName;
                pathDir.mkdirRecurse();
                auto fb = Fetchable(u.uri, finalPath, 0,
                    FetchType.RegularFile, &validateChecksum);
                fetchController.enqueue(fb);
            });

        while (!fetchController.empty)
        {
            fetchController.fetch();
        }

        enforce(failedDownloads.length == 0, "One or more downloads have failed");
    }

    /**
     * Promote sources to where they need to be
     */
    void promoteSources()
    {
        foreach (upstream; buildContext.spec.upstreams.values)
        {
            if (upstream.type != UpstreamType.Plain)
            {
                continue;
            }

            auto partName = upstream.plain.rename !is null
                ? upstream.plain.rename : upstream.uri.baseName;
            string fullname = buildContext.sourceDir.buildPath(partName);
            auto dn = fullname.dirName;
            dn.mkdirRecurse();
            downloadStore.share(upstream.plain.hash, fullname);
        }
    }

    /**
     * Block and fetch the given upstream definition
     */
    bool fetchUpstream(in UpstreamDefinition upstream)
    {
        import std.net.curl : download;

        if (upstream.type != UpstreamType.Plain)
        {
            return false;
        }

        if (downloadStore.contains(upstream.plain.hash))
        {
            return true;
        }

        const auto finalPath = downloadStore.fullPath(upstream.plain.hash);
        auto pathDir = finalPath.dirName;
        pathDir.mkdirRecurse();
        import std.stdio : writefln;

        writefln("Downloading '%s' to '%s'", upstream.uri, finalPath);
        download(upstream.uri, finalPath);
        return true;
    }

    DownloadStore downloadStore = null;
    FetchController fetchController = null;
    Builder builder = null;
    bool running = true;
}
