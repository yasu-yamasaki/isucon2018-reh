#!/bin/bash
set -ue

export DB_DATABASE=torb
export DB_HOST=118.27.26.226
export DB_PORT=3306
export DB_USER=isucon
export DB_PASS=isucon

./isucon
