#!/bin/zsh
# macOS Finder Quick Action — Convert Anything → Anything with FFmpeg
# Use inside Automator "Run Shell Script": Shell=/bin/zsh, Pass input=as arguments
# You can also run this from Terminal: ./convert-anything.sh <files...>

# PATH for Automator
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
FFMPEG="$(command -v ffmpeg)"
FFPROBE="$(command -v ffprobe)"
if [[ -z "$FFMPEG" || -z "$FFPROBE" ]]; then
  osascript -e 'display alert "FFmpeg/ffprobe not found" message "Install via Homebrew: brew install ffmpeg"'
  echo "missing ffmpeg"
  exit 1
fi

# If environment variable CONVERT_TO is set, skip user prompt
if [[ -n "${CONVERT_TO:-}" ]]; then
  FORMAT="${CONVERT_TO:l}"
else
  CHOICE=$(osascript -e 'choose from list {"mp3","flac","wav","m4a","aac","opus","ogg","mp4","mkv","mov_prores","webm","gif"} with prompt "Select output format" default items {"mp3"}')
  [[ "$CHOICE" == "false" || -z "$CHOICE" ]] && { echo "cancel"; exit 0; }
  FORMAT="${CHOICE:l}"
fi

# Optional knobs
BR_AUDIO="${BR_AUDIO:-}"
CRF_VIDEO="${CRF_VIDEO:-}"
MAXW="${MAXW:-}"

if [[ "$FORMAT" =~ ^(mp3|m4a|aac|opus|ogg)$ && -z "$BR_AUDIO" ]]; then
  BR_AUDIO=$(osascript -e 'text returned of (display dialog "Audio bitrate kbps (blank uses defaults)\nExamples: 128, 192, 256, 320" default answer "")')
fi
if [[ "$FORMAT" =~ ^(mp4|mkv|webm|mov_prores|gif)$ && -z "$CRF_VIDEO" ]]; then
  CRF_VIDEO=$(osascript -e 'text returned of (display dialog "Video CRF (blank uses defaults)\nH.264 ≈ 23, H.265 ≈ 28, VP9 ≈ 32" default answer "")')
  MAXW=$(osascript -e 'text returned of (display dialog "Max width px (blank keeps original)\nExample: 1920" default answer "")')
fi

converted=0
failed=0

is_video() {
  "$FFPROBE" -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$1" | grep -qi video
}
is_audio() {
  "$FFPROBE" -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$1" | grep -qi audio
}

