# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  IS_MACOS=true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  IS_LINUX=true
fi

# Set Oh My Zsh theme conditionally
if [[ "$TERM_PROGRAM" == "vscode" ]] || [[ -n "$CCODE" ]]; then
  ZSH_THEME=""  # Disable Powerlevel10k for Cursor and CCode
else
  # Set name of the theme to load ( ~/.oh-my-zsh/themes/ )
  ZSH_THEME="powerlevel10k/powerlevel10k"

  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# Load Oh My Zsh (always)
export ZSH="$HOME/.oh-my-zsh"

# OPTIMIZATION: Skip Oh My Zsh automatic updates check (saves ~240ms)
# Update manually with: omz update
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

# OPTIMIZATION: Skip completion security check (saves time)
# Run manually if needed: compaudit
ZSH_DISABLE_COMPFIX=true

source $ZSH/oh-my-zsh.sh

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(bundler git zsh-autosuggestions)

# Couple of critical exports first:
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export UPDATE_ZSH_DAYS=30
export EDITOR='vim'
export GOPATH="$HOME/go"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH=$PATH:/usr/local/go/bin

# For ruby/fastlane:
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# macOS-specific configurations
if [[ -n "$IS_MACOS" ]]; then
  export PATH="$PATH:/opt/homebrew/bin"

  # OPTIMIZATION: Cache brew shellenv output (saves ~50ms)
  # Regenerate cache with: brew shellenv > ~/.brew_shellenv_cache
  if [[ -f ~/.brew_shellenv_cache ]]; then
    source ~/.brew_shellenv_cache
  else
    eval "$(brew shellenv)"
    brew shellenv > ~/.brew_shellenv_cache
  fi

  export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/tools:$PATH"
  export PATH="$PATH:/Applications/Android Studio.app/Contents/MacOS"
  export PATH="/Applications/Genymotion.app/Contents/MacOS/tools/:$PATH"
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
  export PATH="$HOMEBREW_PREFIX/opt/openssl@1.1/bin:$PATH"
  export PATH="$HOME/flutter/bin:$PATH"
  export PATH="$PATH:$HOME/.foundry/bin"
  export PATH="$PATH:/nix/var/nix/profiles/default/bin"
  export PATH="$PATH:/usr/local/share/dotnet/"

  export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export ANDROID_AVD_HOME="$HOME/.android/avd"
  export JAVA_HOME="/Applications/Android\ Studio.app/Contents/jbr/Contents/Home"

  export PATH=$PATH:$ANDROID_HOME/emulator
  export PATH=$PATH:$ANDROID_HOME/tools
  export PATH=$PATH:$ANDROID_HOME/tools/bin
  export PATH=$PATH:$ANDROID_HOME/platform-tools
fi

# Linux-specific configurations
if [[ -n "$IS_LINUX" ]]; then
  # Load rye if available
  if [ -f "$HOME/.rye/env" ]; then
    source "$HOME/.rye/env"
  fi
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.cache/lm-studio/bin"

export OLLAMA_HOST=0.0.0.0
export OLLAMA_ORIGINS=*

# Disable autosuggest for large buffers
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=true

# macOS-specific functions
if [[ -n "$IS_MACOS" ]]; then
  function screenshot() {
    local seconds=0
    if [[ $1 ]]; then seconds=$1; fi
    screencapture -x -T $seconds -t png ~/Desktop/screenshot-$(date +"%Y-%m-%d-%H-%M-%S").png
  }

  # Useful if you have to force-shutdown and leave Postgres in a weird state.
  function fixpg() {
    rm -f /usr/local/var/postgres/postmaster.pid
    brew services restart postgresql
    echo 'If still not working, try running `pg_ctl -D /usr/local/var/postgres start` to see full output.'
    echo 'or on M1: `pg_ctl -D /opt/homebrew/var/postgres start`'
  }

  # When OS X camera stops working occasionally.
  function fixcamera {
    sudo killall VDCAssistant
  }

  # Fix LoL config file (gets overwritten sometimes).
  function fixlol() {
    cp ~/.misc/PersistedSettings.json "/Applications/League of Legends.app/Contents/LoL/Config/PersistedSettings.json"
  }
fi

function spec() {
  test -e package.json && grep -q '"test":' package.json && yarn test $1
  test -e .rspec && bundle exec rspec $1
}

function mirror() {
  local url=$1
  local level=${2:-3}  # Default to level 3 if not specified

  wget --mirror \
       --level=$level \
       --convert-links \
       --adjust-extension \
       --page-requisites \
       --no-parent \
       -e robots=off \
       --reject gif,mp4,webm,mov \
       "$url"
}

function main() {
  # If main branch exists, use it, otherwise fall back to master:
  if git show-ref --quiet refs/heads/main; then
    git checkout main
  else
    git checkout master
  fi
}

