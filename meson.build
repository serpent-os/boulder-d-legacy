project(
	'boulder',
	['d'],
	version: '1.0.1',
	license: [
		'Zlib',
	]
)

compiler = meson.get_compiler('d')
if compiler.get_id() == 'llvm' and compiler.version().version_compare('<1.31.0')
	error('LDC must be at least 1.31.0')
endif

pkgconf = import('pkgconfig')

# libmoss with all the options
libmoss = subproject('libmoss',
	default_options: [
		'default_library=static',
	],
	version: '>=1.2.0'
)

# Grab moss-config
link_libmoss_config = libmoss.get_variable('link_libmoss_config')

# Grab moss-core
link_libmoss_core = libmoss.get_variable('link_libmoss_core')

# Grab moss-deps
link_libmoss_deps = libmoss.get_variable('link_libmoss_deps')

# Grab moss-fetcher
link_libmoss_fetcher = libmoss.get_variable('link_libmoss_fetcher')

# Grab moss-format
link_libmoss_format = libmoss.get_variable('link_libmoss_format')

boulder_data_dir = [
    include_directories('data'),
]

install_subdir('license-list-data' / 'text',
    install_dir: get_option('prefix') / get_option('datadir') / 'boulder' / 'licenses',
    strip_directory: true)

# Actual linky buildy stuff
subdir('source')

# Macros etc.
subdir('data')
