/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.collector
 *
 * Collection routines
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.collector;

import std.path;
import std.file;
import std.algorithm : startsWith, filter;
import std.exception : enforce;
import std.string : format;
import moss.format.source.package_definition;

/**
 * A CollectionRule simply defines a pattern to match against (glob style)
 * and a priority with which the pattern will be used.
 *
 * Increased priority numbers lead to the rule running before other rules.
 */
package struct CollectionRule
{
    /**
     * A glob style pattern to match against
     */
    string pattern = null;

    /**
     * A target name to incorporate, such as "name-devel"
     */
    string target = null;

    /**
     * Priority used to sort the rules
     */
    int priority = 0;

    pure bool match(const(string) inp) @safe
    {
        return (inp == pattern || inp.startsWith(pattern)
                || globMatch!(CaseSensitive.yes)(inp, pattern));
    }
}

/**
 * The BuildCollector is responsible for collecting and analysing the
 * contents of the build root, and assigning packages for each given
 * path.
 *
 * By default, all files will end up in the main package unless explicitly
 * overridden by a pattern.
 */
final class BuildCollector
{

public:

    /**
     * Add a priority based rule to the system which can of course be overridden.
     */
    void addRule(string pattern, string target, uint priority = 0) @safe
    {
        import std.algorithm : sort;

        /* Sort ahead of time */
        rules ~= CollectionRule(pattern, target, priority);
        rules.sort!((a, b) => a.priority > b.priority);
    }

    /**
     * Return the package target for the given filesystem path by matching
     * globs.
     */
    auto packageTarget(const(string) targetPath)
    {
        auto matchingSet = rules.filter!((r) => r.match(targetPath));
        enforce(!matchingSet.empty,
                "packageTarget: No matching rule for path: %s".format(targetPath));

        return matchingSet.front.target;
    }

private:

    /* Map file glob patterns to target packages */
    CollectionRule[] rules;
}
