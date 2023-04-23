/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.profile
 *
 * buildProfile APIs
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.profile;

import mason.build.collector;
import mason.build.context;
import mason.build.stage;
import moss.deps.analysis;
import moss.format.source.script;
import moss.format.source.spec;
import std.array : join, empty;
import std.experimental.logger;
import std.format : format;
import std.file : exists;

/**
 * A build profile is generated for each major build profile in the
 * source configuration, i.e. x86_64, emul32, etc.
 *
 * It is tied to a specific architecture and will be seeded from
 * the architecture-specific build options.
 */
struct BuildProfile
{

public:

    /**
     * Construct a new BuildProfile using the given (parsed) spec file.
     */
    this(const(string) architecture)
    {
        //trace(__FUNCTION__);
        this._architecture = architecture;
        this._buildRoot = join([buildContext.rootDir, "build", architecture], "/");
        this._installRoot = join([buildContext.rootDir, "install"], "/");

        /* PGO handling */
        pgoDir = buildRoot ~ "-pgo";

        StageType[] stages;

        /* CSPGO is only available with LLVM toolchain */
        const bool multiStagePGO = (buildContext.spec.options.toolchain == "llvm"
                && buildContext.spec.options.cspgo == true);

        /* PGO specific staging */
        if (hasPGOWorkload)
        {
            /* Always construct a stage1 */
            stages = [
                StageType.Prepare | StageType.ProfileStage1,
                StageType.Setup | StageType.ProfileStage1,
                StageType.Build | StageType.ProfileStage1,
                StageType.Workload | StageType.ProfileStage1,
            ];

            /* Mulitistage uses + refines */
            if (multiStagePGO)
            {
                stages ~= [
                    StageType.Prepare | StageType.ProfileStage2,
                    StageType.Setup | StageType.ProfileStage2,
                    StageType.Build | StageType.ProfileStage2,
                    StageType.Workload | StageType.ProfileStage2,
                ];
            }

            /* Always add the use/final stage */
            stages ~= [
                StageType.Prepare | StageType.ProfileUse,
                StageType.Setup | StageType.ProfileUse,
                StageType.Build | StageType.ProfileUse,
                StageType.Install | StageType.ProfileUse,
                StageType.Check | StageType.ProfileUse,
            ];
        }
        else
        {
            /* No PGO, just execute stages */
            stages = [
                StageType.Prepare, StageType.Setup, StageType.Build,
                StageType.Install, StageType.Check,
            ];
        }

        /* Lights, cameras, action */
        foreach (s; stages)
        {
            insertStage(s);
        }

    }

    /**
     * Return the architecture for this profile
     */
    pure @property string architecture() @safe @nogc nothrow
    {
        return _architecture;
    }

    /**
     * Return the build root directory for this profile
     */
    pure @property string buildRoot() @safe @nogc nothrow
    {
        return _buildRoot;
    }

    /**
     * Return the installation root directory for this profile
     */
    pure @property string installRoot() @safe @nogc nothrow
    {
        return _installRoot;
    }

    /**
     * Write the temporary script to disk, then execute it.
     */
    bool runStage(ExecutionStage* stage, string workDir, ref string script) @system
    {
        import mason.build.util;

        import std.stdio : File, fflush, stdin, stderr, stdout;
        import std.string : format;
        import std.file : remove;

        import moss.core.ioutil;
        import std.sumtype : match;

        //trace(format!"%s(%s, %s, <script>)"(__FUNCTION__, stage.name, workDir));
        /* Ensure we get a temporary file */
        auto tmpResult = IOUtil.createTemporary(format!"/tmp/moss-stage-%s-XXXXXX"(stage.name));
        TemporaryFile tmpFile;
        CError err;
        tmpResult.match!((tmp) { tmpFile = tmp; }, (CError localErr) {
            err = localErr;
        });

        /* Error? Bail */
        if (err.errorCode != 0)
        {
            critical(format!"Critical error in stage '%s': %s"(stage.name,
                    cast(string) err.toString()));
            return false;
        }

        File fi;
        fi.fdopen(tmpFile.fd, "w");

        scope (exit)
        {
            fi.close();
            remove(tmpFile.realPath);
        }

        /* Write + flush */
        fi.write(script);
        fi.flush();
        fflush(fi.getFP);

        /* Execute, TODO: Fix environment */
        int statusCode = -1;
        auto res = executeCommand("/bin/sh", [tmpFile.realPath], null, workDir);
        res.match!((err) {
            error(format!"Unable to execute script: %s"(cast(string) err.toString));
        }, (code) { statusCode = code; });

        if (statusCode != 0)
        {
            error(format!"Stage '%s' exited with code [%d]"(stage.name, statusCode));
        }
        return statusCode == 0;
    }

