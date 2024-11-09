#!/bin/sh
buildah      rm    --all
buildah      prune --force
podman image prune --force
