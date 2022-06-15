/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - Autotools integration
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.build.meson;

public struct MesonBuild
{
    string setup()
    {
        return "%meson";
    }

    string build()
    {
        return "%meson_build";
    }

    string install()
    {
        return "%meson_install";
    }

    string check()
    {
        return null;
    }
}
