#!/bin/zsh

# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Prompt for confirmation. Usage: confirm "message" [N]
# Default is Y unless second argument is N.
confirm() {
  local prompt=$1 default=${2:-Y}
  echo
  if [[ $default == Y ]]; then
    echo -n "${RED}${prompt} ${NC}[Y/n] "
  else
    echo -n "${RED}${prompt} ${NC}[y/N] "
  fi
  read REPLY
  if [[ $default == Y ]]; then
    [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]
  else
    [[ $REPLY =~ ^[Yy]$ ]]
  fi
}

#########
# Start #
#########

clear
echo " _           _        _ _       _     "
echo "(_)         | |      | | |     | |    "
echo " _ _ __  ___| |_ __ _| | |  ___| |__  "
echo "| | |_ \/ __| __/ _  | | | / __| |_ \ "
echo "| | | | \__ \ || (_| | | |_\__ \ | | |"
echo "|_|_| |_|___/\__\__,_|_|_(_)___/_| |_|"
echo
echo
echo Enter root password

# Ask for the administrator password upfront.
sudo -v

# Keep Sudo until script is finished
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# Update macOS
if confirm "Install macOS updates?"; then
  echo
  echo "${GREEN}Looking for updates.."
  echo
  sudo softwareupdate -i -a
fi

# Set host name
if confirm "Change host name?"; then
  echo "${RED}Please enter your host name:${NC}"
  read hostname

  sudo scutil --set HostName "$hostname"
  sudo scutil --set LocalHostName "$hostname"
  sudo scutil --set ComputerName "$hostname"
  dscacheutil -flushcache
fi

# Install Rosetta
if confirm "Install Rosetta?"; then
  if ! /usr/bin/pgrep -q oahd; then
    sudo softwareupdate --install-rosetta --agree-to-license
  else
    echo "${GREEN}Rosetta is already installed."
  fi
fi

# Install Homebrew and packages
if confirm "Install Homebrew and packages?"; then
  # Install Homebrew if not already present
  if ! command -v brew &>/dev/null; then
    echo
    echo "${GREEN}Installing Homebrew"
    echo
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo "${GREEN}Homebrew is already installed."
  fi

  # Append Homebrew initialization to .zprofile (idempotent)
  grep -qF 'eval "$(/opt/homebrew/bin/brew shellenv)"' "${HOME}/.zprofile" 2>/dev/null || \
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"${HOME}/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # Add $HOME/bin to PATH (idempotent)
  grep -qF 'export PATH="$HOME/bin:$PATH"' "${HOME}/.zprofile" 2>/dev/null || \
    echo 'export PATH="$HOME/bin:$PATH"' >>"${HOME}/.zprofile"
  export PATH="$HOME/bin:$PATH"

  # Check installation and update
  echo
  echo "${GREEN}Checking installation.."
  echo
  brew update && brew doctor
  export HOMEBREW_NO_INSTALL_CLEANUP=1

  # Install packages
  echo
  echo "${GREEN}Installing packages..."
  brew bundle --file=./Brewfile

  # Cleanup
  echo
  echo "${GREEN}Cleaning up..."
  brew update && brew upgrade && brew cleanup && brew doctor
fi

# Install chezmoi-split
if confirm "Install chezmoi-split?"; then
  echo "${GREEN}Installing chezmoi-split..."
  mkdir -p "$HOME/bin"
  ARCH=$(uname -m)
  case "$ARCH" in
    arm64) ARCH="arm64" ;;
    x86_64) ARCH="amd64" ;;
  esac
  CHEZMOI_SPLIT_VERSION=$(curl -fsSL https://api.github.com/repos/thirteen37/chezmoi-split/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')
  curl -fsSL "https://github.com/thirteen37/chezmoi-split/releases/download/v${CHEZMOI_SPLIT_VERSION}/chezmoi-split_${CHEZMOI_SPLIT_VERSION}_darwin_${ARCH}.tar.gz" | tar xz -C "$HOME/bin" chezmoi-split
fi

# Enable Touch ID for sudo
if confirm "Enable Touch ID for sudo?"; then
  if ! grep -qF 'pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
    if [[ ! -f /opt/homebrew/lib/pam/pam_reattach.so ]]; then
      echo "${RED}Warning: pam_reattach.so not found. Install pam-reattach via Homebrew first.${NC}"
    else
      echo "${GREEN}Configuring Touch ID for sudo..."
      sudo tee /etc/pam.d/sudo_local <<'EOF' >/dev/null
auth       optional       /opt/homebrew/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so
EOF
    fi
  else
    echo "${GREEN}Touch ID for sudo is already configured."
  fi
fi

# Auto-update
if confirm "Auto-update brew?"; then
  mkdir -p ~/Library/LaunchAgents
  brew tap homebrew/autoupdate
  brew autoupdate start $HOMEBREW_UPDATE_FREQUENCY --upgrade --cleanup --immediate --sudo
fi

# Settings
if confirm "Configure default system settings?"; then
  echo "${GREEN}Configuring default settings..."
  while IFS= read -r setting; do
    eval $setting
  done < ./settings
fi

# Dock settings
if confirm "Apply Dock settings?" N; then
  typeset -a dock_skipped=()
  while read -r op arg; do
    [[ -z "$op" || "$op" == \#* ]] && continue
    case $op in
      ">")
        IFS="|" read -r replace_app add_app <<<"$arg"
        if [[ ! -e "$add_app" ]]; then
          dock_skipped+=("$add_app")
          continue
        fi
        dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null
        ;;
      "+")
        if [[ ! -e "$arg" ]]; then
          dock_skipped+=("$arg")
          continue
        fi
        dockutil --add "$arg" &>/dev/null
        ;;
      "-")
        dockutil --remove "$arg" &>/dev/null
        ;;
    esac
  done < ./dock
  # Report skipped apps
  if (( ${#dock_skipped[@]} )); then
    echo "${RED}Skipped (not found):${NC}"
    for app in "${dock_skipped[@]}"; do
      echo "  $app"
    done
  fi
fi

clear
echo "${GREEN}______ _____ _   _  _____ "
echo "${GREEN}|  _  \  _  | \ | ||  ___|"
echo "${GREEN}| | | | | | |  \| || |__  "
echo "${GREEN}| | | | | | | .   ||  __| "
echo "${GREEN}| |/ /\ \_/ / |\  || |___ "
echo "${GREEN}|___/  \___/\_| \_/\____/ "

echo
echo
printf "${RED}"
read -s -k $'?Press ANY KEY to REBOOT\n'
sudo reboot
exit
