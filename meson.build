project(
	'boulder',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

pkgconf = import('pkgconfig')

# Grab moss-config
moss_config = subproject('moss-config')
link_libmoss_config = moss_config.get_variable('link_libmoss_config')

# Grab moss-core
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# Grab moss-deps
moss_deps = subproject('moss-deps')
link_libmoss_deps = moss_deps.get_variable('link_libmoss_deps')

# Grab moss-fetcher
moss_fetcher = subproject('moss-fetcher')
link_libmoss_fetcher = moss_fetcher.get_variable('link_libmoss_fetcher')

# Grab moss-format
moss_format = subproject('moss-format')
link_libmoss_format = moss_format.get_variable('link_libmoss_format')

boulder_sources = [
    'source/boulder/cli/package.d',
    'source/boulder/cli/version_command.d',
    'source/boulder/cli/build_command.d',
    'source/boulder/controller.d',
    'source/mason/cli/build_command.d',
    'source/mason/cli/package.d',
    'source/mason/package.d',
    'source/mason/build/collector.d',
    'source/mason/build/context.d',
    'source/mason/build/controller/package.d',
    'source/mason/build/emitter.d',
    'source/mason/build/manifest/binary_manifest.d',
    'source/mason/build/manifest/json_manifest.d',
    'source/mason/build/manifest/package.d',
    'source/mason/build/package.d',
    'source/mason/build/profile.d',
    'source/mason/build/stage.d',
    'source/mason/build/util.d',
    'source/mason/build/builder.d',
    'source/main.d',
]

boulder_includes = [
    include_directories('source'),
]

boulder_deps = [
    link_libmoss_config,
    link_libmoss_core,
    link_libmoss_deps,
    link_libmoss_format,
    link_libmoss_fetcher,
]

boulder = executable(
	'boulder',
	boulder_sources,
	install: true,
	dependencies: boulder_deps,
	include_directories: boulder_includes,
	link_args: '--link-defaultlib-shared=false',
)
