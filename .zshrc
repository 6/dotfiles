# Disable Powerlevel10k for VSCode/Cursor/Claude Code terminals (cleaner prompt)
if [[ "$TERM_PROGRAM" == "vscode" ]] || [[ -n "$CCODE" ]]; then
  ZSH_THEME=""
else
  ZSH_THEME="powerlevel10k/powerlevel10k"

  # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
  # Initialization code that may require console input (password prompts, [y/n]
  # confirmations, etc.) must go above this block; everything else may go below.
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# Load Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# OPTIMIZATION: Skip Oh My Zsh automatic updates check (saves ~240ms)
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

# OPTIMIZATION: Skip completion security check
ZSH_DISABLE_COMPFIX=true

source $ZSH/oh-my-zsh.sh

plugins=(bundler git zsh-autosuggestions)

# ── Homebrew (macOS + Linux) ──
if [[ "$OSTYPE" == darwin* ]]; then
  export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export PATH="$PATH:/opt/homebrew/bin"
  # OPTIMIZATION: Cache brew shellenv output (saves ~50ms)
  if command -v brew &>/dev/null; then
    if [[ -f ~/.brew_shellenv_cache ]]; then
      source ~/.brew_shellenv_cache
    else
      brew shellenv > ~/.brew_shellenv_cache
      source ~/.brew_shellenv_cache
    fi
  fi
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
  # Always use fresh brew shellenv on Linux to ensure PATH priority
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ── Common exports ──
export UPDATE_ZSH_DAYS=30
export EDITOR='vim'
export GOPATH="$HOME/go"

# For ruby/fastlane:
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# ── Common PATH ──
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/flutter/bin:$PATH"
export PATH="$PATH:$HOME/.foundry/bin"
export PATH="$PATH:/nix/var/nix/profiles/default/bin"
export PATH="$PATH:$HOME/.cache/lm-studio/bin"

# Ollama
export OLLAMA_HOST=0.0.0.0
export OLLAMA_ORIGINS=*

# ── Autosuggest settings ──
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=true

# ── Common functions ──

function main() {
  if git show-ref --quiet refs/heads/main; then
    git checkout main
  else
    git checkout master
  fi
}

function spec() {
  test -e package.json && grep -q '"test":' package.json && yarn test $1
  test -e .rspec && bundle exec rspec $1
}

