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

module boulder.build.builder;

import moss.format.source.spec;
import boulder.build.context;
import boulder.build.collector;
import boulder.build.profile;
import boulder.build.emitter;
import moss.core.platform;
import moss.deps.analysis;
import std.algorithm : each;
import moss.deps.analysis.elves;

/**
 * Processing of files for analysis + mutation
 */
static immutable AnalysisChain[] boulderChains = [
    /* Handle ELF files */
    AnalysisChain("elves", [&acceptElfFiles, &scanElfFiles, &includeFile,],
            100),

    /* Default inclusion policy */
    AnalysisChain("default", [&includeFile], 0),
];

/**
 * The Builder is responsible for the full build of a source package
 * and emitting a binary package.
 */
final class Builder
{

public:

    /**
     * Construct a new Builder with the given input file. It must be
     * a stone.yml formatted file and actually be valid.
     */
    this()
    {
        buildContext.rootDir = getBuildRoot();

        /* Collection + analysis */
        collector = new BuildCollector();
        analyser = new Analyser();
        boulderChains.each!((const c) => {
            auto chain = cast(AnalysisChain) c;
            analyser.addChain(chain);
        }());

        auto plat = platform();
        /* Is emul32 supported for 64-bit OS? */
        if (plat.emul32)
        {
            auto emul32name = "emul32/" ~ plat.name;
            if (buildContext.spec.supportedArchitecture(emul32name)
                    || buildContext.spec.supportedArchitecture("emul32"))
            {
                addArchitecture(emul32name);
            }
        }

        /* Add builds if this is a supported platform */
        if (buildContext.spec.supportedArchitecture(plat.name)
                || buildContext.spec.supportedArchitecture("native"))
        {
            addArchitecture(plat.name);
        }

        preparePackageDefinitions();
    }

    /**
     * Add an architecture to the build list
     */
    void addArchitecture(string name)
    {
        architectures ~= name;
        profiles ~= new BuildProfile(name);
    }

    /**
     * Prepare our root filesystem for building on
     */
    void prepareRoot() @system
    {
        import std.stdio : writeln;
        import std.file : rmdirRecurse, mkdirRecurse, exists;

        writeln("Preparing root tree");

        if (buildContext.rootDir.exists)
        {
            writeln("Removing old build tree");
            buildContext.rootDir.rmdirRecurse();
        }

        mkdirRecurse(buildContext.rootDir);
    }

    /**
     * Copy all package files to pkgDir
     */
    void preparePkgFiles() @system
    {
        import std.array : array;
        import std.file : copy, dirEntries, exists, isDir, mkdirRecurse, SpanMode;
        import std.path : asRelativePath, buildPath;

        /* Create directory for the package files*/
        buildContext.pkgDir.mkdirRecurse();

        /* Copy the files directory into the build */
        auto location = buildContext.specDir.buildPath("pkg");
        if (location.exists && location.isDir)
        {
            foreach (file; dirEntries(location, SpanMode.breadth, false))
            {
                auto relName = asRelativePath(file.name, location).array;
                auto destName = buildPath(buildContext.pkgDir, relName);
                if (file.isDir())
                {
                    destName.mkdirRecurse();
                }
                else
                {
                    copy(file.name, destName);
                }
            }
        }
    }

    /**
     * Ensure all profile builds will compile ahead of time
     */
    void validateProfiles() @system
    {
        import std.algorithm.iteration : each;

        profiles.each!((ref p) => p.validate());
    }

    /**
     * Build all of the given profiles
     */
    void buildProfiles() @system
    {
        import std.algorithm.iteration : each;

        profiles.each!((ref p) => p.build());
    }

    /**
     * Collect and analyse all assets using the
     * given collector
     */
    void collectAssets() @system
    {
        import std.algorithm : map, uniq, each, sort;
        import std.array : array;

        auto roots = profiles.map!((ref p) => p.installRoot).array();
        roots.sort();
        roots.uniq.each!((const s) => this.collectRootfs(s));
        analyser.process();
    }

