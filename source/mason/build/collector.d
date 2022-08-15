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
import std.stdio;
import std.algorithm : startsWith, filter;
import std.exception : enforce;
import std.experimental.logger;
import std.format : format;
import moss.format.source.package_definition;
import moss.format.source.path_definition;

/**
 * A CollectionRule simply defines a path pattern to match against (glob style)
 * and a priority with which the pattern will be used.
 *
 * Increased priority numbers lead to the rule running before other rules.
 */
package struct CollectionRule
{
    /**
     * A PathDefinition supporting a glob style path pattern and a path type
     * to match against.
     */
    PathDefinition pathDef;

    /**
     * A target name to incorporate, such as "name-devel"
     */
    string target = null;

    /**
     * Priority used to sort the rules
     */
    int priority = 0;

    /// FIXME: Update to care about types too
    bool match(const(string) encounteredFilePath) @safe
    {
        debug { trace(format!"match build artefact '%s' against rule: %s"(encounteredFilePath,  pathDef)); }
        return (pathDef.path == encounteredFilePath || encounteredFilePath.startsWith(pathDef.path)
                || globMatch!(CaseSensitive.yes)(encounteredFilePath, pathDef.path));
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
     * Add a priority based CollectionRule to the system which can of course be overridden.
     */
    void addRule(PathDefinition pathDef, string packageTarget, uint priority = 0) @safe
    {
        import std.algorithm : sort;

        /* Sort ahead of time */
        rules ~= CollectionRule(pathDef, packageTarget, priority);
        rules.sort!((a, b) => a.priority > b.priority);
    }

    /**
     * Return the package target for the given encountered filesystem path by .match-ing
     * it against the list of CollectionRules w/PathDefinition globs.
     * TODO: .. and type
     */
    auto packageTarget(const(string) encounteredFilePath)
    {
        ///FIXME this needs extra filtering functionality for the type
        auto matchingSet = rules.filter!((r) => r.match(encounteredFilePath));
        enforce(!matchingSet.empty,
                "LINT: packageTarget(): No matching rule for path: %s".format(encounteredFilePath));

        return matchingSet.front.target;
    }

private:

    /* Map PathDefinition glob patterns + file types to target packages */
    CollectionRule[] rules;
}
