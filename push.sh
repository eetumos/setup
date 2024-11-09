#!/bin/sh
set -e

podman login ghcr.io

podman push "$@" ghcr.io/eetumos/silverblue:latest
podman push "$@" ghcr.io/eetumos/silverblue:base
podman push "$@" ghcr.io/eetumos/silverblue:nvidia
