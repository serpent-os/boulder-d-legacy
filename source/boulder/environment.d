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

import std.format : format;

/** Boulder version */
const VERSION = "@VERSION@";
/** Git version */
const GIT_VERSION = "@GIT_VERSION@";

/** 
 * Returns the full formatted version string including 
 * git hash (if compiled from the repo)
 *
 * e.g. 0.1.0 (1d2f6b389)
 */
string fullVersion()
{
    immutable git = GIT_VERSION == " " ? "" : format!" (%s)"(GIT_VERSION);

    return format!"%s%s"(VERSION, git);
}