    /**
     * Request for this profile to now build
     */
    bool build()
    {
        import std.array : replace;
        import std.file : exists, mkdirRecurse, rmdirRecurse;

        //trace(__FUNCTION__);
        bool preparedFS = false;

        foreach (ref e; stages)
        {
            string workdir = buildRoot;
            /* Prepare the buildRoot FS if it hasn't been already */
            if (preparedFS)
            {
                workdir = getWorkDir();
            }
            else
            {
                /**
                 * If directory already exists, nuke it and start fresh.
                 * This is to refresh the build files for PGO builds after each stage.
                 */
                if (buildRoot.exists())
                {
                    buildRoot.rmdirRecurse();
                }
                buildRoot.mkdirRecurse();

                /* Ensure PGO dirs are present if needed */
                if ((e.type & StageType.ProfileStage1) == StageType.ProfileStage1)
                {
                    pgoDir.mkdirRecurse();
                }

                /* FS has now been prepared */
                preparedFS = true;
            }

            /* Prepare the rootfs now */
            auto builder = ScriptBuilder();
            prepareScripts(e, builder, workdir);

            auto scripted = builder.process(e.script).replace("%%", "%");

            if (!runStage(e, workdir, scripted))
            {
                return false;
            }

            /* Want to regenerate the working directory after each pgo stage */
            if ((e.type & StageType.Workload) == StageType.Workload)
            {
                preparedFS = false;
            }
        }
        return true;
    }

    /**
     * Throw an error if script building fails
     */
    void validate()
    {
        foreach (ref e; stages)
        {
            //trace(__FUNCTION__, "stage: ", e.name);
            ScriptBuilder builder;
            prepareScripts(e, builder, buildRoot);

            /* Throw script away, just ensure it can build */
            const auto scripted = builder.process(e.script);
        }
    }

    /**
     * Prepare a script builder for use
     */
    void prepareScripts(ExecutionStage* stage, ref ScriptBuilder sbuilder, string workDir)
    {
        //trace(__FUNCTION__);
        sbuilder.addDefinition("installroot", installRoot);
        sbuilder.addDefinition("buildroot", buildRoot);
        sbuilder.addDefinition("workdir", workDir);

        /* Use the shared ccache tree */
        if ("/mason/ccache".exists)
        {
            sbuilder.addDefinition("compiler_cache", "/mason/ccache");
        }
        else
        {
            sbuilder.addDefinition("compiler_cache", "$HOME/.ccache");
        }

        /* Always include /bill (future work), and maybe ccache */
        immutable string path = buildContext.compilerCache
            ? "/usr/lib/ccache/bin:/usr/bin:/bin" : "/usr/bin:/bin";

        /* Set the relevant compilers */
        if (buildContext.spec.options.toolchain == "llvm")
        {
            sbuilder.addDefinition("compiler_c", "clang");
            sbuilder.addDefinition("compiler_cxx", "clang++");
            sbuilder.addDefinition("compiler_objc", "clang");
            sbuilder.addDefinition("compiler_objcxx", "clang++");
            sbuilder.addDefinition("compiler_cpp", "clang -E -");
            sbuilder.addDefinition("compiler_objcpp", "clang -E -");
            sbuilder.addDefinition("compiler_objcxxcpp", "clang++ -E");
            sbuilder.addDefinition("compiler_ar", "llvm-ar");
            sbuilder.addDefinition("compiler_ld", "ld.lld");
            sbuilder.addDefinition("compiler_objcopy", "llvm-objcopy");
            sbuilder.addDefinition("compiler_nm", "llvm-nm");
            sbuilder.addDefinition("compiler_ranlib", "llvm-ranlib");
            sbuilder.addDefinition("compiler_strip", "llvm-strip");
            sbuilder.addDefinition("compiler_path", path);
        }
        else
        {
            sbuilder.addDefinition("compiler_c", "gcc");
            sbuilder.addDefinition("compiler_cxx", "g++");
            sbuilder.addDefinition("compiler_objc", "gcc");
            sbuilder.addDefinition("compiler_objcxx", "g++");
            sbuilder.addDefinition("compiler_cpp", "gcc -E");
            sbuilder.addDefinition("compiler_objcpp", "gcc -E");
            sbuilder.addDefinition("compiler_objcxxcpp", "g++ -E");
            sbuilder.addDefinition("compiler_ar", "gcc-ar");
            sbuilder.addDefinition("compiler_ld", "ld.bfd");
            sbuilder.addDefinition("compiler_objcopy", "objcopy");
            sbuilder.addDefinition("compiler_nm", "gcc-nm");
            sbuilder.addDefinition("compiler_ranlib", "gcc-ranlib");
            sbuilder.addDefinition("compiler_strip", "strip");
            sbuilder.addDefinition("compiler_path", path);
        }

        sbuilder.addDefinition("pgo_dir", pgoDir);

        /* Load system macros */
        buildContext.prepareScripts(sbuilder, architecture);

        bakeFlags(stage, sbuilder);

        /* Fully cooked */
        sbuilder.bake();
    }

private:

