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

module mason.build.util;

public import std.sumtype;
import core.exception : RangeError;
import std.process : Config, ProcessException, spawnProcess, wait;
import std.stdio : stderr, stdin, stdout;
import std.string : format;

/**
 * Execution error has a readable error string and a return code
 */
public struct ExecutionError
{
    /**
     * Some status code
     */
    int statusCode = 0;

    /**
     * Usable error string
     */
    string errorString;

    /**
     * Return readable error
     */
    pure @property string toString() const
    {
        return errorString;
    }
}

/**
 * The result is either a status code or some execution error.
 */
public alias ExecutionResult = SumType!(int, ExecutionError);

/**
 * Execute the command and return the result. 
 */
public ExecutionResult executeCommand(in string command, in string[] args,
        in string[string] environment, in string workingDir = ".")
{
    static auto config = Config.retainStderr | Config.retainStdout
        | Config.stderrPassThrough | Config.inheritFDs;

    int statusCode = -1;
    auto id = spawnProcess(command ~ args, stdin, stdout, stderr, environment, config, workingDir);

    try
    {
        statusCode = wait(id);
    }
    catch (RangeError ex)
    {
        return ExecutionResult(ExecutionError(statusCode, "No args provided to executeCommand"));
    }
    catch (ProcessException ex)
    {
        return ExecutionResult(ExecutionError(statusCode,
                format!"Could not launch: %s"(command ~ args)));
    }
    return ExecutionResult(statusCode);
}
