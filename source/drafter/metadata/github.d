/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * drafter.metadata.github
 *
 * GitHub specific metadata helpers
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module drafter.metadata.github;

import std.typecons : Nullable;
import moss.format.source.source_definition;
import std.regex;
import std.string : format;
import std.uni : toLower;

/**
 * Github automatically generated downloads
 */
auto reGithubAutomatic = regex(
        r"\w+\:\/\/github\.com\/([A-Za-z0-9-_]+)\/([A-Za-z0-9-_]+)\/archive\/refs\/tags\/([A-Za-z0-9.-_]+)\.(tar|zip)");

/**
 * Mapping to our groups
 */
private static enum GithubIndex : int
{
    Owner = 1,
    Project = 2,
    Version = 3,
}

/**
 * Manually uploaded files on GitHub
 */
auto reGithubManual = regex(
        r"\w+\:\/\/github\.com\/([A-Za-z0-9-_]+)\/([A-Za-z0-9-_]+)\/releases\/download\/([A-Za-z0-9-_.]+)\/.*");

/**
 * More advanced matching of GitHub specific URIs
 */
public struct GithubMetadata
{
    /**
     * Match full unmodified string with 2 regex patterns
     */
    Nullable!(SourceDefinition, SourceDefinition.init) match(in string uri)
    {
        Nullable!(SourceDefinition, SourceDefinition.init) ret = SourceDefinition.init;

        auto matchers = [
            uri.matchFirst(reGithubAutomatic), uri.matchFirst(reGithubManual),
        ];

        foreach (m; matchers)
        {
            if (m.empty)
            {
                continue;
            }
            auto sd = SourceDefinition();
            sd.homepage = format!"https://github.com/%s/%s"(m[GithubIndex.Owner],
                    m[GithubIndex.Project]);
            sd.name = m[GithubIndex.Project].toLower;
            sd.versionIdentifier = m[GithubIndex.Version];
            return Nullable!(SourceDefinition, SourceDefinition.init)(sd);
        }

        return ret;
    }
}