    /**
     * Specialist function to work with the ScriptBuilder in enabling a sane
     * set of build flags
     */
    void bakeFlags(ExecutionStage* stage, ref ScriptBuilder sbuilder) @safe
    {
        import moss.format.source.tuning_flag : TuningFlag, Toolchain;
        import std.array : join;
        import std.string : strip;
        import std.algorithm : uniq, filter, map;
        import std.array : array;

        /* Set toolchain type for flag probing */
        auto toolchain = buildContext.spec.options.toolchain == "llvm"
            ? Toolchain.LLVM : Toolchain.GNU;

        /* Enable basic cflags always */
        sbuilder.enableGroup("architecture");

        /* Take all tuning selections */
        foreach (ref t; buildContext.spec.options.tuneSelections)
        {
            final switch (t.type)
            {
            case TuningSelectionType.Enable:
                sbuilder.enableGroup(t.name);
                break;
            case TuningSelectionType.Disable:
                sbuilder.disableGroup(t.name);
                break;
            case TuningSelectionType.Config:
                sbuilder.enableGroup(t.name, t.configValue);
                break;
            }
        }

        /* Apply the global defaults now */
        foreach (w; buildContext.defaultTuningGroups(architecture))
        {
            if (!buildContext.spec.options.hasTuningSelection(w))
            {
                sbuilder.enableGroup(w);
            }
        }

        /* Enable PGO flags at correct stages of build */
        if (hasPGOWorkload)
        {
            if ((stage.type & StageType.ProfileStage1) == StageType.ProfileStage1)
            {
                sbuilder.enableGroup("pgostage1");
            }
            else if ((stage.type & StageType.ProfileStage2) == StageType.ProfileStage2)
            {
                sbuilder.enableGroup("pgostage2");
            }
            else if ((stage.type & StageType.ProfileUse) == StageType.ProfileUse)
            {
                sbuilder.enableGroup("pgouse");
                if (buildContext.spec.options.samplepgo == true)
                {
                    sbuilder.enableGroup("pgosample");
                }
            }
        }

        /* Help fix up flag mappings */
        pragma(inline, true) string fixupFlags(T)(T inp)
        {
            return inp.map!((f) => f.strip)
                .array
                .uniq
                .filter!((e) => e.length > 1)
                .join(" ");
        }

        /* Fix up unique set of flags and stringify them */
        auto flagset = sbuilder.buildFlags();
        auto cflags = fixupFlags(flagset.map!((f) => f.cflags(toolchain)));
        auto cxxflags = fixupFlags(flagset.map!((f) => f.cxxflags(toolchain)));
        auto ldflags = fixupFlags(flagset.map!((f) => f.ldflags(toolchain)));

        sbuilder.addDefinition("cflags", cflags);
        sbuilder.addDefinition("cxxflags", cxxflags);
        sbuilder.addDefinition("ldflags", ldflags);
    }

    /**
     * Attempt to grab the workdir from the build tree
     *
     * Unless explicitly specified, it will be the first directory
     * entry within the build root
     */
    string getWorkDir() @system
    {
        import std.file : dirEntries, SpanMode;
        import std.path : baseName;
        import std.string : startsWith;
        import std.array : join;

        //trace(__FUNCTION__);
        /* TODO: Support workdir variable in spec and verify it exists */
        auto items = dirEntries(buildRoot, SpanMode.shallow, false);
        foreach (item; items)
        {
            auto name = item.name.baseName;
            if (!item.name.startsWith(".") && item.isDir)
            {
                return join([buildRoot, name], "/");
            }
        }

        return buildRoot;
    }

    /**
     * Return true if a PGO workload is found for this architecture
     */
    bool hasPGOWorkload() @safe
    {
        import std.string : startsWith;

        BuildDefinition buildDef = buildContext.spec.rootBuild;
        if (architecture in buildContext.spec.profileBuilds)
        {
            buildDef = buildContext.spec.profileBuilds[architecture];
        }
        else if (architecture.startsWith("emul32/") && "emul32" in buildContext.spec.profileBuilds)
        {
            buildDef = buildContext.spec.profileBuilds["emul32"];
        }

        return buildDef.workload() != null;
    }

