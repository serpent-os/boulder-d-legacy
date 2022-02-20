/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Go buildy buildy
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.build_package;

public import boulder.stages : Stage, StageReturn, StageContext;

/**
 * Encapsulate build stage
 */
public static immutable(Stage) stageBuildPackage = Stage("build-package", &buildPackage);

/**
 * Go do the build!
 */
static private StageReturn buildPackage(scope StageContext context)
{
    return StageReturn.Failure;
}