for inpath in "$@"; do
  [[ -f "$inpath" ]] || { failed=$((failed+1)); continue; }

  dir="${inpath%/*}"
  base="${inpath##*/}"
  name="${base%.*}"
  ext="$FORMAT"
  out="${dir}/${name}.${ext}"
  [[ -e "$out" ]] && out="${dir}/${name}_$(date +%Y%m%d_%H%M%S).${ext}"

  vfilters=()
  [[ -n "$MAXW" ]] && vfilters+=( "scale='min(iw,${MAXW})':-2" )

  cmd=()

  case "$FORMAT" in
    mp3)
      if is_audio "$inpath"; then
        br=(); [[ -n "$BR_AUDIO" ]] && br=( -b:a "${BR_AUDIO}k" )
        cmd=( -vn -c:a libmp3lame "${br[@]}" )
      else osascript -e 'display alert "Not audio" message "'"$base → mp3"'"'; failed=$((failed+1)); continue; fi ;;
    flac)
      if is_audio "$inpath"; then cmd=( -vn -c:a flac )
      else osascript -e 'display alert "Not audio" message "'"$base → flac"'"'; failed=$((failed+1)); continue; fi ;;
    wav)
      if is_audio "$inpath"; then cmd=( -vn -c:a pcm_s16le )
      else osascript -e 'display alert "Not audio" message "'"$base → wav"'"'; failed=$((failed+1)); continue; fi ;;
    m4a|aac)
      if is_audio "$inpath"; then
        ext="m4a"; out="${dir}/${name}.${ext}"; [[ -e "$out" ]] && out="${dir}/${name}_$(date +%Y%m%d_%H%M%S).${ext}"
        br=(); [[ -n "$BR_AUDIO" ]] && br=( -b:a "${BR_AUDIO}k" )
        cmd=( -vn -c:a aac "${br[@]}" -movflags +faststart )
      else osascript -e 'display alert "Not audio" message "'"$base → m4a/aac"'"'; failed=$((failed+1)); continue; fi ;;
    opus)
      if is_audio "$inpath"; then br=(); [[ -n "$BR_AUDIO" ]] && br=( -b:a "${BR_AUDIO}k" ); cmd=( -vn -c:a libopus "${br[@]}" )
      else osascript -e 'display alert "Not audio" message "'"$base → opus"'"'; failed=$((failed+1)); continue; fi ;;
    ogg)
      if is_audio "$inpath"; then
        if [[ -n "$BR_AUDIO" ]]; then cmd=( -vn -c:a libvorbis -b:a "${BR_AUDIO}k" )
        else cmd=( -vn -c:a libvorbis -q:a 5 ); fi
      else osascript -e 'display alert "Not audio" message "'"$base → ogg"'"'; failed=$((failed+1)); continue; fi ;;
    mp4)
      if is_video "$inpath"; then
        crf="${CRF_VIDEO:-23}"
        vf=""; [[ ${#vfilters[@]} -gt 0 ]] && vf="-vf ${vfilters[*]}"
        cmd=( -c:v libx264 -preset medium -crf "$crf" -pix_fmt yuv420p $vf -c:a aac -b:a 192k -movflags +faststart )
      else osascript -e 'display alert "Not video" message "'"$base → mp4"'"'; failed=$((failed+1)); continue; fi ;;
    mkv)
      if is_video "$inpath"; then
        crf="${CRF_VIDEO:-28}"; vf=""; [[ ${#vfilters[@]} -gt 0 ]] && vf="-vf ${vfilters[*]}"
        cmd=( -c:v libx265 -preset medium -crf "$crf" $vf -c:a aac -b:a 160k )
      else osascript -e 'display alert "Not video" message "'"$base → mkv"'"'; failed=$((failed+1)); continue; fi ;;
    mov_prores)
      if is_video "$inpath"; then
        vf=""; [[ ${#vfilters[@]} -gt 0 ]] && vf="-vf ${vfilters[*]}"
        ext="mov"; out="${dir}/${name}.${ext}"; [[ -e "$out" ]] && out="${dir}/${name}_$(date +%Y%m%d_%H%M%S).${ext}"
        cmd=( -c:v prores_ks -profile:v 3 $vf -c:a pcm_s16le )
      else osascript -e 'display alert "Not video" message "'"$base → ProRes"'"'; failed=$((failed+1)); continue; fi ;;
    webm)
      if is_video "$inpath"; then
        crf="${CRF_VIDEO:-32}"; vf=""; [[ ${#vfilters[@]} -gt 0 ]] && vf="-vf ${vfilters[*]}"
        cmd=( -c:v libvpx-vp9 -b:v 0 -crf "$crf" -row-mt 1 -threads 4 $vf -c:a libopus -b:a 128k )
      else osascript -e 'display alert "Not video" message "'"$base → webm"'"'; failed=$((failed+1)); continue; fi ;;
    gif)
      if is_video "$inpath"; then
        pal="${dir}/${name}_palette.png"; fps="12"; scale="${MAXW:-640}"
        "$FFMPEG" -hide_banner -loglevel error -i "$inpath" -vf "fps=${fps},scale=${scale}:-2:flags=lanczos,palettegen" -y "$pal" || { failed=$((failed+1)); continue; }
        "$FFMPEG" -hide_banner -loglevel error -i "$inpath" -i "$pal" -lavfi "fps=${fps},scale=${scale}:-2:flags=lanczos [x];[x][1:v] paletteuse" -y "$out" \
          && rm -f "$pal" || { failed=$((failed+1)); continue; }
        converted=$((converted+1)); echo "$out"; continue
      else osascript -e 'display alert "Not video" message "'"$base → gif"'"'; failed=$((failed+1)); continue; fi ;;
    *)
      osascript -e 'display alert "Unsupported target format" message "'"$FORMAT"'"'
      failed=$((failed+1)); continue ;;
  esac

  if "$FFMPEG" -hide_banner -loglevel error -i "$inpath" "${cmd[@]}" "$out"; then
    converted=$((converted+1)); echo "$out"
  else
    osascript -e 'display alert "Conversion failed" message "'"$base → $FORMAT"'"'
    failed=$((failed+1))
  fi
done

osascript -e 'display notification "'"$converted"' converted • '"$failed"' failed" with title "FFmpeg Convert"'
echo "done"
exit 0
