/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
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
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module boulder.upstreamcache;

import moss.core.ioutil;
import std.exception : enforce;
import std.experimental.logger;
import std.conv : to;
import std.path : dirName;
import std.file : exists, mkdirRecurse, rename;
import std.string : format;
import std.array : join;
public import moss.format.source.upstream_definition;
import std.sumtype : tryMatch;

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
            rootDirectory, stagingDirectory, gitDirectory, plainDirectory
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
     *  Promote from staging to real
     */
    void promote(in UpstreamDefinition def) @safe
    {
        auto st = stagingPath(def);
        auto fp = finalPath(def);
        enforce(def.type == UpstreamType.Plain, "UpstreamCache: git not yet supported");
        enforce(st.exists, "UpstreamCache.promote(): %s does not exist".format(st));

        /* Move from staging path to final path */
        auto dirn = fp.dirName;
        dirn.mkdirRecurse();
        st.rename(fp);
    }

    /**
     * Promote the shared upstream into a target tree using hardlink or copy.
     */
    void share(in UpstreamDefinition def, in string destPath) ///FIXME: @safe
    {
        auto fp = finalPath(def);
        enforce(def.type == UpstreamType.Plain, "UpstreamCache: git not yet supported");

        try
        {
            auto res = IOUtil.hardlinkOrCopy(fp, destPath);
            /// FIXME: res.tryMatch!((bool b) => b);
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
        enforce(def.type == UpstreamType.Plain, "UpstreamCache: git not yet supported");
        enforce(def.plain.hash.length >= 5,
                "UpstreamCache: Hash too short: " ~ to!string(def.plain));
        return join([stagingDirectory, def.plain.hash], "/");
    }

    /**
     * Return the final path for the definition
     */
    const(string) finalPath(in UpstreamDefinition def) @trusted
    {
        enforce(def.type == UpstreamType.Plain, "UpstreamCache: git not yet supported");
        enforce(def.plain.hash.length >= 5,
                "UpstreamCache: Hash too short: " ~ to!string(def.plain));

        return join([
            plainDirectory, def.plain.hash[0 .. 5], def.plain.hash[5 .. $],
            def.plain.hash
        ], "/");
    }

private:

    /**
     * Base of all directories
     */
    static immutable(string) rootDirectory = "/var/cache/boulder/upstreams";

    /**
     * Staging downloads that might be wonky.
     */
    static immutable(string) stagingDirectory = join([rootDirectory, "staging"], "/");

    /**
     * Git clones
     */
    static immutable(string) gitDirectory = join([rootDirectory, "git"], "/");

    /**
     * Plain downloads
     */
    static immutable(string) plainDirectory = join([rootDirectory, "fetched"], "/");
}
