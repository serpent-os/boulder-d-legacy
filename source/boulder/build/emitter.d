/*
 * This file is part of boulder.
 *
 * Copyright © 2020 Serpent OS Developers
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

module boulder.build.emitter;

import moss.format.source.packageDefinition;
import moss.format.source.sourceDefinition;

/**
 * Resulting Package is only buildable once it contains
 * actual files.
 */
package final struct Package
{
    PackageDefinition pd;
    SourceDefinition source;

    /**
     * Resulting filename
     */
    final const(string) filename() @safe
    {
        import moss.platform : platform;
        import std.string : format;

        auto plat = platform();

        return "%s-%s-%d-%s.stone".format(pd.name, source.versionIdentifier,
                source.release, plat.name);
    }

    /**
     * Add a file to the Package
     */
    final void addFile(const(string) p) @safe
    {
        files ~= p;
        _empty = false;
    }

    /**
     * Return true if this is an empty (skippable) package
     */
    pure final @property bool empty() @safe @nogc nothrow
    {
        return _empty;
    }

private:

    bool _empty = true;
    string[] files;
}

/**
 * The BuildEmitter is used to emit build assets from the build, collection +
 * analysis routines, into an actual package.
 */
final struct BuildEmitter
{

public:

    /**
     * Add a package to the BuildEmitter. It is unknown whether or not
     * a package will actually be emitted until such point as files are
     * added to it.
     */
    final void addPackage(ref SourceDefinition sd, ref PackageDefinition pd) @safe
    {
        auto pkg = new Package();
        pkg.pd = pd;
        pkg.source = sd;
        packages[pd.name] = pkg;
    }

    final void addFile(const(string) pkgName, const(string) fp) @safe
    {
        auto pkg = packages[pkgName];
        pkg.addFile(fp);
    }

    /**
     * Now emit the collected packages
     */
    final void emit() @system
    {
        import std.stdio;
        import std.algorithm;

        packages.values
            .filter!((p) => !p.empty)
            .each!((p) => writeln(p.filename));
    }

private:

    Package*[string] packages;
}
