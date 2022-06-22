project(
	'moss-container',
	['d'],
	version: '0.0.0',
	license: [
		'Zlib',
	],
)


# Right now we'll only build against a local moss-core checkout
moss_core = subproject('moss-core')
link_libmoss_core = moss_core.get_variable('link_libmoss_core')

# We use the same includes for everything..
global_includes = [
	include_directories('source')
]

libcontainer_sources = [
	'source/moss/container/fakeroot.d',
	'source/moss/container/context.d',
	'source/moss/container/package.d',
	'source/moss/container/process.d',
	'source/moss/container/device.d',
]

libcontainer = static_library('moss-container',
	libcontainer_sources,
	dependencies: [link_libmoss_core],
	install: false,
	include_directories: global_includes,
)

link_libcontainer = declare_dependency(
	link_with: libcontainer,
	include_directories: global_includes,
	dependencies: [link_libmoss_core],
)

# When configured directly, we build an executable
if not meson.is_subproject()
	# binary sources
	container_sources = [
		'source/main.d'
	]

	container_deps = [
		link_libcontainer,
	]

	# Compile as a static library
	container = executable(
		'moss-container',
		container_sources,
		dependencies: container_deps,
		install: true,
		include_directories: global_includes,
		link_args: '--link-defaultlib-shared=false',
	)
endif
