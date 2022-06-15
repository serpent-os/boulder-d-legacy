libchef_sources = [
    'package.d',
    'build/autotools.d',
    'build/meson.d',
    'build/package.d',
    'metadata/basic.d',
    'metadata/github.d',
    'metadata/package.d',
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
    d_import_dirs: [
        boulder_data_dir,
    ]
)

link_libchef = declare_dependency(
    link_whole: libchef,
    include_directories: global_includes,
    dependencies: libchef_deps,
)