#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${AUDIO:="N"}"    # Browser audio support (Y/N)

[[ "${AUDIO,,}" != [Yy1]* ]] && return 0

msg="Initializing audio support..."
html "$msg"
[[ "${DEBUG}" == [Yy1]* ]] && echo "$msg"

# Copy audio plugin to nginx-served directory
cp /usr/share/novnc/audio-plugin.js /run/shm/audio-plugin.js

# Start PulseAudio with null sink
mkdir -p /tmp/pulse
rm -f /tmp/pulse/pid
PULSE_RUNTIME_PATH=/tmp/pulse HOME=/root \
  pulseaudio --exit-idle-time=-1 --log-target=stderr --log-level=0 &

# Wait for PulseAudio Unix socket (up to 15 seconds)
for i in $(seq 1 30); do
  [ -S /tmp/pulse/native ] && break
  sleep 0.5
done

if [ ! -S /tmp/pulse/native ]; then
  warn "PulseAudio failed to start; audio will be unavailable."
  return 0
fi

# Start audio proxy: GStreamer encodes PulseAudio → WebM/Opus → raw TCP on port 5711
PULSE_SERVER=unix:/tmp/pulse/native HOME=/root \
  /usr/local/bin/audio-proxy.sh -l 5711 &

# Start websockify to bridge browser WebSocket → raw TCP audio proxy
websockify 127.0.0.1:5712 127.0.0.1:5711 &

# Append QEMU audio device arguments
ARGS+=" -audiodev pa,id=snd0,server=unix:/tmp/pulse/native"
ARGS+=" -device intel-hda -device hda-duplex,audiodev=snd0"

return 0
