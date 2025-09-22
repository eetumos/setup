### NOTE: common ###
FROM quay.io/fedora/fedora-silverblue:42 AS common
RUN dnf remove -y gnome-software{,-rpm-ostree} firefox{,-langpacks} yelp

WORKDIR /tmp
COPY build-env/uname .
ENV PATH=/tmp:/usr/bin


### NOTE: kernel ###
ARG KERNEL=6.16
RUN if [[ $(rpm -q --qf %{version} kernel) > $KERNEL.999 ]]; then                                          \
        rpm-ostree uninstall -y kernel{,-core} kernel-modules{,-core,-extra} virtualbox-guest-additions && \
        rpm-ostree   install -y kernel{,-modules-extra}-$KERNEL.*                                       && \
        dnf versionlock add kernel-core                                                                 ;  \
    fi

RUN dnf install -y kernel-devel-matched "kernel-headers <= $(rpm -q --qf %{version} kernel)" rpm-build

RUN dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-8$(rpm -E %dist).noarch.rpm && \
    dnf install -y zfs                                                                     && \
    dkms autoinstall

RUN curl -sL https://github.com/BoukeHaarsma23/zenergy/archive/master.tar.gz | tar xz && \
    make -C zenergy-master -j modules                                                 && \
    make -C zenergy-master    modules_install clean                                   && \
    rm   -r zenergy-master

RUN dnf install -y https://github.com/winterheart/broadcom-bt-firmware/releases/latest/download/broadcom-bt-firmware-12.0.1.1105.rpm

RUN depmod $(rpm -q --qf %{version}-%{release}.%{arch} kernel)


### NOTE: userland ###
RUN --mount=type=cache,dst=/var/cache/libdnf5 --mount=type=bind,src=build-env/dnf.conf,dst=/etc/dnf/dnf.conf,z \
    curl -sLO --output-dir /etc/yum.repos.d https://negativo17.org/repos/fedora-multimedia.repo             && \
    dnf update -y

RUN --mount=type=cache,dst=/var/cache/libdnf5 --mount=type=bind,src=build-env/dnf.conf,dst=/etc/dnf/dnf.conf,z \
    dnf install -y langpacks-fi nautilus gnome-{tweaks,boxes}                                                  \
                   {h,b}top strace socat iotop-c nethogs nmap wev                                              \
                   smartmontools sg3_utils android-tools                                                       \
                   tmux nnn rclone neovim ripgrep fzf pwgen git-lfs aria2                                      \
                   unrar p7zip-plugins bsdtar mediainfo mkvtoolnix tesseract                                   \
                   cargo fontconfig-devel pipx uv python3-devel cmake meson perf                               \
                   wireguard-tools msmtp golang-github-acme-lego                                               \
                   steam gamescope mangohud vulkan-tools igt-gpu-tools freerdp                              && \
    setcap CAP_PERFMON=ep /usr/bin/intel_gpu_top CAP_PERFMON=ep /usr/bin/btop                               && \
    echo NoDisplay=true | tee -a /usr/share/applications/{nvim,htop}.desktop >/dev/null
RUN fix() { cat /etc/$1 >>/usr/lib/$1; cp /dev/null /etc/$1; } && \
    fix passwd                                                 && \
    fix group

RUN --mount=type=bind,src=patches/rpm,dst=patches,z \
    ./patches/patch-n-build                      && \
    dnf reinstall -y *.rpm                       && \
    rm               *.rpm

RUN dnf copr enable -y iucar/rstudio && \
    dnf install -y rstudio-desktop {R,libcurl,fribidi,libtiff}-devel

RUN CARGO_HOME=cargo-home cargo install --locked --root=/usr --no-track dufs tokei fclones binwalk && \
    rm -r cargo-home

RUN PIPX_GLOBAL_HOME=/usr/lib/pipx PIPX_GLOBAL_BIN_DIR=/usr/bin PIPX_MAN_DIR=/usr/share/man  \
    pipx install --global yt-dlp[default,secretstorage,curl-cffi] ocrmypdf pgsrip icoextract \
                          pulsemixer liquidctl undervolt

RUN curl -sL https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip | bsdtar xC /usr/bin --strip-components=1 && \
    chmod 755 /usr/bin/bun

