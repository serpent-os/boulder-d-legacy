/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - Autotools integration
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.build.autotools;

public struct AutotoolsBuild
{
    string setup()
    {
        return "%configure";
    }

    string build()
    {
        return "%make";
    }

    string install()
    {
        return "%make_install";
    }

    string check()
    {
        return null;
    }
}
