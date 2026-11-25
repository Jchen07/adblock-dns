# Shortcuts for adblock-dns (zsh, macOS).
# Load from your ~/.zshrc:  source /path/to/adblock-dns/shell/aliases.zsh

# Repo folder, detected from this file's location
ADBLOCK_DIR=${${(%):-%x}:A:h:h}

adblock-on() {
  if ! docker info >/dev/null 2>&1; then
    echo "Opening Docker..."
    open -a Docker || return 1
    local i=0
    until docker info >/dev/null 2>&1; do
      (( ++i > 60 )) && { echo "Docker did not start"; return 1; }
      sleep 2
    done
  fi
  docker compose --project-directory "$ADBLOCK_DIR" up -d || return 1
  echo "Ad blocker ON. Mac IP: $(ipconfig getifaddr en0)"
  echo "iPhone: Wi-Fi > Configure DNS > Manual"
}

adblock-off() {
  echo "Remember: set the iPhone DNS to Automatic."
  docker compose --project-directory "$ADBLOCK_DIR" down && echo "Ad blocker OFF"
}

alias adblock-status='docker ps --filter name=adguardhome --format "{{.Names}}: {{.Status}}"'