function mirror() {
  local url=$1
  local level=${2:-3}

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

function port() {
  lsof -i tcp:"$1"
}

function mainpd() {
  local prev_branch=$(git rev-parse --abbrev-ref HEAD)
  mainp

  if git branch --merged | grep -q "^\s*${prev_branch}$"; then
    git branch -d "$prev_branch"
  elif ! git branch -r | grep -q "origin/${prev_branch}$"; then
    echo "Remote branch deleted (PR merged), force-deleting local branch..."
    git branch -D "$prev_branch"
  else
    echo "Warning: Branch '${prev_branch}' is not merged and still exists on remote"
    echo "If you're sure the PR is merged, run: git branch -D ${prev_branch}"
  fi
}

function linkmodels() {
  find ~/oss/llama.cpp/models/ -type l -exec rm -f {} \; 2>/dev/null
  find ~/oss/llama.cpp/models/ -type d -empty -delete 2>/dev/null
  mkdir -p ~/oss/llama.cpp/models

  while IFS= read -r -d '' model_file; do
    rel_path="${model_file#$HOME/models/}"
    target_path=~/oss/llama.cpp/models/"$rel_path"
    target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"
    if [[ ! -e "$target_path" ]]; then
      ln -vs "$model_file" "$target_path"
    fi
  done < <(find ~/models -type f -name "*.gguf" -print0)
}

# ── Common aliases ──
alias gti='git'
alias igt='git'
alias gt='git'
alias mainp='main && git pull'
alias cc='claude --model opus'
alias ccs='claude --model sonnet'
alias a="code ."
alias most="du -hs * | sort -rh | head -10"

# ── Tool initialization ──
eval "$(direnv hook zsh)"
eval "$(mise activate zsh)"

# ── Load machine-specific config ──
if [ -f $HOME/.zsh_custom ]; then
  source "$HOME/.zsh_custom"
fi

# ── Powerlevel10k config ──
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ── Google Cloud SDK ──
if [ -f ~/google-cloud-sdk/completion.zsh.inc ]; then
  source ~/google-cloud-sdk/completion.zsh.inc
  source ~/google-cloud-sdk/path.zsh.inc
fi

# ── Terminal-specific prompts (VSCode/Cursor/Claude Code) ──
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
elif [[ -n "$CCODE" ]]; then
  autoload -Uz vcs_info
  precmd_vcs_info() { vcs_info }
  precmd_functions+=( precmd_vcs_info )
  setopt prompt_subst
  zstyle ':vcs_info:git:*' formats '%F{green}%b%f '
  zstyle ':vcs_info:*' enable git
  PROMPT='%F{208}%~%f ${vcs_info_msg_0_}%F{214}$%f '
  RPROMPT=''
fi

# ── macOS-specific configuration ──
if [[ "$OSTYPE" == darwin* ]]; then
  # macOS PATH additions
  export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/tools:$PATH"
  export PATH="$PATH:/Applications/Android Studio.app/Contents/MacOS"
  export PATH="/Applications/Genymotion.app/Contents/MacOS/tools/:$PATH"
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  export PATH="$HOMEBREW_PREFIX/opt/openssl@1.1/bin:$PATH"
  export PATH="$PATH:/usr/local/share/dotnet/"

  # Android SDK
  export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export ANDROID_AVD_HOME="$HOME/.android/avd"
  export JAVA_HOME="/Applications/Android\ Studio.app/Contents/jbr/Contents/Home"
  export PATH=$PATH:$ANDROID_HOME/emulator
  export PATH=$PATH:$ANDROID_HOME/tools
  export PATH=$PATH:$ANDROID_HOME/tools/bin
  export PATH=$PATH:$ANDROID_HOME/platform-tools

  # PNPM
  export PNPM_HOME="$HOME/Library/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac

  # macOS functions
  function screenshot() {
    local seconds=0
    if [[ $1 ]]; then seconds=$1; fi
    screencapture -x -T $seconds -t png ~/Desktop/screenshot-$(date +"%Y-%m-%d-%H-%M-%S").png
  }

  function fixpg() {
    rm -f /usr/local/var/postgres/postmaster.pid
    brew services restart postgresql
    echo 'If still not working, try running `pg_ctl -D /usr/local/var/postgres start` to see full output.'
    echo 'or on M1: `pg_ctl -D /opt/homebrew/var/postgres start`'
  }

  function fixcamera {
    sudo killall VDCAssistant
  }

  function fixlol() {
    cp ~/.misc/PersistedSettings.json "/Applications/League of Legends.app/Contents/LoL/Config/PersistedSettings.json"
  }

  # macOS aliases
  alias fixdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
  alias fixsim='sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService'
  alias mp3="youtube-dl --add-metadata -x --extract-audio --audio-format mp3"
  alias ap='osascript ~/.misc/airpods.applescript'

  # VSCode shell integration (macOS-specific path)
  [[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

  # Lazy-load terraform autocomplete (macOS homebrew path)
  if [[ "$TERM_PROGRAM" != "vscode" ]] && [[ -z "$CCODE" ]]; then
    terraform() {
      unfunction terraform
      autoload -U +X bashcompinit && bashcompinit
      complete -o nospace -C /opt/homebrew/bin/terraform terraform
      terraform "$@"
    }

    heroku() {
      unfunction heroku
      HEROKU_AC_ZSH_SETUP_PATH="$HOME/Library/Caches/heroku/autocomplete/zsh_setup"
      test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH
      heroku "$@"
    }
  fi
fi

# ── Linux-specific configuration ──
if [[ "$OSTYPE" == linux* ]]; then
  # CUDA paths
  export PATH=/usr/local/cuda/bin:$PATH
  export CPATH=/usr/local/cuda/include:$CPATH
  export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
fi

# ── ASCII art on terminal open (must be last) ──
if [[ "$TERM_PROGRAM" != "vscode" ]] && [[ -z "$CCODE" ]] && [[ -d $HOME/.misc ]]; then
  ASCII=("totoro" "beach" "stars")
  cat $HOME/.misc/ascii_$ASCII[$RANDOM%$#ASCII+1] 2>/dev/null
fi
