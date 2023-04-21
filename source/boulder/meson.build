# Build the main executable.

conf_data = configuration_data()
conf_data.set('VERSION', meson.project_version())
conf_data.set('GIT_VERSION', '@GIT_VERSION@')

environment = configure_file(
    input : 'environment.d',
    output : 'environment.d.tmp',
    configuration : conf_data,
)

environment = vcs_tag(
    command: ['git', 'describe', '--tags', '--always', '--dirty', '--abbrev=9'],
    input: environment,
    output: 'environment.d',
    replace_string: '@GIT_VERSION@',
    fallback: '',
)

boulder_sources = [
    'cli/package.d',
    'cli/build_command.d',
    'cli/chroot_command.d',
    'cli/deletecache_command.d',
    'cli/new_command.d',
    'cli/version_command.d',
    'buildjob.d',
    'controller.d',
    'upstreamcache.d',
    'stages/build_package.d',
    'stages/chroot_package.d',
    'stages/clean_root.d',
    'stages/create_root.d',
    'stages/configure_root.d',
    'stages/fetch_upstreams.d',
    'stages/populate_root.d',
    'stages/share_upstreams.d',
    'stages/sync_artefacts.d',
    'stages/package.d',
    'main.d',
    environment,
]

boulder_includes = [
    include_directories('.'),
]

boulder_deps = [
    link_libmoss_config,
    link_libmoss_core,
    link_libmoss_deps,
    link_libmoss_format,
    link_libmoss_fetcher,
    link_libdrafter,
    link_libmason,
]

boulder = executable(
	'boulder',
	boulder_sources,
	install: true,
	dependencies: boulder_deps,
	include_directories: boulder_includes,
	link_args: ['--link-defaultlib-shared=false'],
)

# Ensure mason works
install_symlink('mason',
    install_dir: 'bin',
    pointing_to: 'boulder')
