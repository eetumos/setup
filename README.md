setup
=====
Customized Fedora Silverblue


Highlights
----------
### Drivers
- zfs
- nvidia
- zenergy

### Software
- gnome with a patch for multiseat
- wrapper for umu-launcher
- monado
- ollama
- various CLI tools (tmux, nnn, nvim, ripgrep, ffmpeg, ...)


Issues
------
- kernel arguments require manual modification
  - add `preempt=full`
  - add `module_blacklist=nouveau`
  - remove `init=*/ostree-prepare-root` (on systems with downgraded kernel)


Tips
----
### Fix tmux
```
loginctl enable-linger $USER
```

### Fix NVIDIA
```
rpm-ostree kargs --append-if-missing=module_blacklist=nouveau
```

### Use local build
```
s=$(podman info -f json | jq -r .store.graphRoot)
t=ghcr.io/eetumos/silverblue
rpm-ostree rebase ostree-unverified-image:containers-storage:[$s]$t
```


TODO
----
- HDR support
