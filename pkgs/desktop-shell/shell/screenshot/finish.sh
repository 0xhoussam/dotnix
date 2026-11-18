#!/usr/bin/env bash
# Output step of the screenshot tool. Called by ScreenshotService.finish():
#   finish.sh <png> <save-dir> <copy|save|ocr>
# The PNG is already cropped and annotated; this only copies, files or reads it.
tmp=$1
dir=$2
kind=$3

# temp shots are only kept long enough for the notification thumbnail
find "$(dirname "$tmp")" -name 'shot-*.png' -mmin +120 -delete 2>/dev/null

note() { notify-send -a Screenshot -i "$tmp" "$@"; }

case "$kind" in
  copy)
    wl-copy --type image/png < "$tmp" && note "Screenshot copied" "Image is on the clipboard"
    ;;
  save)
    mkdir -p "$dir" || exit 1
    out="$dir/screenshot-$(date +%F_%H-%M-%S).png"
    if cp "$tmp" "$out"; then
      rm -f "$tmp"
      notify-send -a Screenshot -i "$out" "Screenshot saved" "$out"
    fi
    ;;
  ocr)
    if ! command -v tesseract >/dev/null; then
      notify-send -a Screenshot "OCR unavailable" "tesseract is not installed"
      exit 1
    fi
    txt=$(tesseract "$tmp" - 2>/dev/null)
    if printf %s "$txt" | grep -q '[^[:space:]]'; then
      printf %s "$txt" | wl-copy
      note "Text copied" "$(printf %s "$txt" | head -c 200)"
    else
      note "No text found" "Nothing readable in the selection"
    fi
    ;;
esac
