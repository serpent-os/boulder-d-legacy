/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.upstreamcache
 *
 * Path mangling for retention of sources
 *
 * TODO: Rename module to boulder.upstream_cache
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.upstreamcache;

import std.array : join;
import std.conv : to;
import std.exception : enforce;
import std.experimental.logger;
import std.file : exists, mkdirRecurse, rename;
import std.path : dirName, pathSplitter;
import std.process : environment;
import std.string : format;
import std.sumtype : tryMatch;
public import moss.format.source.upstream_definition;

import moss.core.ioutil;

/**
 * Base of all directories
 */
public string sharedRootUpstreamsCache()
{
    auto cacheDir = environment.get("XDG_CACHE_HOME", environment.get("HOME") ~ "/.cache");
    return cacheDir ~ "/boulder/upstreams";
}

/**
 * The UpstreamCache provides persistent paths and
 * deduplication facilities to permit retention of
 * hash-indexed downloads across multiple builds.
 */
public final class UpstreamCache
{

    /**
     * Only allow Boulder to construct us.
     */
    package this()
    {

    }

    /**
     * Construct all required directories
     */
    void constructDirs()
    {
        auto paths = [
            sharedRootUpstreamsCache(), stagingDirectory(), gitDirectory(),
            plainDirectory()
        ];
        foreach (p; paths)
        {
            p.mkdirRecurse();
        }
    }

    /**
     * Returns: True if the final destination exists
     */
    bool contains(in UpstreamDefinition def) @safe
    {
        return finalPath(def).exists;
    }

    /**
     *  Promote from staging to real. This is where Git sources fetch their
     *  submodules.
     */
    void promote(in UpstreamDefinition def) @safe
    {
        import std.process;

        enforce(def.type == UpstreamType.Plain || def.type == UpstreamType.Git,
            "UpstreamCache: only plain and git types are supported");

        auto st = stagingPath(def);
        auto fp = finalPath(def);

        if (def.type == UpstreamType.Plain || (()@trusted => def.git.staging)())
        {
            enforce(st.exists,
                format!"UpstreamCache.promote(): staging path %s does not exist"(st));
        }

        auto dirn = fp.dirName;
        if (!dirn.exists)
        {
            dirn.mkdirRecurse();
        }

        final switch (def.type)
        {
        case UpstreamType.Plain:
            /* Move from staging path to final path */
            st.rename(fp);
            break;
        case UpstreamType.Git:
            /**
             * Clone the repository from staging path to final path. Check out
             * the desired ref. Then, fetch submodules recursively.
             */

            string refID = (() @trusted => def.git.refID)();

            string[string] env;
            string workdir = fp;
            if (!fp.exists)
            {
                auto cmd = ["git", "clone", "--", st, fp];
                debug
                {
                    trace(cmd);
                }
                auto clone = spawnProcess(cmd, env, Config.none);
                int exitCode = clone.wait();
                enforce(exitCode == 0,
                    format!"Failed to clone git source from staging path %s to final path %s"(st,
                        fp));
            }
            else
            {
                /* 
                 * If we enabled staging, logically this should always be false.
                 * We would've called resetToRef in fetch-upstream already and
                 * skipped promoting if we checked that the ref already existed
                 * in final path.
                 */
                debug enforce(!(() @trusted => def.git.staging)() || !refExists(def,
                        refID), "Repo shouldn't contain the ref according to branching");

                trace(format!"Ref %s doesn't exist in the repository clone in final path. Fetching new refs from local upstream in staging path"(
                        refID));

                auto fetch = spawnProcess(["git", "fetch",], env, Config.none, workdir);
                int exitCode = fetch.wait();
                enforce(exitCode == 0,
                    format!"Failed to fetch more refs from local upstream in staging path %s to final path %s"(st,
                        fp));
                enforce(refExists(def, refID),
                    format!"Ref %s still doesn't exist in the repository clone in final path %s"(fp,
                        refID));
            }

            resetToRef(def, refID);

            break;
        }
    }

    /**
     * Reset the non-bare Git repository in def's **final path** to the
     * requested ref.
     *
     * Note that its submodules will also be fetched and checked out to their
     * corresponding ref.
     *
     * For obvious reasons, def must be a Git upstream.
     */
    void resetToRef(in UpstreamDefinition def, in string refID) @safe
    {
        import std.process;

        enforce(def.type == UpstreamType.Git,
            "UpstreamCache.resetToRef: only supports Git upstreams!");

        string[string] env;
        string workdir = finalPath(def);

        auto cmd = ["git", "reset", "--hard", refID,];
        auto checkOut = spawnProcess(cmd, env, Config.none, workdir);
        int exitCode = checkOut.wait();
        enforce(exitCode == 0, format!"Failed to reset to requested git ref %s"(refID));

        auto submodules = spawnProcess([
            "git", "submodule", "update", "--init", "--recursive", "--depth",
            "1", "--jobs", "4",
        ], env, Config.none, workdir);
        exitCode = submodules.wait();
        enforce(exitCode == 0, "Failed to fetch/checkout submodules");
    }

