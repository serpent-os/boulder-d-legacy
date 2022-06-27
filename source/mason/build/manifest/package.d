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

/**
 * A BuildManifest is produced for each BuildProfile and contains some
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
     *
     * TODO: Replace with per-package emission
     */
    abstract void write() @safe;
    abstract void recordPackage(const(string) pkgName, ref FileInfo[] fileSet);

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
