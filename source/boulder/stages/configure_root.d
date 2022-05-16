/* SPDX-License-Identifier: Zlib */

/**
 * Stage: Configure root
 *
 * Configure the root prior to populating it
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module boulder.stages.configure_root;

public import boulder.stages : Stage, StageReturn, StageContext;

import std.path : dirName;
import std.file : mkdirRecurse, write;
import mason.build.util : executeCommand, ExecutionError;
import std.sumtype : match;
import std.array : join;

/**
 * Go ahead and configure the tree
 *
 * TODO: Don't lock this to protosnek! Use a configuration
 */
public static immutable(Stage) stageConfigureRoot = Stage("configure-root", (StageContext context) {
    auto repoFile = join([
        context.job.hostPaths.rootfs, "etc/moss/repos.conf.d/99_repo.conf"
    ], "/");
    auto repoDir = repoFile.dirName;
    repoDir.mkdirRecurse();
    write(repoFile, `
- protosnek:
    description: "Automatically configured remote repository"
    uri: "https://dev.serpentos.com/protosnek/x86_64/stone.index"
`);

    string[string] env;
    env["PATH"] = "/usr/bin";
    auto result = executeCommand(context.mossBinary, [
            "ur", "-D", context.job.hostPaths.rootfs
        ], env);
    return result.match!((i) => i == 0 ? StageReturn.Success
        : StageReturn.Failure, (ExecutionError e) => StageReturn.Failure);
});
