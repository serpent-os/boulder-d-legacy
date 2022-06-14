libchef_sources = [
    'package.d',
    'build/package.d',
    'metadata.d',
]

libchef_deps = [
    link_libmoss_core,
    link_libmoss_fetcher,
    link_libmoss_deps,
    link_libmoss_format,
]

libchef = static_library(
    'chef',
    libchef_sources,
    include_directories: global_includes,
    dependencies: libchef_deps,
)

link_libchef = declare_dependency(
    link_whole: libchef,
    include_directories: global_includes,
    dependencies: libchef_deps,
)