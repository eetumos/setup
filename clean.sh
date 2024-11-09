#!/bin/sh
buildah      prune --force
podman image prune --force
