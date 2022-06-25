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

module mason.build.context;

import moss.format.source.macros;
import moss.format.source.spec;
import moss.format.source.script;

import std.parallelism : totalCPUs;
import std.concurrency : initOnce;
import std.path : buildNormalizedPath;
import std.string : endsWith;
import std.experimental.logger;

/**
 * Return the current shared Context for all moss operations
 */
BuildContext buildContext() @trusted
{
    return initOnce!_sharedBuildContext(new BuildContext());
}

/* Singleton instance */
private __gshared BuildContext _sharedBuildContext = null;

/**
 * The BuildContext holds global configurations and variables needed to complete
 * all builds.
 */
public final class BuildContext
{
    /**
     * Construct a new BuildContext
     */
    this()
    {
        this._spec = spec;
        this._rootDir = ".";

        jobs = 0;

        this.loadMacros();
    }

    /**
     * Return the spec (recipe) directory
     */
    pure @property string specDir() const @safe @nogc nothrow
    {
        return _specDir;
    }

    /**
     * Set the spec (recipe) directory
     */
    pure @property void specDir(const(string) p) @safe @nogc nothrow
    {
        _specDir = p;
    }

    /**
     * Return the root directory
     */
    pure @property string rootDir() const @safe @nogc nothrow
    {
        return _rootDir;
    }

    /**
     * Set the new root directory
     */
    pure @property void rootDir(const(string) s) @safe @nogc nothrow
    {
        _rootDir = s;
    }

    /**
     * Return the package file directory
     */
    pure @property string pkgDir() const @safe nothrow
    {
        import std.array : join;

        return join([_rootDir, "pkgdir"], "/");
    }

    /**
     * Return the source directory
     */
    pure @property string sourceDir() const @safe nothrow
    {
        import std.array : join;

        return join([_rootDir, "sourcedir"], "/");
    }

    /**
     * Return the underlying specfile
     */
    pragma(inline, true) pure @property scope Spec* spec() @safe @nogc nothrow
    {
        return _spec;
    }

    /**
     * Update the currently used spec for this BuildContext
     */
    pure @property void spec(Spec* spec) @safe @nogc nothrow
    {
        _spec = spec;
    }

    /**
     * Return the number of build jobs
     */
    pure @property int jobs() @safe @nogc nothrow
    {
        return _jobs;
    }

    /**
     * Set the number of build jobs
     */
    @property void jobs(int j) @safe @nogc nothrow
    {
        if (j < 1)
        {
            _jobs = totalCPUs();
            return;
        }

        _jobs = j;
    }

    /**
     * Return the outputDirectory property
     */
    pure @property const(string) outputDirectory() @safe @nogc nothrow
    {
        return _outputDirectory;
    }

    /**
     * Set the outputDirectory property
     */
    pure @property void outputDirectory(const(string) s) @safe @nogc nothrow
    {
        _outputDirectory = s;
    }

    /**
     * Prepare a ScriptBuilder
     */
    void prepareScripts(ref ScriptBuilder sbuilder, string architecture)
    {
        import std.conv : to;

        string[] arches = ["base", architecture];

        sbuilder.addDefinition("name", spec.source.name);
        sbuilder.addDefinition("version", spec.source.versionIdentifier);
        sbuilder.addDefinition("release", to!string(spec.source.release));
        sbuilder.addDefinition("jobs", to!string(jobs));
        sbuilder.addDefinition("pkgdir", pkgDir);
        sbuilder.addDefinition("sourcedir", sourceDir);

        foreach (ref arch; arches)
        {
            auto archFile = defFiles[arch];
            sbuilder.addFrom(archFile);
        }

        foreach (ref action; actionFiles)
        {
            sbuilder.addFrom(action);
        }
    }

private:

    /**
     * Load all supportable macros
     */
    void loadMacros()
    {
        import std.file : exists, dirEntries, thisExePath, SpanMode;
        import std.path : dirName, baseName, absolutePath;
        import moss.core.platform : platform;
        import std.string : format;
        import std.exception : enforce;
        import std.array : join;

        MacroFile* file;

        /* bin/../share/boulder/macros */
        immutable resourceDir = thisExePath.dirName.buildNormalizedPath("..",
                "share", "boulder", "macros").absolutePath;
        auto plat = platform();

        /** Shared actions */
        immutable actionDir = join([resourceDir, "actions"], "/");

        /* Architecture specific definitions */
        immutable archDir = join([resourceDir, "arch"], "/");
        immutable baseYml = join([archDir, "base.yml"], "/");
        immutable nativeYml = join([archDir, "%s.yml".format(plat.name)], "/");
        immutable emulYml = join([archDir, "emul32/%s.yml".format(plat.name)], "/");

        enforce(baseYml.exists, baseYml ~ " file cannot be found");
        enforce(nativeYml.exists, nativeYml ~ " cannot be found");
        if (plat.emul32)
        {
            enforce(emulYml.exists, emulYml ~ " cannot be found");
        }

        void loadDirectoryArchitectures(string prefix, string directory)
        {
            foreach (target; dirEntries(archDir, SpanMode.shallow, false))
            {
                if (!target.name.endsWith(".yml"))
                {
                    continue;
                }
                tracef("Loading architecture: %s", target.name.baseName);
                auto f = new MacroFile(File(target.name));
                f.parse();
                /* Remove the .yml suffix */
                auto identifier = target.name.baseName[0 .. $ - 4];
                defFiles[format!"%s%s"(prefix, identifier)] = f;
            }
        }

        loadDirectoryArchitectures("", archDir);
        loadDirectoryArchitectures("emul32/", archDir ~ "/emul32");

        if (!actionDir.exists)
        {
            return;
        }

        /* Load all the action files in */
        foreach (nom; dirEntries(actionDir, "*.yml", SpanMode.shallow, false))
        {
            if (!nom.isFile)
            {
                continue;
            }
            auto name = nom.name.baseName[0 .. $ - 4];
            file = new MacroFile(File(nom.name));
            file.parse();
            actionFiles ~= file;
        }
    }

    string _rootDir;
    Spec* _spec;

package:
    MacroFile*[string] defFiles;
    MacroFile*[] actionFiles;
    uint _jobs = 0;
    string _outputDirectory = ".";
    string _specDir = ".";
}
