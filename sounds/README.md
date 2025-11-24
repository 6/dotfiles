# Claude Code Notification Sounds

This directory contains audio files for Claude Code notification hooks.

## Current Setup

- **Notification** (needs input): `Purr.aiff`
- **Stop** (task done): `Funk.aiff`

## How It Works

The `play.sh` script automatically detects your OS and uses the appropriate audio player:
- **macOS**: `afplay`
- **Linux**: `paplay` (PulseAudio), `aplay` (ALSA), `ffplay` (ffmpeg), or `mpg123`

## Supported Audio Formats

- **AIFF** - Best for macOS, works on Linux with most players
- **WAV** - Universal support, works everywhere
- **MP3** - Smaller files, needs `mpg123` on Linux
- **OGG** - Good compression, needs appropriate player

## Linux Setup

On most modern Linux distros, PulseAudio is pre-installed. If sounds don't work:

```bash
# Ubuntu/Debian
sudo apt install pulseaudio-utils  # for paplay

# Or install alternative players
sudo apt install alsa-utils         # for aplay (WAV only)
sudo apt install ffmpeg             # for ffplay (all formats)
sudo apt install mpg123             # for mpg123 (MP3)
```

### Tips

- Keep files under 1MB for fast playback
- 0.5-2 seconds is ideal duration
- Convert to AIFF or WAV for best compatibility
- Use `ffmpeg` to convert: `ffmpeg -i input.mp3 output.aiff`

## Changing Sounds

1. Download a sound and save it to this directory (`~/dotfiles/sounds/`)
2. Update `~/.claude/settings.json` with just the filename:

```json
"hooks": {
  "Notification": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/dotfiles/sounds/play.sh your-sound.aiff"
        }
      ]
    }
  ]
}
```

**Note:** `play.sh` automatically looks for sounds in its own directory, so you only need to specify the filename.

## macOS System Sounds

Available on macOS at `/System/Library/Sounds/`:
- Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

Preview them: `afplay /System/Library/Sounds/Hero.aiff`
