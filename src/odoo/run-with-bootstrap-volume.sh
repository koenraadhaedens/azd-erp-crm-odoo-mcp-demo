#!/bin/sh
set -eu

install -d -o odoo -g odoo -m 0770 /bootstrap
exec runuser -u odoo -- "$@"
