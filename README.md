setup
=====
Customized Fedora Silverblue


Highlights
----------
### Drivers
- zfs
- nvidia
- zenergy


Tips
----
### Fix NVIDIA
```
rpm-ostree kargs --append-if-missing=module_blacklist=nouveau
```

### Fix tmux
```
loginctl enable-linger $USER
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
