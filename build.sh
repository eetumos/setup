#!/bin/sh
set -e

find $(dirname $0)/{build-env,patches} -exec touch -d2025-01-01 {} +

podman build --target=base   -t ghcr.io/eetumos/silverblue:latest --pull=never "$@" .
podman build --target=base   -t ghcr.io/eetumos/silverblue:base   --pull=never "$@" .
podman build --target=nvidia -t ghcr.io/eetumos/silverblue:nvidia --pull=never "$@" .
