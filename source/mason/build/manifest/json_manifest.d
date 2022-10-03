/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.manifest.json_manifest
 *
 * Human readable summary of build
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.manifest.json_manifest;

public import mason.build.manifest;

import std.stdio : File;
import std.conv : to;
import std.json;
import mason.build.context;
import std.array : join, array;
import std.algorithm : map, filter;
import std.range : empty;
import moss.deps.dependency : Provider, Dependency;

/**
 * JSON, write-only implementation of a BuildManifest
 */
final class BuildManifestJSON : BuildManifest
{

    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture) @safe
    {
        import std.string : format;
        import std.algorithm : substitute;

        /* i.e. manifest.x86_64 */
        fileName = "manifest.%s.jsonc".format(architecture.substitute!("/", "-"));

        /* Root values required in the manifest. */
        emissionNodes = [
            "manifest-version": "0.1",
            "source-name": buildContext.spec.source.name,
            "source-release": to!string(buildContext.spec.source.release),
            "source-version": to!string(buildContext.spec.source.versionIdentifier),
        ];

    }

    override void write() @trusted
    {
        import std.algorithm : substitute;

        auto targetPath = join([buildContext.outputDirectory, fileName], "/");
        auto fp = File(targetPath, "w");
        scope (exit)
        {
            fp.close();
        }

        fp.write("/** Human readable report. This is not consumed by boulder */\n");
        emissionNodes["packages"] = packageNodes;
        auto jsonEmission = emissionNodes.toJSON(true, JSONOptions.doNotEscapeSlashes);
        fp.write(jsonEmission.substitute!("    ", "\t"));
        fp.write("\n");
    }

    override void recordPackage(scope Package* pkg, scope AnalysisBucket bucket,
            scope LayoutPayload lp) @safe
    {
        JSONValue node;
        node["name"] = pkg.pd.name;
        node["files"] = lp.map!((r) { return join(["/usr", r.target], "/"); }).array;
        auto providers = bucket.providers.map!((p) => p.toString);
        if (!providers.empty)
        {
            node["provides"] = providers.array;
        }
        auto deps = bucket.dependencies.map!((d) => d.toString);
        if (!deps.empty)
        {
            node["depends"] = deps.array;
        }
        packageNodes[pkg.pd.name] = node;
    }

private:

    JSONValue emissionNodes;
    JSONValue[string] packageNodes;
}
