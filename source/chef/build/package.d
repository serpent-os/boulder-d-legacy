/* SPDX-License-Identifier: Zlib */

/**
 * Chef - Build Management
 *
 * Generation and manipulation of source recipe files that can then be consumed
 * by boulder.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module chef.build;

public import chef.build.autotools;
public import chef.build.cmake;
public import chef.build.meson;

import std.traits : EnumMembers;
import std.string : capitalize;
import std.experimental.typecons : wrap;

public Build buildTypeToHelper(BuildType type)
{
    auto nom = cast(string) type;

    final switch (nom)
    {
        static foreach (member; EnumMembers!BuildType)
        {
    case member:
            /* Disallow unknown, return null */
            static if (member == "unknown")
            {
                return null;
            }
            else
            {
                /* Return class based instantiation */
                mixin("auto helper = " ~ member.capitalize ~ "Build();");
                return helper.wrap!Build;
            }
        }
    }
}

/**
 * Supported build system types.
 */
public enum BuildType : string
{
    /**
     * Uses configure/make/install routine
     */
    Autotools = "autotools",

    /**
     * CMake integration
     */
    CMake = "cmake",

    /**
     * Uses meson + ninja
     */
    Meson = "meson",

    /**
     * Unsupported tooling
     */
    Unknown = "unknown",
}

/**
 * Any BuildPattern implementation must have the
 * following members to be valid. For lightweight
 * usage we actually use structs not class implementations.
 */
public interface Build
{
    /**
     * Implement the `setup` step
     */
    string setup();

    /**
     * Implement the `build` step
     */
    string build();

    /**
     * Implement the `install` step
     */
    string install();

    /**
     * Implement the `check` step
     */
    string check();
}
