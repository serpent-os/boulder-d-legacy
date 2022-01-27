project(
	'moss-container',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	],
)

# Package sources
container_sources = [
	'source/moss/container/fakeroot.d',
	'source/moss/container/context.d',
	'source/moss/container/mounts.d',
	'source/moss/container/package.d',
	'source/moss/container/process.d',
	'source/moss/container/device.d',
	'source/main.d'
]

# Expose source dependencies
container_includes = [
	include_directories('source'),
]

# Right now we'll only build against a local moss-core checkout
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

container_deps = [
	link_libmoss_core,
]

# Compile as a static library
container = executable(
	'moss-container',
	container_sources,
	dependencies: container_deps,
	install: true,
	include_directories: container_includes,
	link_args: '--link-defaultlib-shared=false',
)
