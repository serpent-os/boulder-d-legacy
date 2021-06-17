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

module boulder.build.manifest;

public import boulder.build.collector;
public import boulder.build.analysis;

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
    abstract void recordPackage(const(string) pkgName, ref FileAnalysis[] fileSet);

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

public import boulder.build.manifest.json_manifest;
public import boulder.build.manifest.binary_manifest;
