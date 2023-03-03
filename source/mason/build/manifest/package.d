/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * Mmoss.build.manifest
 *
 * Defines a BuildManifest API
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module mason.build.manifest;

public import moss.deps.analysis;
public import moss.format.binary.payload.layout;
public import moss.format.binary.payload.meta;
public import moss.format.source.package_definition;
public import moss.format.source.source_definition;
import std.algorithm : each, filter, map, sort, uniq;
import std.array : array;
import std.experimental.logger : info;
import std.string : format;

/**
 * Resulting Package is only buildable once it contains
 * actual files.
 */
public struct Package
{
    PackageDefinition pd;
    SourceDefinition source;

    uint64_t buildRelease = 1;

    /**
     * Resulting filename
     */
    const(string) filename() @safe
    {
        import moss.core.platform : platform;
        import std.string : format;

        auto plat = platform();

        return "%s-%s-%d-%d-%s.stone".format(pd.name, source.versionIdentifier,
                source.release, buildRelease, plat.name);
    }
}

/**
     * Generate metadata payload
     */
public MetaPayload generateMetadata(scope AnalysisBucket bucket,
        scope Package* pkg, bool shouldLog = true) @trusted
{
    auto met = new MetaPayload();
    met.addRecord(RecordType.String, RecordTag.Name, pkg.pd.name);
    met.addRecord(RecordType.String, RecordTag.Version, pkg.source.versionIdentifier);
    met.addRecord(RecordType.Uint64, RecordTag.Release, pkg.source.release);
    met.addRecord(RecordType.Uint64, RecordTag.BuildRelease, pkg.buildRelease);
    met.addRecord(RecordType.String, RecordTag.Summary, pkg.pd.summary);
    met.addRecord(RecordType.String, RecordTag.Description, pkg.pd.description);
    met.addRecord(RecordType.String, RecordTag.Homepage, pkg.source.homepage);
    met.addRecord(RecordType.String, RecordTag.SourceID, pkg.source.name);

    /* TODO: Be more flexible encoding architecture. */
    import moss.core.platform : platform;

    auto plat = platform();
    met.addRecord(RecordType.String, RecordTag.Architecture, plat.name);

    pkg.source.license.sort();
    pkg.source.license.uniq.each!((l) => met.addRecord(RecordType.String, RecordTag.License, l));

    auto providers = bucket.providers();
    auto specifiedDeps = pkg.pd.runtimeDependencies.map!((const n) => fromString!Dependency(n));
    auto discoveredDeps = bucket.dependencies();
    auto dependenciesFull = specifiedDeps.array() ~ discoveredDeps.array();
    dependenciesFull.sort();
    auto dependencies = dependenciesFull.uniq();

    if (!providers.empty)
    {
        foreach (prov; providers)
        {
            if (shouldLog)
            {
                info(format!"[%s] provides %s"(pkg.pd.name, prov));
            }
            met.addRecord(RecordType.Provider, RecordTag.Provides, prov);
        }
    }
    if (!dependencies.empty)
    {
        foreach (dep; dependencies)
        {
            if (shouldLog)
            {
                info(format!"[%s] depends on %s"(pkg.pd.name, dep));
            }
            met.addRecord(RecordType.Dependency, RecordTag.Depends, dep);
        }
    }

    return met;

}

/**
 * A BuildManifest is produced for each build and contains some
 * data which we can use to verify that a source recipe has indeed been
 * build-verified.
 *
 * Additionally it provides important information to supplement the source
 * index for build-time results, i.e. subpackage yields, etc.
 */
public class BuildManifest
{
    /**
     * Write the whole manifest
     */
    abstract void write() @safe;

    /**
     * Record details from the package.
     */
    abstract void recordPackage(scope Package* pkg, AnalysisBucket bucket, LayoutPayload lp) @safe;

    pure @property final const(string) fileName() const @safe @nogc nothrow
    {
        return _fileName;
    }

    pure @property final void fileName(const(string) s) @safe @nogc nothrow
    {
        _fileName = s;
    }

private:

    string _fileName = null;
}

public import mason.build.manifest.json_manifest;
public import mason.build.manifest.binary_manifest;
