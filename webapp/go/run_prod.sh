#!/bin/bash
set -ue

export DB_DATABASE=torb
# export DB_HOST=118.27.15.185
export DB_HOST=localhost
export DB_PORT=3306
export DB_USER=isucon
export DB_PASS=isucon

./isucon
