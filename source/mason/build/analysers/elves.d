/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.analysers.elves;
 *
 * Special case handling for ELF files, stripping + dbginfo, etc.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.analysers.elves;

public import moss.deps.analysis;

import mason.build.builder : Builder;
import mason.build.context;
import mason.build.util;
import std.array : join;
import std.exception : enforce;
import std.experimental.logger;
import std.file : mkdirRecurse;
import std.path : baseName, dirName;
import std.string : format;

public AnalysisReturn deferElfInclusion(scope Analyser analyser, ref FileInfo fileInfo)
{
    Builder instance = analyser.userdata!Builder;

    /* Need regular ELF files */
    if (fileInfo.type != FileType.Regular)
    {
        return AnalysisReturn.IncludeFile;
    }

    /* Include without stripping or further modification */
    if (fileInfo.buildID is null)
    {
        return AnalysisReturn.IncludeFile;
    }

    /* Defer inclusion of real ELF file */
    instance.pushDeferredElf(fileInfo);
    return AnalysisReturn.IgnoreFile;
}

/**
 * Copy the ELF debug section into debug files
 */
public void copyElfDebug(scope Analyser analyser, ref FileInfo fileInfo)
{
    auto instance = analyser.userdata!Builder;

    bool useLLVM = buildContext.spec.options.toolchain == "llvm";
    auto command = useLLVM ? "/usr/bin/llvm-objcopy" : "/usr/bin/objcopy";

    auto debugdir = fileInfo.bitSize == 64 ? "usr/lib/debug/.build-id" : "usr/lib32/debug/.build-id";
    auto debugInfoPathRelative = join([
        debugdir, fileInfo.buildID[0 .. 2], fileInfo.buildID[2 .. $] ~ ".debug"
    ], "/");
    auto debugInfoPath = join([instance.installRoot, debugInfoPathRelative], "/");
    trace("debugInfoPath: ", debugInfoPath);
    auto debugInfoDir = debugInfoPath.dirName;
    debugInfoDir.mkdirRecurse();

    /* Execute, TODO: Fix environment */
    auto ret = executeCommand(command, [
            "--only-keep-debug", fileInfo.fullPath, debugInfoPath
            ], null);
    auto code = ret.match!((err) {
        error(format!"debuginfo failure: %s"(err.toString));
        return -1;
    }, (code) => code);

    /* Collect the debug asset */
    if (code != 0)
    {
        return;
    }

    /* GNU debuglink. */
    auto commandLink = useLLVM ? "/usr/bin/llvm-objcopy" : "/usr/bin/objcopy";
    auto linkRet = executeCommand(commandLink, [
            "--add-gnu-debuglink", debugInfoPath, fileInfo.fullPath
            ], null);
    code = linkRet.match!((err) {
        error(format!"debuginfo:link failure: %s"(err.toString));
        return -1;
    }, (code) => code);
    if (code != 0)
    {
        warning(format!"debuginfo:link not including broken debuginfo: /%s"(debugInfoPathRelative));
        return;
    }

    trace(format!"debuginfo: %s"(fileInfo.path));
    instance.collectPath(debugInfoPath, instance.installRoot);
}

/**
 * Interface back with boulder instance for file stripping. This is specific
 * to ELF files only (i.e. split for debuginfo)
 */
public void stripElfFiles(scope Builder instance, ref FileInfo fileInfo)
{
    if (!buildContext.spec.options.strip || fileInfo.type != FileType.Regular)
    {
        return;
    }

    bool useLLVM = buildContext.spec.options.toolchain == "llvm";
    auto command = useLLVM ? "/usr/bin/llvm-strip" : "/usr/bin/strip";
    immutable directory = fileInfo.path.dirName.baseName;
    immutable isExecutable = (directory == "bin" || directory == "sbin");

    /* Execute, TODO: Fix environment */
    auto ret = executeCommand(command, isExecutable
            ? [fileInfo.fullPath] : [
                "-g", "--strip-unneeded", fileInfo.fullPath
            ], null);
    auto code = ret.match!((err) {
        error(format!"strip failure: %s"(err.toString));
        return -1;
    }, (code) => code);

    if (code == 0)
    {
        trace(format!"strip: %s"(fileInfo.path));
    }
}
