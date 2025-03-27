setup
=====
Customized Fedora Silverblue


Highlights
----------
### Drivers
- zfs
- nvidia
- zenergy

### Patched software
- gdm ([multiseat](https://gitlab.gnome.org/GNOME/gdm/-/merge_requests/291))
- gnome-shell ([multiseat](https://gitlab.gnome.org/GNOME/gnome-shell/-/merge_requests/2230))
- mutter ([xreal air](https://github.com/eetumos/setup/blob/main/patches/rpm/mutter/xreal-air-sbs.patch))
- monado ([xreal air](https://gitlab.freedesktop.org/monado/monado/-/merge_requests/2435))


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
