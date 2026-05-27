# syntax=docker/dockerfile:1

FROM debian:trixie-slim

ARG TARGETARCH
ARG VERSION_ARG="0.0"
ARG VERSION_QMP="0.0.6"
ARG VERSION_UTK="1.2.0"
ARG VERSION_VNC="1.7.0"
ARG VERSION_PASST="2026_05_07"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        bc \
        jq \
        xxd \
        tini \
        wget \
        7zip \
        curl \
        ovmf \
        fdisk \
        nginx \
        swtpm \
        procps \
        ethtool \
        iptables \
        iproute2 \
        dnsmasq \
        xz-utils \
        apt-utils \
        net-tools \
        e2fsprogs \
        qemu-utils \
        websocketd \
        iputils-ping \
        genisoimage \
        inotify-tools \
        netcat-openbsd \
        ca-certificates \
        git \
        qemu-system-x86 \
        pulseaudio \
        gstreamer1.0-tools \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        socat \
        python3-websockify \
        python3 \
        python3-pip && \
    pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore "qemu.qmp==${VERSION_QMP}" && \
    wget "https://github.com/qemus/passt/releases/download/v${VERSION_PASST}/passt_${VERSION_PASST}_${TARGETARCH}.deb" -O /tmp/passt.deb -q --timeout=10 && \
    dpkg -i /tmp/passt.deb && \
    apt-get download qemu-system-gui && \
    dpkg-deb -x qemu-system-gui_*.deb /tmp/qemu-gui && \
    cp /tmp/qemu-gui/usr/lib/x86_64-linux-gnu/qemu/audio-pa.so /usr/lib/x86_64-linux-gnu/qemu/ && \
    rm -rf /tmp/qemu-gui qemu-system-gui_*.deb && \
    apt-get clean && \
    mkdir -p /etc/qemu && \
    echo "allow br0" > /etc/qemu/bridge.conf && \
    mkdir -p /usr/share/novnc && \
    wget "https://github.com/novnc/noVNC/archive/refs/tags/v${VERSION_VNC}.tar.gz" -O /tmp/novnc.tar.gz -q --timeout=10 && \
    tar -xf /tmp/novnc.tar.gz -C /tmp/ && \
    cd "/tmp/noVNC-${VERSION_VNC}" && \
    mv app core vendor package.json ./*.html /usr/share/novnc && \
    git clone --depth 1 https://github.com/me-asri/noVNC-audio-plugin.git /tmp/audio-plugin && \
    cp /tmp/audio-plugin/audio-proxy.sh /usr/local/bin/audio-proxy.sh && \
    chmod +x /usr/local/bin/audio-proxy.sh && \
    sed -i 's|tcpclientsrc port="${pulse_port}" ! \(queue ! \)\?rawaudioparse use-sink-caps=false format=pcm pcm-format="${pulse_format}" sample-rate="${pulse_sample_rate}" num-channels="${pulse_channels}"|pulsesrc server=unix:/tmp/pulse/native device=qemu_output.monitor|g' /usr/local/bin/audio-proxy.sh && \
    sed -i "s|customSettings: {},|customSettings: { defaults: {}, mandatory: {} },|" /usr/share/novnc/app/ui.js && \
    rm -rf /tmp/audio-plugin && \
    unlink /etc/nginx/sites-enabled/default && \
    sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf && \
    echo "$VERSION_ARG" > /run/version && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --chmod=755 ./src /run/
COPY --chmod=644 audio/audio-plugin.js /usr/share/novnc/audio-plugin.js
COPY --chmod=644 audio/webutil.js /usr/share/novnc/app/webutil.js
COPY --chmod=755 ./web /var/www/
COPY --chmod=664 ./web/conf/defaults.json /usr/share/novnc
COPY --chmod=664 ./web/conf/mandatory.json /usr/share/novnc
COPY --chmod=744 ./web/conf/nginx.conf /etc/nginx/default.conf
COPY --chmod=644 audio/pulse-default.pa /etc/pulse/default.pa

RUN sed -i 's|</head>|<script type="module" crossorigin="anonymous" src="audio-plugin.js"></script></head>|' /usr/share/novnc/vnc.html

ADD --chmod=755 "https://github.com/qemus/fiano/releases/download/v${VERSION_UTK}/utk_${VERSION_UTK}_${TARGETARCH}.bin" /run/utk.bin

VOLUME /storage
EXPOSE 22 5900 8006

ENV BOOT="alpine"
ENV CPU_CORES="2"
ENV RAM_SIZE="2G"
ENV DISK_SIZE="64G"
ENV AUDIO="N"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
