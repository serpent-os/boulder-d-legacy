/* SPDX-License-Identifier: Zlib */

/**
 * Boulder Stages
 *
 * Modular simplistic API for various stages in the execution of the
 * boulder part of building, i.e. container and root encapsulation
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages;

public import boulder.buildjob : BuildJob;
public import boulder.stages.clean_root;
public import boulder.stages.create_root;
public import boulder.stages.configure_root;

/**
 * Default boulder stages
 */
static auto boulderStages = [
    &stageCleanRoot, &stageCreateRoot, &stageConfigureRoot
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
public alias StageFunction = StageReturn function(scope StageContext context);

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
    immutable(StageFunction) functor;
}
