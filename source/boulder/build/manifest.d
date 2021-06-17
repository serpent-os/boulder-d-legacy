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

import boulder.build.context;
import std.path : buildPath;

/**
 * A BuildManifest is produced for each BuildProfile and contains some
 * data which we can use to verify that a source recipe has indeed been
 * build-verified.
 *
 * Additionally it provides important information to supplement the source
 * index for build-time results, i.e. subpackage yields, etc.
 */
public final class BuildManifest
{
    /**
     * Disallow default constructor
     */
    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture)
    {
        import std.string : format;

        /* i.e. manifest.x86_64 */
        _fileName = "manifest.%s".format(architecture);
    }

    /**
     * Return the file name for the manifest (not the full path)
     */
    pure @property string fileName() const @safe @nogc nothrow
    {
        return _fileName;
    }

    /**
     * Save the manifest (useful only for future manifest).
     * This is considered a build artefact, but for development purposes
     * the file should then be stashed in git for verified builds.
     */
    void save() @safe
    {
        auto targetPath = buildContext.outputDirectory.buildPath(fileName);
    }

    /**
     * Load the manifest from the same directory that we found the specFile in
     */
    void load() @safe
    {
        auto sourcePath = buildContext.specDir.buildPath(fileName);
    }

private:

    string _fileName = null;
}
