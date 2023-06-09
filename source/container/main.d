/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Main entry point
 *
 * Provides the main entry point into the `moss-container` binary along
 * with some CLI parsing and container namespace initialisation.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module container.main;

import container.cli : run;

int main(string[] args)
{
    try
    {
        run(args);
    }
    catch (Exception e)
    {
        return 1;
    }
    return 0;
}