    /**
     * Given an UpstreamDefinition and a Git ref, check if the ref is present in
     * the upstream source's clone in the **final path**. Always returns false
     * if the source's final path doesn't exist.
     *
     * Note that it does not actually verify that ref exists as a commit. It
     * only verifies that there is an object in the database corresponding to
     * the SHA1 provided. However, it's enough for our purposes, since
     * oftentimes we specify the git tag anyway.
     */
    bool refExists(in UpstreamDefinition def, in string refID) @safe
    {
        enforce(def.type == UpstreamType.Git,
            "UpstreamCache.refExists: Only Git upstreams can query ref existence");

        import std.process;

        auto fp = finalPath(def);

        if (!fp.exists)
        {
            return false;
        }

        string[string] env;
        auto verify = spawnProcess(["git", "cat-file", "-e", refID,], env, Config.none, fp,);
        return verify.wait() == 0;
    }

    /**
     * Promote the shared upstream into a target tree using hardlink or copy.
     */
    void share(in UpstreamDefinition def, in string destPath) ///FIXME: @safe
    {
        enforce(def.type == UpstreamType.Plain || def.type == UpstreamType.Git,
            "UpstreamCache: only plain and git types are supported");

        auto fp = finalPath(def);

        debug
        {
            trace(format!"Sharing from %s to %s"(fp, destPath));
        }

        try
        {
            final switch (def.type)
            {
            case UpstreamType.Plain:
                auto res = IOUtil.hardlinkOrCopy(fp, destPath);
                /// FIXME: res.tryMatch!((bool b) => b);
                break;
            case UpstreamType.Git:
                copyDir(fp, destPath);
                break;
            }
        }
        catch (Exception e)
        {
            error(e);
        }
    }

    /**
     * Return the staging path for the definition
     */
    const(string) stagingPath(in UpstreamDefinition def) @trusted
    {
        import std.path : pathSplitter, buildNormalizedPath;

        enforce(def.type == UpstreamType.Plain || def.type == UpstreamType.Git,
            "UpstreamCache: only plain and git types are supported");

        final switch (def.type)
        {
        case UpstreamType.Plain:
            enforce(def.plain.hash.length >= 5,
                "UpstreamCache: Hash too short: " ~ to!string(def.plain));
            return join([stagingDirectory(), def.plain.hash], "/");
        case UpstreamType.Git:
            return join([stagingDirectory(), "git",
                    normalizedUriPath(def.uri)], "/");
        }
    }

    /**
     * Return the final path for the definition
     */
    const(string) finalPath(in UpstreamDefinition def) @trusted
    {
        import std.path;
        import std.algorithm.searching : startsWith;

        enforce(def.type == UpstreamType.Plain || def.type == UpstreamType.Git,
            "UpstreamCache: only plain and git types are supported");

        final switch (def.type)
        {
        case UpstreamType.Plain:
            enforce(def.plain.hash.length >= 5,
                "UpstreamCache: Hash too short: " ~ to!string(def.plain));

            return join([
                plainDirectory(), def.plain.hash[0 .. 5], def.plain.hash[5 .. $],
                def.plain.hash
            ], "/");
        case UpstreamType.Git:
            string path = join([gitDirectory(), normalizedUriPath(def.uri)], "/");

            /* A very simple check to prevent path escaping */
            enforce(!path.asRelativePath(gitDirectory()).startsWith(".."),
                "Path escaping in Git URI may be possible");

            return path;
        }
    }

private:
    /**
     * Staging downloads that might be wonky.
     */
    string stagingDirectory()
    {
        return join([sharedRootUpstreamsCache(), "staging"], "/");
    }

    /**
     * Git clones
     */
    string gitDirectory()
    {
        return join([sharedRootUpstreamsCache(), "git",], "/");
    }

    /**
     * Plain downloads
     */
    string plainDirectory()
    {
        return join([sharedRootUpstreamsCache(), "fetched"], "/");
    }

    /**
     * Converts and normalizes a URI (in our use case, an HTTP(S) Git remote
     * url) to a valid path.
     */
    static string normalizedUriPath(string uri) @safe pure
    {
        import std.uri;
        import std.array;
        import std.path : pathSplitter;

        auto len = uriLength(uri);
        enforce(len > -1, "Upstream is not a valid HTTP Git URI");

        /* In case someone enters a evil url that may destroy the upstream
         * caches, we only use the substring that is verified to be an
         * URI
         */
        auto splitted = pathSplitter(uri).array();
        return join(splitted[1 .. $], "/");
    }

    @safe pure unittest
    {

        assert(normalizedUriPath(
                "https://github.com/serpent-os/moss.git") == "github.com/serpent-os/moss.git");
    }

    /**
     * Copies the contents of directory inDir to the destination directory
     * outDir.
     *
     * Hopefully in the future, we can move this to IOUtil in moss-core. It's
     * currently put here because I don't want to pollute IOUtil with high-level
     * code.
     */
    void copyDir(string inDir, string outDir)
    {
        import std.array : array;
        import std.file;
        import std.path;
        import std.parallelism : parallel;
        import std.typecons : Yes;

        if (!exists(outDir))
        {
            mkdir(outDir);
        }
        else
        {
            enforce(outDir.isDir, format!"Destination path %s is not a folder."(outDir));
        }

        foreach (entry; parallel(dirEntries(inDir, SpanMode.shallow, false).array))
        {
            auto fileName = baseName(entry.name);
            auto destName = buildPath(outDir, fileName);
            if (entry.isDir())
            {
                copyDir(entry.name, destName);
            }
            else if (entry.isSymlink) /* Safer to handle symlinks manually */
            {
                symlink(readLink(entry.name), destName);
            }
            else /* File */
            {
                copy(entry.name, destName, Yes.preserveAttributes);
            }
        }
    }
}
