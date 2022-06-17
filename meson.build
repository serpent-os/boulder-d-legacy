project(
	'boulder',
	['d'],
	version: '0.0.0',
	license: [
		'ZLib',
	]
)

pkgconf = import('pkgconfig')

# Pre-configure moss-vendor
subproject('moss-vendor',
    default_options: [
        'with_elf=true',
        'with_rocksdb=false',
        'with_xxhash=true',
        'with_yaml=true',
        'with_zstd=true',
    ],
)

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

boulder_data_dir = [
    include_directories('data'),
]

boulder_license_dir = [
    include_directories('license-list-data/text'),
]

# Actual linky buildy stuff
subdir('source')
