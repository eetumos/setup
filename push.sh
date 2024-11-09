#!/bin/sh
set -e

podman login ghcr.io

podman push --compression-format=zstd:chunked "$@" ghcr.io/eetumos/silverblue:latest
podman push --compression-format=zstd:chunked "$@" ghcr.io/eetumos/silverblue:base
podman push --compression-format=zstd:chunked "$@" ghcr.io/eetumos/silverblue:nvidia
