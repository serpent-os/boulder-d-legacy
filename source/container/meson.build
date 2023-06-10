dep_subid = dependency('subid', required: false)
if not dep_subid.found()
	# Unfortunately libsubid doesn't ship a .pc file as of April 2023.
	cc = meson.get_compiler('c')
    dep_subid = cc.find_library('subid', has_headers: ['shadow' / 'subid.h'], required: true)
endif
dep_dopt = dependency('dopt', method: 'dub')

container_deps = [
    dep_dub,
    dep_subid,
    link_libmoss_core,
]

container_sources = [
    'cli/create.d',
    'cli/package.d',
    'cli/remove.d',
    'cli/run.d',
	'context.d',
	'fakeroot.d',
	'filesystem.d',
    'main.d',
	'package.d',
	'process.d',
	'usermapping.d',
]

container = executable(
    'container',
    container_sources,
    dependencies: container_deps,
    install: true,
    install_dir : get_option('libexecdir') / meson.project_name(),
    include_directories: global_includes,
    link_args: '--link-defaultlib-shared=false',
)
