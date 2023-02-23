/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.util
 *
 * Internal helpers for mason
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.util;

public import std.sumtype;
import core.exception : RangeError;
import core.sys.posix.signal : sigaction, sigaction_t, sigemptyset, SIGINT;
import std.process : Config, kill, ProcessException, spawnProcess, wait;
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

    /* Initalize sigaction_t with our sigIntHandler */
    sigaction_t newSA;
    newSA.sa_handler = &sigIntHandler;
    newSA.sa_flags = 0;
    sigemptyset(&newSA.sa_mask);

    try
    {
        statusCode = wait(id);
        /* Catch SIGINT and only kill the child process */
        sigaction(SIGINT, &newSA, null);
        if (sigInt == true)
        {
            kill(id, SIGINT);
        }
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

/**
 * Sets sigInt to true if the signal recieved is 130 (SIGINT)
 * Params: signal
 */
extern (C) void sigIntHandler(int sig) nothrow @nogc @system
{
    sigInt = true;
}

private:
bool sigInt = false;
