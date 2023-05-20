/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.stages
 *
 * Modular simplistic API for various stages in the execution of the
 * boulder part of building, i.e. container and root encapsulation
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.stages;

public import moss.core.mounts;
public import boulder.buildjob : BuildJob;
public import boulder.upstreamcache;
public import boulder.stages.build_package;
public import boulder.stages.chroot_package;
public import boulder.stages.clean_root;
public import boulder.stages.create_root;
public import boulder.stages.configure_root;
public import boulder.stages.fetch_upstreams;
public import boulder.stages.populate_root;
public import boulder.stages.share_upstreams;
public import boulder.stages.sync_artefacts;
public import moss.config.profile;
public import moss.config.repo;

public import moss.core.fetchcontext;

import core.sys.posix.stdlib : uid_t;

/**
 * Default stages to build a package
 */
static auto buildStages = [
    &stageCleanRoot, &stageCreateRoot, &stageFetchUpstreams, &stageConfigureRoot,
    &stagePopulateRoot, &stageShareUpstreams, &stageBuildPackage,
    &stageSyncArtefacts,
];

/**
 * Default stages to chroot into a target
 */
static auto chrootStages = [
    &stageCreateRoot, &stagePopulateRoot, &stageChrootPackage
];

/**
 * The StageContext (i.e. BoulderController) exposes some useful properties
 * to facilitate integration.
 */
public interface StageContext
{
    /**
     * The current job
     *
     * Returns: Const reference to the BuildJob
     */
    pure @property const(BuildJob) job() @safe @nogc nothrow const;

    /**
     * Output directory for everything being dumped.
     */
    pure @property immutable(string) outputDirectory() @safe @nogc nothrow const;

    /**
     * Required architecture for build
     */
    pure @property immutable(string) architecture() @safe @nogc nothrow const;

    /**
     * Returns: true if compiler caching is enabled
     */
    pure @property bool compilerCache() @safe @nogc nothrow const;

    /**
     * Confinement status
     *
      * Returns: true if confinement is employed
     */
    pure @property bool confinement() @safe @nogc nothrow const;
    /**
     * Path to moss
     *
     * Returns: Immutable string containing the path
     */
    pure @property immutable(string) mossBinary() @safe @nogc nothrow const;

    /**
     * Path to moss-container
     *
     * Returns: Immutable string containing the path
     */
    pure @property immutable(string) containerBinary() @safe @nogc nothrow const;

    /**
     * Returns: The upstream (fetch) cache
     */
    pure @property UpstreamCache upstreamCache() @safe @nogc nothrow;

    /**
     * Returns: The underlying fetch implementation
     */
    pure @property FetchContext fetcher() @safe @nogc nothrow;

    /**
     * Returns: The current configuration
     */
    pure @property Profile profile() @safe @nogc nothrow;

    /**
     * Add a mounted mointpoint in order to manually unmount later
     */
    void addMount(in FileMount mount) @safe nothrow;
}

/**
 * In order to facilitate flow control each stage execution must return
 * their status
 */
public enum StageReturn
{
    /** Stage executed successfully */
    Success,

    /** Stage failed, bail from processing */
    Failure,

    /** Stage didn't need to run */
    Skipped,
}

/**
 * Each execution function for a stage must explicitly match our type
 */
public alias StageFunction = StageReturn function(StageContext context);

/**
 * A Stage is just an element to control the flow of execution in the
 * boulder process. It is not the same as a mason build stage.
 */
public struct Stage
{
    /**
     * Name for this execution stage
     */
    immutable(string) name;

    /**
     * The runnable method
     */
    StageFunction functor;
}
