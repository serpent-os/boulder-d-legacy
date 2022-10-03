/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Mmoss.build.manifest
 *
 * Defines a BuildManifest API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.manifest;

public import moss.deps.analysis.fileinfo;

public import moss.format.binary.payload.meta;
public import moss.format.binary.payload.layout;

/**
 * A BuildManifest is produced for each build and contains some
 * data which we can use to verify that a source recipe has indeed been
 * build-verified.
 *
 * Additionally it provides important information to supplement the source
 * index for build-time results, i.e. subpackage yields, etc.
 */
public class BuildManifest
{
    /**
     * Write the whole manifest
     */
    abstract void write() @safe;

    /**
     * Record details from the package.
     */
    abstract void recordPackage(const(string) pkgName, scope MetaPayload mp, scope LayoutPayload lp) @safe;

    pure @property final const(string) fileName() const @safe @nogc nothrow
    {
        return _fileName;
    }

    pure @property final void fileName(const(string) s) @safe @nogc nothrow
    {
        _fileName = s;
    }

private:

    string _fileName = null;
}

public import mason.build.manifest.json_manifest;
public import mason.build.manifest.binary_manifest;
