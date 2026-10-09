#!/bin/bash
# Usage: fit-video.sh <video> [max-bytes]
# GitLab rejects attachments over 10 MB, so the default is 10 MB (10,000,000 bytes).
set -e

in="$1"
max_bytes="${2:-10000000}"
[ -s "$in" ] || { echo "No video at $in" >&2; exit 1; }

size() { stat -f %z "$1" 2>/dev/null || stat -c %s "$1"; }
before=$(size "$in")
if [ "$before" -le "$max_bytes" ]; then
  echo "{\"file\":\"$in\",\"bytes\":$before,\"compressed\":false,\"fits\":true}"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Each step: longest side in pixels, then x264 CRF (higher is smaller).
while read -r side crf; do
  ffmpeg -nostdin -loglevel error -y -i "$in" -an \
    -vf "scale=w='min($side,iw)':h='min($side,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2" \
    -c:v libx264 -preset slow -crf "$crf" -pix_fmt yuv420p -movflags +faststart "$tmp/out.mp4"
  after=$(size "$tmp/out.mp4")
  echo "longest side $side, crf $crf: $after bytes" >&2
  if [ "$after" -le "$max_bytes" ]; then
    mv "$tmp/out.mp4" "$in"
    echo "{\"file\":\"$in\",\"bytes\":$after,\"before\":$before,\"compressed\":true,\"fits\":true}"
    exit 0
  fi
done <<EOF
1280 28
1280 32
960 35
720 38
EOF

echo "Still over $max_bytes bytes at the smallest step; the original is kept" >&2
echo "{\"file\":\"$in\",\"bytes\":$before,\"compressed\":false,\"fits\":false}"
exit 2
