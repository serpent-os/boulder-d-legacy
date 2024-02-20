/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * boulder.environment
 *
 * Environment variables
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module boulder.environment;

import std.algorithm.iteration : map;
import std.algorithm.searching : find;
import std.array : back;
import std.format : format;
import std.string : stripRight, splitLines, split, replace;

/** Boulder version */
static immutable VERSION = getenv("VERSION");
/** Git hash */
static immutable GIT_HASH = getenv("GIT_HASH");

/** 
 * Returns the full formatted version string including 
 * git hash (if compiled from the repo)
 *
 * e.g. 0.1.0 (1d2f6b389)
 */
string fullVersion()
{
    immutable git = GIT_HASH == "" ? "" : format!" (%s)"(GIT_HASH);

    pragma(msg, format!"--\n-- found (VERSION, GIT_HASH): (%s, %s)\n--"(VERSION, GIT_HASH));

    return format!"%s%s"(VERSION, git);
}

private static string getenv(string key)
{
    static immutable environment = import("environment").stripRight;

    return splitLines(environment).map!(l => l.split('='))
        .find!(l => l[0] == key)
        .front[1];
}
