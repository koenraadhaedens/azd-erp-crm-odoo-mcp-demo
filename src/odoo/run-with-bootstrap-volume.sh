#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
	install -d -o odoo -g odoo -m 0770 /bootstrap
	exec runuser -u odoo -- "$@"
fi

# ACI runtimes may retain the image entrypoint when applying an explicit
# command. In that case an outer invocation has already dropped privileges.
exec "$@"
