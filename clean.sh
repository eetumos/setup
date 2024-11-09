#!/bin/sh
buildah rm --all
podman image prune --force

if [ -n "$1" ]
then
    buildah prune --force
fi
