t# ffmpeg-quick-convert
# FFmpeg QuickConvert (macOS Finder Quick Action)

Right-click any media file in Finder → pick a target format → convert.
Audio and video. Batch safe. Zero overwrites. Uses FFmpeg locally.

## Requirements
- macOS 12+
- FFmpeg (and ffprobe) installed via Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ffmpeg
```

## Install as a Quick Action      
1. Open **Automator** → New → **Quick Action**  
2. Header:
   - Workflow receives: **files or folders**
   - In: **Finder.app**
   - Allow multiple: **ON**
3. Add **Run Shell Script**
   - Shell: `/bin/zsh`
   - Pass input: **as arguments**
4. Paste the contents of `src/convert-anything.sh` into the script box.
5. Save as **Convert: Anything → Anything**. Automator will save to `~/Library/Services`.

Enable in Finder: Finder → Settings → **Extensions** → Finder → **Quick Actions** → check your workflow.

## Use
- Right-click one or more files → **Quick Actions** → **Convert: Anything → Anything**
- Choose target format:
  - Audio: `mp3`, `flac`, `wav`, `m4a`, `aac`, `opus`, `ogg`
  - Video: `mp4` (H.264), `mkv` (H.265), `mov_prores` (ProRes 422 HQ), `webm` (VP9), `gif`
- Outputs are written next to sources. If the name exists, a timestamp is appended.

## One-click hard-coded variants
Create another Quick Action using the same script, but set env vars above it:

```zsh
export CONVERT_TO=mp3
export BR_AUDIO=320
```

or

```zsh
export CONVERT_TO=mp4
export CRF_VIDEO=23
export MAXW=1920
```

The script will skip dialogs when these are provided.

## Troubleshooting
- Action “does nothing”: ensure **Pass input: as arguments**.  
- “ffmpeg not found”: Automator’s PATH is small; this script exports `/opt/homebrew/bin`.  
- Permission denied: convert files inside folders you own.  
- Automator blank error: the script echoes `done` at the end to satisfy Automator.

## License
MIT
