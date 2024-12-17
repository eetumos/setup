### common ###
FROM quay.io/fedora/fedora-silverblue:44 AS common
RUN dnf remove -y gnome-software{,-rpm-ostree} firefox{,-langpacks} yelp sos python3-botocore
ENV PATH=/usr/bin

WORKDIR /tmp
RUN mv /usr/bin/uname{,.orig}
COPY build-env/uname /usr/bin/uname


### kernel ###
ARG KERNEL=7.2
RUN if [[ $(rpm -q --qf %{version} kernel) > $KERNEL.999 ]]                                              ; \
    then                                                                                                   \
        rpm-ostree uninstall -y kernel{,-core} kernel-modules{,-core,-extra} virtualbox-guest-additions && \
        rpm-ostree   install -y kernel{,-modules-extra}-$KERNEL.*                                       && \
        dnf versionlock add kernel-core                                                                  ; \
    fi

RUN dnf install -y kernel-devel-matched "kernel-headers <= $(rpm -q --qf %{version} kernel)" rpm-build

RUN dnf install -y https://zfsonlinux.org/fedora/zfs-release-3-1$(rpm -E %dist).noarch.rpm && \
    dnf install -y zfs

RUN curl -sL https://github.com/BoukeHaarsma23/zenergy/archive/master.tar.gz | tar xz && \
    make -C zenergy-master -j modules                                                 && \
    make -C zenergy-master    modules_install clean                                   && \
    rm   -r zenergy-master

RUN dnf install -y https://github.com/winterheart/broadcom-bt-firmware/releases/latest/download/broadcom-bt-firmware-12.0.1.1105.rpm

RUN depmod $(rpm -q --qf %{version}-%{release}.%{arch} kernel)


### userland ###
RUN --mount=type=cache,dst=/var/cache/libdnf5 --mount=type=bind,src=build-env/dnf.conf,dst=/etc/dnf/dnf.conf,z \
    curl -sLO --output-dir /etc/yum.repos.d https://negativo17.org/repos/fedora-multimedia.repo             && \
    dnf update -y

RUN --mount=type=cache,dst=/var/cache/libdnf5 --mount=type=bind,src=build-env/dnf.conf,dst=/etc/dnf/dnf.conf,z \
    dnf install -y tmux nnn neovim ripgrep fzf pwgen                                                           \
                   {h,b}top {s,l}trace socat iotop-c nethogs nmap wev                                          \
                   tio smartmontools sg3_utils android-tools wireguard-tools wireshark                         \
                                                                                                               \
                   unrar p7zip-plugins bsdtar guestfs-tools                                                    \
                   mediainfo mkvtoolnix lib{avif,webp}-tools tesseract graphviz                                \
                   rclone aria2 git-lfs golang-github-acme-lego msmtp                                          \
                                                                                                               \
                   rpmdevtools pipx uv python3-devel fontconfig-devel                                          \
                   cmake meson cargo rustfmt rust-analyzer gdb perf                                            \
                                                                                                               \
                   vulkan-{tools,validation-layers} egl-utils mangohud gamescope igt-gpu-tools                 \
                   nautilus gnome-boxes steam langpacks-fi                                                  && \
    setcap CAP_PERFMON=ep /usr/bin/intel_gpu_top CAP_PERFMON=ep /usr/bin/btop                               && \
    echo NoDisplay=true | tee -a /usr/share/applications/{nvim,htop}.desktop >/dev/null

RUN dnf copr enable -y iucar/rstudio && \
    dnf install -y rstudio-desktop {R,libcurl,fribidi,libtiff}-devel

RUN CARGO_HOME=cargo-home cargo install --locked --root=/usr --no-track dufs tokei fclones binwalk && \
    rm -r cargo-home

RUN --mount=type=cache,dst=/.cache/uv                                                       \
    dnf install -y libusb1-devel systemd-devel                                           && \
    PIPX_GLOBAL_HOME=/usr/lib/pipx PIPX_GLOBAL_BIN_DIR=/usr/bin PIPX_MAN_DIR=/usr/share/man \
    pipx install --global yt-dlp[default,secretstorage,curl-cffi] pgsrip ocrmypdf           \
                          ruff icoextract pulsemixer liquidctl undervolt

