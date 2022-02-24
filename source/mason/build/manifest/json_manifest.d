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
