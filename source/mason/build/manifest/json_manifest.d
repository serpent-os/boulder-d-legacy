/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.manifest.json_manifest
 *
 * Human readable summary of build
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.manifest.json_manifest;

public import mason.build.manifest;

import mason.build.context;
import moss.deps.dependency : Provider, Dependency;
import std.algorithm : filter, map, sort, substitute, uniq;
import std.array : join, array;
import std.conv : to;
import std.format : format;
import std.json;
import std.range : empty;
import std.stdio : File;

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
        /* i.e. manifest.x86_64 */
        fileName = "manifest.%s.jsonc".format(architecture.substitute!("/", "-"));

        /* Root values required in the manifest. */
        emissionNodes = [
            "manifest-version": "0.2",
            "source-name": buildContext.spec.source.name,
            "source-release": to!string(buildContext.spec.source.release),
            "source-version": to!string(buildContext.spec.source.versionIdentifier),
        ];
        /// TODO: Add "build-version":
    }

    override void write() @trusted
    {
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
        auto buildDeps = buildContext.spec.rootBuild.buildDependencies
            ~ buildContext.spec.rootBuild.checkDependencies;
        buildDeps.sort();
        buildDeps = buildDeps.uniq.array;
        if (!buildDeps.empty)
        {
            node["build-depends"] = buildDeps;
        }
        packageNodes[pkg.pd.name] = node;
    }

private:

    JSONValue emissionNodes;
    JSONValue[string] packageNodes;
}