# Return PID of process running on the given port:
function port() {
  if [[ -n "$IS_MACOS" ]]; then
    lsof -i tcp:"$1"
  elif [[ -n "$IS_LINUX" ]]; then
    lsof -i tcp:"$1" 2>/dev/null || ss -tlnp | grep ":$1 "
  fi
}

# https://docs.openwebui.com/getting-started/quick-start#updating
function upgradeoui() {
  docker rm -f open-webui
  docker pull ghcr.io/open-webui/open-webui:main
  docker run -d -p 4455:8080 -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:main
}

function linkmodels() {
  # Clean up all symlinks (not just broken ones) to start fresh:
  find ~/oss/llama.cpp/models/ -type l -exec rm -f {} \; 2>/dev/null

  # Remove empty directories left behind
  find ~/oss/llama.cpp/models/ -type d -empty -delete 2>/dev/null

  # Ensure target directory exists
  mkdir -p ~/oss/llama.cpp/models

  # Recursively find and link all .gguf files from ~/models/
  while IFS= read -r -d '' model_file; do
    # Get relative path from ~/models to preserve provider directory structure
    rel_path="${model_file#$HOME/models/}"
    target_path=~/oss/llama.cpp/models/"$rel_path"
    target_dir=$(dirname "$target_path")

    # Create target directory structure if needed
    mkdir -p "$target_dir"

    # Link to llama.cpp, preserving directory structure
    if [[ ! -e "$target_path" ]]; then
      ln -vs "$model_file" "$target_path"
    fi
  done < <(find ~/models -type f -name "*.gguf" -print0)

  # Note: Ollama cannot directly use .gguf files via symlinks or OLLAMA_MODELS.
}

# macOS-specific aliases
if [[ -n "$IS_MACOS" ]]; then
  alias fixdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
  alias fixsim='sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService'
  alias ap='osascript ~/.misc/airpods.applescript'
fi

alias a="code ."
alias mp3="youtube-dl --add-metadata -x --extract-audio --audio-format mp3"
alias most="du -hs * | gsort -rh | head -10"
alias gti='git'
alias igt='git'
alias gt='git'
alias cc='claude --model opus'
alias ccs='claude --model sonnet'
alias mainp='main && git pull'

function mainpd() {
  local prev_branch=$(git rev-parse --abbrev-ref HEAD)
  mainp

  # Check if branch is merged locally
  if git branch --merged | grep -q "^\s*${prev_branch}$"; then
    git branch -d "$prev_branch"
  # Check if remote branch has been deleted (PR was merged)
  elif ! git branch -r | grep -q "origin/${prev_branch}$"; then
    echo "Remote branch deleted (PR merged), force-deleting local branch..."
    git branch -D "$prev_branch"
  else
    echo "⚠️  Branch '${prev_branch}' is not merged and still exists on remote"
    echo "If you're sure the PR is merged, run: git branch -D ${prev_branch}"
  fi
}

# IMPORTANT: Load direnv and mise ONCE here (not again in .zsh_custom!)
eval "$(direnv hook zsh)"
eval "$(mise activate zsh)"

[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

# Load machine-specific ZSH configuration (if present)
if [ -f $HOME/.zsh_custom ]; then
  source "$HOME/.zsh_custom"
fi

if [ -f ~/google-cloud-sdk/completion.zsh.inc ]; then
  source ~/google-cloud-sdk/completion.zsh.inc
  source ~/google-cloud-sdk/path.zsh.inc
fi

# Use a minimal prompt in Cursor to avoid command detection issues
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
elif [[ -n "$CCODE" ]]; then
  # Orange/yellow prompt for CCode (Ghostty Code)
  # Enable git branch display
  autoload -Uz vcs_info
  precmd_vcs_info() { vcs_info }
  precmd_functions+=( precmd_vcs_info )
  setopt prompt_subst
  zstyle ':vcs_info:git:*' formats '%F{green}%b%f '
  zstyle ':vcs_info:*' enable git
  PROMPT='%F{208}%~%f ${vcs_info_msg_0_}%F{214}$%f '
  RPROMPT=''
else
  # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

if [[ "$TERM_PROGRAM" != "vscode" ]]; then
  # macOS-specific lazy loading
  if [[ -n "$IS_MACOS" ]]; then
    # OPTIMIZATION: Lazy-load terraform autocomplete (saves ~28ms)
    terraform() {
      unfunction terraform
      autoload -U +X bashcompinit && bashcompinit
      complete -o nospace -C /opt/homebrew/bin/terraform terraform
      terraform "$@"
    }

    # OPTIMIZATION: Lazy-load heroku autocomplete (saves ~430ms)
    heroku() {
      unfunction heroku
      HEROKU_AC_ZSH_SETUP_PATH="$HOME/Library/Caches/heroku/autocomplete/zsh_setup"
      test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH
      heroku "$@"
    }

    ASCII=("totoro" "beach" "stars")
    cat $HOME/.misc/ascii_$ASCII[$RANDOM%$#ASCII+1]
  fi
fi
