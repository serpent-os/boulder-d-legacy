install_subdir('macros',
    install_dir: get_option('prefix') / get_option('datadir') / 'boulder'
)

install_data([
        'default-x86_64.conf',
    ],
    install_dir: get_option('prefix') / get_option('datadir') / 'boulder' / 'profiles.conf.d'
)

configure_file(
    input: 'environment.in',
    output: 'environment',
    configuration: {
        'VERSION': meson.project_version(),
        'GIT_HASH': run_command(
            ['git', 'describe', '--tags', '--always', '--dirty', '--abbrev=9'],
            check: false,
        ).stdout().strip()
    },
)
