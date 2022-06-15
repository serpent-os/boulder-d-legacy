/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - Autotools integration
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.build.autotools;

import std.regex;

/**
 * Ugly as all living fuck but lets us discover pkgconfig dependencies
 * in configure.ac files using group index 2.
 */
static immutable reConfigurePkgconfig = ctRegex!(
        r"PKG_CHECK_MODULES\s?\(\s?\[([A-Za-z_]+)\s?\]\s?,\s?\[\s?(\s?[A-Za-z0-9\-_+]+)\s?]");

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