RUN curl -sL https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip | bsdtar xC /usr/bin --strip-components=1 && \
    chmod 755 /usr/bin/bun

RUN curl -sLo /usr/bin/kepubify https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-64bit && \
    chmod +x  /usr/bin/kepubify

RUN rew=$(curl https://roomeqwizard.com/installers/ | rg -o 'REW_linux_no_jre.*\.sh' | sort -Vr | head -n1) && \
    curl -o rew https://roomeqwizard.com/installers/$rew                                                    && \
    sed -i 's/-gt "17"/= ""/g' rew                                                                          && \
    chmod +x rew                                                                                            && \
    XDG_DATA_HOME=$PWD ./rew -q                                                                             && \
    sed -i 's/-gt "17"/= ""/g' /opt/REW/roomeqwizard                                                        && \
    rm -r rew install4j /.cache/{install4j,dconf}

RUN curl -sLOOO -o date-menu-formatter@marcinjakubowski.github.com.strip.zip -o lan-ip-address@mrhuber.com.strip.zip                                  \
        https://github.com/eetumos/battery-time/releases/latest/download/battery-time@eetumos.github.com.shell-extension.zip                          \
        https://github.com/Leleat/Tiling-Assistant/releases/latest/download/tiling-assistant@leleat-on-github.shell-extension.zip                     \
        https://github.com/stuarthayhurst/alphabetical-grid-extension/releases/latest/download/AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip \
        https://github.com/marcinjakubowski/date-menu-formatter/archive/master.zip                                                                    \
        https://github.com/Josholith/gnome-extension-lan-ip-address/archive/master.zip                                                             && \
    for F in *.strip.zip; do D=/usr/share/gnome-shell/extensions/${F%.strip.zip};                    mkdir -p $D && bsdtar xf $F -C $D --strip-components=1; done && rm *.strip.zip && \
    for F in       *.zip; do D=/usr/share/gnome-shell/extensions/${F%.zip}; D=${D%.shell-extension}; mkdir -p $D && bsdtar xf $F -C $D;                      done && rm       *.zip && \
    glib-compile-schemas /usr/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/schemas

RUN curl -sLO --output-dir /usr/share/fonts https://github.com/dmlls/whatsapp-emoji-linux/releases/latest/download/WhatsAppEmoji.ttf


### base ###
FROM common AS base

COPY files/ /
RUN mv /usr/bin/uname{.orig,} && rm -r * && dconf update


### nvidia ###
FROM common AS nvidia

RUN --mount=type=cache,dst=/var/cache/libdnf5 --mount=type=bind,src=build-env/dnf.conf,dst=/etc/dnf/dnf.conf,z \
    curl -sLOO --output-dir /etc/yum.repos.d                                                                   \
        https://negativo17.org/repos/fedora-nvidia-580.repo                                                    \
        https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo               && \
    dnf install -y --disable-repo=fedora-multimedia nvidia-driver{,-libs.i686,-cuda-libs} dkms-nvidia       && \
    dnf versionlock add                             nvidia-driver{,-libs.i686,-cuda-libs} dkms-nvidia       && \
    dnf install -y cuda{,-cudnn} nvidia-container-toolkit nvtop                                             && \
    echo NoDisplay=true >>/usr/share/applications/nvtop.desktop

RUN python -m venv /usr/lib/nvidia-venv && /usr/lib/nvidia-venv/bin/pip install nvidia-ml-py

RUN --mount=type=cache,dst=/.cache/uv                                                       \
    dnf install -y python3.12                                                            && \
    PIPX_GLOBAL_HOME=/usr/lib/pipx PIPX_GLOBAL_BIN_DIR=/usr/bin PIPX_MAN_DIR=/usr/share/man \
    pipx install --global --python=python3.12 whisper-ctranslate2

RUN --mount=type=cache,dst=.                                                                              \
    if ! [ -f ollama-linux-amd64.tar.zst ]                                                              ; \
    then                                                                                                  \
        curl -sLO https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst  ; \
    fi                                                                                                 && \
    tar xf ollama-linux-amd64.tar.zst -C /usr --exclude=libcu*.so* --exclude=cuda_v12

COPY files/ files-nvidia/ /
RUN mv /usr/bin/uname{.orig,} && rm -r * && dconf update
