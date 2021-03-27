#!/bin/sh

set -eu

if [ ! -e customs/installed ]; then
	printf "Copy /usr/local/src/customs content in $(pwd)\n"
	cp -au /usr/local/src/customs .
	touch customs/installed
	chown -R www-data: customs
fi

exec "$@"
