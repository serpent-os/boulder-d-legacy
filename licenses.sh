#!/bin/bash
set -e

rm -f data/licenses.list
pushd license-list-data/text
for i in `ls -1 *.txt`; do
	echo $i >> ../../data/licenses.list
done
popd
