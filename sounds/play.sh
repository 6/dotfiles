#!/usr/bin/env bash
# Cross-platform audio player for Claude Code notifications
# Usage: play.sh <audio-file>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If just a filename is provided, look for it in the script's directory
SOUND_FILE="$1"
if [[ "$SOUND_FILE" != /* ]] && [[ "$SOUND_FILE" != ~* ]]; then
  # Relative path or just filename - prepend script directory
  SOUND_FILE="$SCRIPT_DIR/$SOUND_FILE"
fi

# Expand tilde if present
SOUND_FILE="${SOUND_FILE/#\~/$HOME}"

if [[ ! -f "$SOUND_FILE" ]]; then
  echo "Error: Sound file not found: $SOUND_FILE" >&2
  exit 1
fi

# Detect OS and use appropriate audio player
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  afplay "$SOUND_FILE"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux - try different players in order of preference
  if command -v paplay &> /dev/null; then
    # PulseAudio (most modern Linux distros)
    paplay "$SOUND_FILE"
  elif command -v aplay &> /dev/null; then
    # ALSA (older, but widely available - WAV/AIFF only)
    aplay "$SOUND_FILE" 2>/dev/null
  elif command -v ffplay &> /dev/null; then
    # ffmpeg's player (if installed)
    ffplay -nodisp -autoexit -loglevel quiet "$SOUND_FILE"
  elif command -v mpg123 &> /dev/null; then
    # mpg123 for MP3 files
    mpg123 -q "$SOUND_FILE"
  else
    echo "Error: No audio player found. Install paplay, aplay, ffplay, or mpg123" >&2
    exit 1
  fi
else
  echo "Error: Unsupported OS: $OSTYPE" >&2
  exit 1
fi
