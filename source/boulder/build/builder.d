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
import boulder.build.util;
import moss.core.platform;
import moss.deps.analysis;
import std.algorithm : each, filter;
import moss.deps.analysis.elves;
import std.stdio : stderr;
import std.string : startsWith;

import core.sys.posix.sys.stat;

/**
 * As far as boulder is concerned, any directory mode 0755 is utterly uninteresting
 * and doesn't need to be recorded in the final payload, as we can simply recreate
 * it.
 */
private static immutable auto regularDirectoryMode = S_IFDIR | S_IROTH | S_IXOTH
    | S_IRGRP | S_IXGRP | S_IRWXU;

/* 
 * Do not allow non /usr paths!
 */
private static AnalysisReturn dropBadPaths(scope Analyser analyser, ref FileInfo info)
{
    if (!info.path.startsWith("/usr/"))
    {
        if (!info.path.startsWith("/usr"))
        {
            stderr.writefln!"[Analyse] Rejecting non /usr/ file from inclusion: %s"(info.path);
        }
        return AnalysisReturn.IgnoreFile;
    }

    return AnalysisReturn.NextHandler;
}

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
        analyser.userdata = this;
        setupChains();

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
        emitter.emit(buildContext.outputDirectory, this.analyser);
    }

    /**
     * Produce required manifests
     */
    void produceManifests() @system
    {
        import std.algorithm : each;

        profiles.each!((ref p) => p.produceManifest(analyser));

    }

private:

    /**
     * Setup our boulder chains */
    void setupChains()
    {
        const auto boulderChains = [
            /* Highest policy */
            AnalysisChain("badFiles", [&dropBadPaths], 100),

            /* Handle ELF files */
            AnalysisChain("elves", [
                    &acceptElfFiles, &scanElfFiles, &copyElfDebug,
                    &stripElfFiles, &includeFile,
                    ], 100),

            /* Default inclusion policy */
            AnalysisChain("default", [&includeFile], 0),
        ];

        boulderChains.each!((const c) => {
            auto chain = cast(AnalysisChain) c;
            analyser.addChain(chain);
        }());
    }

    /**
     * TODO: Copy the ELF debug section into debug files
     */
    static AnalysisReturn copyElfDebug(scope Analyser analyser, ref FileInfo fileInfo)
    {
        auto instance = analyser.userdata!Builder;
        import std.stdio : stdin, stdout, stderr, writeln;
        import std.exception : enforce;
        import std.string : format;
        import std.path : buildPath, dirName;
        import std.file : mkdirRecurse;

        if (fileInfo.buildID is null)
        {
            return AnalysisReturn.NextFunction;
        }

        bool useLLVM = buildContext.spec.options.toolchain == "llvm";
        auto command = useLLVM ? "/usr/bin/llvm-objcopy" : "/usr/bin/objcopy";

        auto debugdir = fileInfo.bitSize == 64
            ? "usr/lib/debug/.build-id" : "usr/lib32/debug/.build-id";
        auto debugInfoPath = instance.profiles[0].installRoot.buildPath(debugdir,
                fileInfo.buildID[0 .. 2], fileInfo.buildID[2 .. $] ~ ".debug");
        auto debugInfoDir = debugInfoPath.dirName;
        debugInfoDir.mkdirRecurse();

        /* Execute, TODO: Fix environment */
        auto ret = executeCommand(command, [
                "--only-keep-debug", fileInfo.fullPath, debugInfoPath
                ], null);
        auto code = ret.match!((err) {
            writeln("[debuginfo] failure: ", err.toString());
            return -1;
        }, (code) => code);

        if (code == 0)
        {
            writeln("[debuginfo] ", fileInfo.path);
            instance.collectPath(debugInfoPath, instance.profiles[0].installRoot);
        }

        return AnalysisReturn.NextFunction;
    }

    /**
     * Interface back with boulder instance for file stripping. This is specific
     * to ELF files only (i.e. split for debuginfo)
     */
    static AnalysisReturn stripElfFiles(scope Analyser analyser, ref FileInfo fileInfo)
    {
        Builder instance = analyser.userdata!Builder();
        import std.stdio : stdin, stdout, stderr, writeln;
        import std.exception : enforce;
        import std.string : format;

        if (!buildContext.spec.options.strip)
        {
            return AnalysisReturn.NextFunction;
        }

        bool useLLVM = buildContext.spec.options.toolchain == "llvm";
        auto command = useLLVM ? "/usr/bin/llvm-strip" : "/usr/bin/strip";

        /* Execute, TODO: Fix environment */
        import std.process : Config, spawnProcess, wait;

        auto ret = executeCommand(command, [
                "--strip-unneeded", fileInfo.fullPath
                ], null);
        auto code = ret.match!((err) {
            writeln("[strip] failure: ", err.toString);
            return -1;
        }, (code) => code);

        if (code == 0)
        {
            writeln("[strip] ", fileInfo.path);
        }

        return AnalysisReturn.NextFunction;
    }

    /**
        * Explicitly requested addition of some path, so add it now.
        */
    void collectPath(in string path, in string root)
    {
        import std.path : relativePath;
        import std.string : format;

        auto targetPath = path.relativePath(root);
        if (targetPath[0] != '/')
        {
            targetPath = format!"/%s"(targetPath);
        }
        auto inf = FileInfo(targetPath, path);
        inf.target = collector.packageTarget(targetPath);
        analyser.addFile(inf);
    }

    /**
     * Begin collection on the given rootfs tree, from the collectAssets
     * call.
     */
    void collectRootfs(const(string) root)
    {
        import std.file : dirEntries, DirEntry, SpanMode;

        /**
         * Custom recursive dirEntries (DFS) style function which lets us
         * detect empty directories and directories with special permissions
         * so that for the most part we won't explicitly include directory
         * records in the payload.
         */
        void collectionHelper(in string path, bool specialDirectory = false)
        {
            auto entries = dirEntries(path, SpanMode.shallow, false);

            if (entries.empty)
            {
                /* Include empty directory */
                collectPath(path, root);
                return;
            }
            else if (specialDirectory)
            {
                /* Include directory with non standard mode */
                collectPath(path, root);
            }
            /* Otherwise, ignore the directory and rely on mkdir recursive */

            /* Depth first, close fd early to prevent exhaustion */
            foreach (entry; entries)
            {
                auto specialDir = entry.isDir() && entry.statBuf.st_mode != regularDirectoryMode;
                if (entry.isDir)
                {
                    collectionHelper(entry.name, specialDir);
                }
                else
                {
                    collectPath(entry.name, root);
                }
                entry.destroy();
            }
        }

        collectionHelper(root);
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
