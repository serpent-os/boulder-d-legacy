/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Module Name (use e.g. 'moss.core.foo.bar')
 *
 * Module Description (FIXME)
 *
 * In package.d files containing only imports and nothing else,
 * 'Module namespace imports.' is sufficient description.
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
import std.array : join;

/**
 * JSON, write-only implementation of a BuildManifest
 */
final class BuildManifestJSON : BuildManifest
{

    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture)
    {
        import std.string : format;
        import std.algorithm : substitute;

        /* i.e. manifest.x86_64 */
        fileName = "manifest.%s.json".format(architecture.substitute!("/", "-"));

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

    /**
     * Emit a package as a JSON node to the manifest
     */
    override void recordPackage(const(string) pkgName, ref FileInfo[] fileSet)
    {
        import std.algorithm : map;
        import std.array : array;

        const JSONValue fileSetMapped = fileSet.map!((m) => m.path).array;
        JSONValue newPkg;
        newPkg["files"] = fileSetMapped;
        packageNodes[pkgName] = newPkg;
    }

private:

    JSONValue emissionNodes;
    JSONValue[string] packageNodes;
}
