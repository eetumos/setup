### common ###
FROM quay.io/fedora/fedora-silverblue:43 AS common
RUN dnf remove -y gnome-software{,-rpm-ostree} firefox{,-langpacks} yelp sos python3-botocore
ENV PATH=/usr/bin

WORKDIR /tmp
RUN mv /usr/bin/uname{,.orig}
COPY build-env/uname /usr/bin/uname


### kernel ###
ARG KERNEL=6.18
RUN if [[ $(rpm -q --qf %{version} kernel) > $KERNEL.999 ]]                                              ; \
    then                                                                                                   \
        rpm-ostree uninstall -y kernel{,-core} kernel-modules{,-core,-extra} virtualbox-guest-additions && \
        rpm-ostree   install -y kernel{,-modules-extra}-$KERNEL.*                                       && \
        dnf versionlock add kernel-core                                                                  ; \
    fi

RUN dnf install -y kernel-devel-matched "kernel-headers <= $(rpm -q --qf %{version} kernel)" rpm-build

RUN dnf install -y https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm -E %dist).noarch.rpm && \
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
    dnf install -y langpacks-fi nautilus gnome-{tweaks,boxes}                                                  \
                   {h,b}top {s,l}trace socat iotop-c nethogs nmap wev                                          \
                   smartmontools sg3_utils android-tools wireshark tio                                         \
                   tmux nnn neovim ripgrep rclone aria2 git-lfs pwgen tini fzf                                 \
                   unrar p7zip-plugins bsdtar mediainfo mkvtoolnix tesseract                                   \
                   rpmdevtools cargo fontconfig-devel pipx uv python3-devel cmake meson gdb perf               \
                   wireguard-tools msmtp golang-github-acme-lego                                               \
                   steam gamescope mangohud egl-utils vulkan-tools igt-gpu-tools vulkan-validation-layers   && \
    setcap CAP_PERFMON=ep /usr/bin/intel_gpu_top CAP_PERFMON=ep /usr/bin/btop                               && \
    echo NoDisplay=true | tee -a /usr/share/applications/{nvim,htop}.desktop >/dev/null
RUN fix() { cat /etc/$1 >>/usr/lib/$1; cp /dev/null /etc/$1; } && \
    fix passwd                                                 && \
    fix group

RUN --mount=type=bind,src=patches/rpm,dst=patches,z \
    ./patches/patch-n-build                      && \
    dnf reinstall -y *.rpm                       && \
    rm -r /.cache    *.rpm

RUN dnf copr enable -y iucar/rstudio && \
    dnf install -y rstudio-desktop {R,libcurl,fribidi,libtiff}-devel

RUN CARGO_HOME=cargo-home cargo install --locked --root=/usr --no-track dufs tokei fclones binwalk && \
    rm -r cargo-home

RUN dnf install -y libusb1-devel systemd-devel                                            && \
    PIPX_GLOBAL_HOME=/usr/lib/pipx PIPX_GLOBAL_BIN_DIR=/usr/bin PIPX_MAN_DIR=/usr/share/man  \
    pipx install --global yt-dlp[default,secretstorage,curl-cffi] ocrmypdf pgsrip icoextract \
                          pulsemixer liquidctl undervolt

RUN curl -sL https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip | bsdtar xC /usr/bin --strip-components=1 && \
    chmod 755 /usr/bin/bun

RUN curl -sLo /usr/bin/kepubify https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-64bit && \
    chmod +x  /usr/bin/kepubify

RUN curl -sL https://github.com/samtools/samtools/releases/latest/download/samtools-1.23.tar.bz2 | tar xj && \
    cd samtools-* && ./configure --prefix=/usr && make -j && make install && cd .. && rm -r samtools-*    && \
    curl -sL https://github.com/samtools/bcftools/releases/latest/download/bcftools-1.23.tar.bz2 | tar xj && \
    cd bcftools-* && ./configure --prefix=/usr && make -j && make install && cd .. && rm -r bcftools-*    && \
    curl -sL https://github.com/samtools/htslib/releases/latest/download/htslib-1.23.tar.bz2     | tar xj && \
    cd   htslib-* && ./configure --prefix=/usr && make -j && make install && cd .. && rm -r   htslib-*

RUN --mount=type=bind,src=patches/monado,dst=patches,z                                          \
    dnf install -y {eigen3,hidapi,openxr,systemd,vulkan-loader,wayland,wayland-protocols}-devel \
                   lib{drm,glvnd,usb1,v4l,Xrandr}-devel glslang                              && \
    git clone --recurse-submodules https://gitlab.freedesktop.org/monado/monado.git          && \
    cd monado                                                                                && \
    for P in ../patches/*; do git apply $P; done                                             && \
    cmake  -B       build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr                \
                          -DBUILD_TESTING=OFF -DXRT_FEATURE_SERVICE=OFF                      && \
    cmake --build   build -j                                                                 && \
    cmake --install build                                                                    && \
    cd .. && rm -r monado

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
    curl -sLO --output-dir /etc/yum.repos.d https://negativo17.org/repos/fedora-nvidia-580.repo             && \
    dnf install -y --disable-repo=fedora-multimedia nvidia-driver{,-libs.i686,-cuda-libs} dkms-nvidia       && \
    dnf versionlock add                             nvidia-driver{,-libs.i686,-cuda-libs} dkms-nvidia       && \
    dnf install -y cuda{,-cudnn,-cupti} libcusparselt golang-github-nvidia-container-toolkit nvtop          && \
    echo NoDisplay=true >>/usr/share/applications/nvtop.desktop

RUN --mount=type=cache,dst=/.cache/pip                                                    \
    dnf install -y python3.10-devel                                                    && \
    python3.10 -m venv /usr/lib/nvidia-venv                                            && \
    source             /usr/lib/nvidia-venv/bin/activate                               && \
    pip download --index-url=https://download.pytorch.org/whl/cu130 --no-deps torch    && \
    torch=$(unzip -p torch-*.whl torch-*/METADATA)                                     && \
    for p in $(rg -oP 'Requires-Dist: \Knvidia-(cu)?(blas|da-cupti|da-nvrtc|da-runtime|dnn|fft|file|pti|rand|solver|sparse|nvjitlink).*?(?=;)' <<< $torch | sed -e 's/-/_/g' -e 's/==/-/'); \
    do                                                                                    \
        mkdir /usr/lib/nvidia-venv/lib64/python3.10/site-packages/$p.dist-info         && \
        touch /usr/lib/nvidia-venv/lib64/python3.10/site-packages/$p.dist-info/METADATA ; \
    done                                                                               && \
    pip install --index-url=https://download.pytorch.org/whl/cu130 torch-*.whl            \
        -c <(echo torch==$(rg -oP '^Version: \K.*$' <<< $torch))                       && \
    pip install nvidia-ml-py nemo_toolkit[asr]                                         && \
    rm torch-*.whl

RUN PIPX_GLOBAL_HOME=/usr/lib/pipx PIPX_GLOBAL_BIN_DIR=/usr/bin PIPX_MAN_DIR=/usr/share/man \
    pipx install --global --python=python3.10 whisper-ctranslate2

RUN --mount=type=cache,dst=.                                                                              \
    if ! [ -f ollama-linux-amd64.tar.zst ]                                                              ; \
    then                                                                                                  \
        curl -sLO https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst  ; \
    fi                                                                                                 && \
    tar xf ollama-linux-amd64.tar.zst -C /usr --exclude=libcu*.so* --exclude=cuda_v12

COPY files/ files-nvidia/ /
RUN mv /usr/bin/uname{.orig,} && rm -r * && dconf update
