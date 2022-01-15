#!/bin/bash
set -e
set -x

# Override by setting COMPILER=dmd in environment
if [[ -z "${COMPILER}" ]]; then
	export COMPILER="ldc2"
fi

if [[ ! -z "$1" ]]; then
    MODE="$1"
fi


dub test --parallel --compiler="${COMPILER}" --skip-registry=all -v --force
