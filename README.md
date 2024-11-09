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
- desktop environment (gnome, chromium, libreoffice, mpv, ...)
- common cli tools (tmux, nnn, nvim, ripgrep, ...)


Issues
------
- kernel arguments require manual modification
  - add `preempt=full`
  - add `module_blacklist=nouveau`


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

### Enable hardware video acceleration on Chromium
```
echo --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder \
    >~/.var/app/org.chromium.Chromium/config/chromium-flags.conf
```

### Rebase to a local build
```
s=$(podman info -f json | jq -r .store.graphRoot)
t=ghcr.io/eetumos/silverblue
rpm-ostree rebase ostree-unverified-image:containers-storage:[$s]$t
```


TODO
----
- HDR support
