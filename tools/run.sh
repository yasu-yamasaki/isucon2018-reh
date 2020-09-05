#!/bin/sh
pushd webapp/go
go mod download
make build
sh run_prod.sh &
popd