RUN curl -sLo /usr/bin/kepubify https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-64bit && \
    chmod +x  /usr/bin/kepubify

RUN --mount=type=bind,src=patches/monado,dst=patches,z                                                                           \
    dnf install -y {openxr,vulkan-loader,wayland,wayland-protocols,systemd,libdrm,hidapi,libusb1,libv4l,eigen3}-devel glslang && \
    git clone --recurse-submodules https://gitlab.freedesktop.org/monado/monado.git                                           && \
    cd monado                                                                                                                 && \
    for P in ../patches/*; do git apply $P; done                                                                              && \
    cmake  -B       build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_TESTING=OFF -DXRT_HAVE_XLIB=OFF         \
                          -DXRT_FEATURE_SERVICE=OFF                                                                           && \
    cmake --build   build -j                                                                                                  && \
    cmake --install build                                                                                                     && \
    cd .. && rm -r monado

RUN curl -sLOOO -o date-menu-formatter@marcinjakubowski.github.com.strip.zip -o lan-ip-address@mrhuber.com.strip.zip                                  \
        https://github.com/eetumos/battery-time/releases/latest/download/battery-time@eetumos.github.com.shell-extension.zip                          \
        https://github.com/Leleat/Tiling-Assistant/releases/download/v52/tiling-assistant@leleat-on-github.shell-extension.zip                        \
        https://github.com/stuarthayhurst/alphabetical-grid-extension/releases/latest/download/AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip \
        https://github.com/marcinjakubowski/date-menu-formatter/archive/master.zip                                                                    \
        https://github.com/Josholith/gnome-extension-lan-ip-address/archive/master.zip                                                             && \
    for F in *.strip.zip; do D=/usr/share/gnome-shell/extensions/${F%.strip.zip};                    mkdir -p $D && bsdtar xf $F -C $D --strip-components=1; done && rm *.strip.zip && \
    for F in       *.zip; do D=/usr/share/gnome-shell/extensions/${F%.zip}; D=${D%.shell-extension}; mkdir -p $D && bsdtar xf $F -C $D;                      done && rm       *.zip && \
    glib-compile-schemas /usr/share/gnome-shell/extensions/AlphabeticalAppGrid@stuarthayhurst/schemas

RUN curl -sLO --output-dir /usr/share/fonts https://github.com/dmlls/whatsapp-emoji-linux/releases/latest/download/WhatsAppEmoji.ttf


### NOTE: base ###
FROM common AS base

COPY files/ /
RUN rm -r * && dconf update


### NOTE: nvidia ###
FROM common AS nvidia

RUN --mount=type=cache,dst=/var/cache/libdnf5 --mount=type=bind,src=build-env/dnf.conf,dst=/etc/dnf/dnf.conf,z \
    --mount=type=bind,src=files-nvidia/etc/nvidia/kernel.conf,dst=/etc/nvidia/kernel.conf,z                    \
    dnf install -y nvidia-driver{,-libs.i686} dkms-nvidia cuda{,-cudnn}                                        \
                   nvidia-settings golang-github-nvidia-container-toolkit nvtop                             && \
    rm -f /etc/nvidia/kernel.conf.rpmnew                                                                    && \
    echo NoDisplay=true >>/usr/share/applications/nvtop.desktop                                             && \
    dkms autoinstall

RUN python -m venv /usr/lib/nvidia-venv && /usr/lib/nvidia-venv/bin/pip install nvidia-ml-py

RUN dnf install -y python3.12                                                            && \
    PIPX_GLOBAL_HOME=/usr/lib/pipx PIPX_GLOBAL_BIN_DIR=/usr/bin PIPX_MAN_DIR=/usr/share/man \
    pipx install --global --python=python3.12 whisper-ctranslate2

RUN --mount=type=cache,dst=.                                                                                                       \
    [ -f ollama-linux-amd64.tgz ] || curl -sLO https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tgz && \
    tar xf ollama-linux-amd64.tgz --exclude=libcu*.so*                                                                          && \
    mv bin/ollama /usr/bin/ && mv lib/ollama /usr/lib/ && rm -r bin lib

COPY files/ files-nvidia/ /
RUN rm -r * && dconf update
