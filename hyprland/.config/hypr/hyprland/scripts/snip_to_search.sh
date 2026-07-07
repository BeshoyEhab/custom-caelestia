#!/usr/bin/env bash
# Google Lens screen region search
hyprshot -m region -z -o /tmp -f lens_image.png
imageLink=$(curl -sF files[]=@/tmp/lens_image.png 'https://uguu.se/upload' | jq -r '.files[0].url')
xdg-open "https://lens.google.com/uploadbyurl?url=${imageLink}"
rm /tmp/lens_image.png
