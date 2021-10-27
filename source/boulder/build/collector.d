/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module boulder.build.collector;

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
