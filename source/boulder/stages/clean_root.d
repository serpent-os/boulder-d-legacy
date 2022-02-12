/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Clean root
 *
 * Simple stage that will just clean the existing root if found
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.clean_root;

public import boulder.stages : Stage, StageReturn;

/**
 * Handle cleaning of root tree
 */
public static immutable(Stage) stageCleanRoot = Stage("clean-root", (context) {
    return StageReturn.Failure;
});
