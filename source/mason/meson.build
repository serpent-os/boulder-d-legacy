libmason_sources = [
    'cli/build_command.d',
    'cli/package.d',
    'package.d',
    'build/collector.d',
    'build/context.d',
    'build/controller/package.d',
    'build/emitter.d',
    'build/manifest/binary_manifest.d',
    'build/manifest/json_manifest.d',
    'build/manifest/package.d',
    'build/package.d',
    'build/profile.d',
    'build/stage.d',
    'build/util.d',
    'build/builder.d',
]

libmason_deps = [
    link_libmoss_format,
    link_libmoss_deps,
    link_libmoss_core,
]

libmason = static_library(
    'mason',
    libmason_sources,
    include_directories: global_includes,
    dependencies: libmason_deps,
)

link_libmason = declare_dependency(
    link_whole: libmason,
    include_directories: global_includes,
    dependencies: libmason_deps,
)