    /**
     * Emit all binary packages
     */
    void emitPackages() @system
    {
        emitter.emit(buildContext.outputDirectory, this.collector);
    }

    /**
     * Produce required manifests
     */
    void produceManifests() @system
    {
        import std.algorithm : each;

        profiles.each!((ref p) => p.produceManifest(collector));

    }

private:

    /**
     * Begin collection on the given rootfs tree, from the collectAssets
     * call.
     */
    void collectRootfs(const(string) root)
    {
        import std.file : dirEntries, DirEntry, SpanMode;
        import std.path : relativePath;
        import std.string : format;

        /* Add every encountered file for processing */
        foreach (ref DirEntry e; dirEntries(root, SpanMode.depth, false))
        {
            auto targetPath = e.name.relativePath(root);

            /* Ensure full "local" path */
            if (targetPath[0] != '/')
            {
                targetPath = "/%s".format(targetPath);
            }

            auto fullPath = e.name;
            auto inf = FileInfo(targetPath, fullPath);
            inf.target = collector.packageTarget(targetPath);
            analyser.addFile(inf);
        }
    }

    /**
     * Load all package definitions in
     */
    void preparePackageDefinitions() @system
    {
        import std.algorithm : map, each, joiner;
        import std.array : array;

        string[] arches = ["base"];
        arches ~= architectures;

        /* Insert core package definitions */
        arches.map!((a) => buildContext.defFiles[a].packages)
            .joiner
            .each!((p) => addDefinition(p));

        /* Insert custom package definitions */
        inclusionPriority += 1000;
        addDefinition(buildContext.spec.rootPackage);
        buildContext.spec.subPackages.values.each!((p) => addDefinition(p));

        /* Fully baked definitions, pass to the emitter */
        packages.values.each!((p) => emitter.addPackage(buildContext.spec.source, p));
    }

    /**
     * Insert a definition to allow matching file paths to a proper
     * PackageDefinition merged object. This comes from the spec and
     * our base definitions.
     */
    void addDefinition(PackageDefinition pd)
    {
        import std.algorithm : each, uniq, sort;
        import std.range : chain;
        import std.array : array;

        /* Always insert paths as they're encountered */
        pd = buildContext.spec.expand(pd);
        void insertRule(const(string) name)
        {
            collector.addRule(name, pd.name, inclusionPriority);
            ++inclusionPriority;
        }

        pd.paths.each!((p) => insertRule(p));

        /* Insert new package if needed */
        if (!(pd.name in packages))
        {
            packages[pd.name] = pd;
            return;
        }

        /* Merge rules */
        auto oldPkg = &packages[pd.name];
        oldPkg.runtimeDependencies = oldPkg.runtimeDependencies.chain(pd.runtimeDependencies)
            .uniq.array;
        oldPkg.paths = oldPkg.paths.chain(pd.paths).uniq.array;

        sort(oldPkg.runtimeDependencies);
        sort(oldPkg.paths);

        /* Merge details */
        if (oldPkg.summary is null)
        {
            oldPkg.summary = pd.summary;
        }
        if (oldPkg.description is null)
        {
            oldPkg.description = pd.description;
        }
    }

    /**
     * Safely get the home root tree
     */
    string getBuildRoot() @safe
    {
        import std.path : buildPath, expandTilde;
        import std.file : exists;
        import std.exception : enforce;
        import std.string : format;

        auto hdir = expandTilde("~");
        enforce(hdir.exists, "Home directory not found!");

        return hdir.buildPath(".moss", "buildRoot",
                "%s-%s".format(buildContext.spec.source.name, buildContext.spec.source.release));
    }

    string[] architectures;
    BuildProfile*[] profiles;
    Analyser analyser;
    BuildCollector collector;
    BuildEmitter emitter;
    PackageDefinition[string] packages;
    int inclusionPriority = 0;
}
