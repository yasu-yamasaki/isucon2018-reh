#!/bin/bash
cd webapp/go
go mod download
make build
sh run_prod.sh &
cd ../..