/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - CMake integration
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.build.cmake;

public struct CmakeBuild
{
    string setup()
    {
        return "%cmake";
    }

    string build()
    {
        return "%cmake_build";
    }

    string install()
    {
        return "%cmake_install";
    }

    string check()
    {
        return null;
    }
}
