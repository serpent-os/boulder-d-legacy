/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Main entry point
 *
 * Provides the main entry point into the `container` companion application.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module container.main;

import std : stderr;

import container.cli : run;

int main(string[] args)
{
    return run(args);
}