    /**
     * Insert a stage for processing + execution
     *
     * We'll only insert stages if we find a relevant build description for it,
     * and doing so will result in parent traversal of profiles (i.e. root namespace
     * and emul32 namespace)
     */
    void insertStage(StageType t)
    {
        import std.string : startsWith;

        /* Default to root namespace */
        BuildDefinition buildDef = buildContext.spec.rootBuild;

        /* Find specific definition for stage, or an appropriate parent */
        if (architecture in buildContext.spec.profileBuilds)
        {
            buildDef = buildContext.spec.profileBuilds[architecture];
        }
        else if (architecture.startsWith("emul32/") && "emul32" in buildContext.spec.profileBuilds)
        {
            buildDef = buildContext.spec.profileBuilds["emul32"];
        }

        /* Start stage script with the environment output */
        string script = buildDef.environment();

        /* Check core type of stage */
        if ((t & StageType.Setup) == StageType.Setup)
        {
            script ~= buildDef.setup();
        }
        else if ((t & StageType.Build) == StageType.Build)
        {
            script ~= buildDef.build();
        }
        else if ((t & StageType.Install) == StageType.Install)
        {
            script ~= buildDef.install();
        }
        else if ((t & StageType.Check) == StageType.Check)
        {
            script ~= buildDef.check();
        }
        else if ((t & StageType.Workload) == StageType.Workload)
        {
            script ~= buildDef.workload();
            /* If workload is run with llvm toolchain, we need to merge the profile data */
            if (buildContext.spec.options.toolchain == "llvm")
            {
                if ((t & StageType.ProfileStage1) == StageType.ProfileStage1)
                {
                    script ~= "%llvm_merge_s1";
                }
                else if ((t & StageType.ProfileStage2) == StageType.ProfileStage2)
                {
                    script ~= "%llvm_merge_s2";
                }
            }
        }
        else if ((t & StageType.Prepare) == StageType.Prepare)
        {
            script = genPrepareScript();
        }

        /* Do not add stage if no commands appended to environment */
        if (script == buildDef.environment())
        {
            return;
        }

        auto stage = new ExecutionStage(&this, t);
        stage.script = script;
        stages ~= stage;
    }

    /**
     * Generate preparation script
     *
     * The sole purpose of this internal script is to make the sources
     * available to the current build in their extracted/exploded form
     * via the %(sourcedir) definition.
     */
    string genPrepareScript() @system
    {
        import std.string : endsWith;
        import std.path : baseName;

        string ret = "";

        /* Push commands to extract a zip */
        void extractZip(ref UpstreamDefinition u)
        {
            ret ~= "mkdir -p " ~ u.plain.unpackdir ~ "\n";
            ret ~= "unzip -d \"" ~ u.plain.unpackdir ~ "\" \"%(sourcedir)/"
                ~ u.plain.rename ~ "\" || (echo \"Failed to extract archive\"; exit 1);";
        }

        /* Push commands to extract a tar */
        void extractTar(ref UpstreamDefinition u)
        {
            ret ~= "mkdir -p " ~ u.plain.unpackdir ~ "\n";
            ret ~= "tar xf \"%(sourcedir)/" ~ u.plain.rename ~ "\" -C \"" ~ u.plain.unpackdir ~ "\" --strip-components="
                ~ u.plain.stripdirs ~ " || (echo \"Failed to extract archive\"; exit 1);";
        }

        /**
         * Push commands to copy submodules-ready git repository from
         * %(sourcedir).
         *
         * Note that for now, we're doing literal folder copying (i.e.
         * `cp -Ra`), because doing a mirror clone would result in
         * submodules being fetched once more from the internet. In the future,
         * we may want to mount the repository read-only into %(sourcedir) to
         * prevent tampering with an overlayfs on top for the build process to
         * write stuff.
         */
        void copyGitRepo(ref UpstreamDefinition u)
        {
            /**
             * cp will fail to preserve ownership if it sees a symlink.
             * e.g. cp: failed to preserve ownership for X: Operation not supported
             */
            ret ~= "cp -Ra --no-preserve=ownership \"%(sourcedir)/"
                ~ u.uri.baseName ~ "/\" \"" ~ u.git.clonedir ~ "\"\n";
        }

        foreach (source; buildContext.spec.upstreams)
        {
            final switch (source.type)
            {
            case UpstreamType.Plain:
                if (!source.plain.unpack)
                {
                    continue;
                }
                /* Ensure a target name */
                if (source.plain.rename is null)
                {
                    source.plain.rename = source.uri.baseName;
                }
                if (source.plain.rename.endsWith(".zip"))
                {
                    extractZip(source);
                }
                else
                {
                    extractTar(source);
                }
                break;
            case UpstreamType.Git:
                /**
                 * Manually set clonedir. The layout of a union in D causes
                 * the default initialization of GitUpstreamDefinition to
                 * not work as expected.
                 */
                if (source.git.clonedir == null || source.git.clonedir.empty)
                {
                    source.git.clonedir = ".";
                }
                copyGitRepo(source);
            }
        }

        return ret == "" ? null : ret;
    }

    string _architecture;
    ExecutionStage*[] stages;
    string _buildRoot;
    string _installRoot;
    string pgoDir;
}
