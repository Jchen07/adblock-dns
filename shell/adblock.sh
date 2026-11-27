# Shortcuts for adblock-dns (bash or zsh, on macOS or Linux).
# Load from ~/.zshrc or ~/.bashrc:  source /path/to/adblock-dns/shell/adblock.sh
# Windows: use shell/adblock.ps1 instead.

# Repo folder, detected from this file's location
if [ -n "$ZSH_VERSION" ]; then
  eval 'ADBLOCK_DIR=${${(%):-%x}:A:h:h}'
else
  ADBLOCK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fi

# This computer's address on the home network
adblock-ip() {
  local ip=""
  case "$(uname -s)" in
    Darwin)
      local dev
      dev=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
      ip=$(ipconfig getifaddr "${dev:-en0}" 2>/dev/null)
      ;;
    Linux)
      ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
      [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
      ;;
  esac
  [ -n "$ip" ] || { echo "Could not find the network address. Is Wi-Fi or Ethernet connected?" >&2; return 1; }
  echo "$ip"
}

_adblock_docker() {
  docker info >/dev/null 2>&1 && return 0
  if [ "$(uname -s)" = Darwin ]; then
    echo "Opening Docker..."
    open -a Docker || return 1
  else
    echo "Starting Docker (may ask for your password)..."
    sudo systemctl start docker || return 1
  fi
  local i=0
  until docker info >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -gt 60 ] && { echo "Docker did not start" >&2; return 1; }
    sleep 2
  done
}

adblock-on() {
  local ip
  ip=$(adblock-ip) || return 1
  _adblock_docker || return 1
  # Keep .env in sync with the current address, so a new IP just works
  echo "LAN_IP=$ip" > "$ADBLOCK_DIR/.env"
  docker compose --project-directory "$ADBLOCK_DIR" up -d || return 1
  echo "Ad blocker ON. DNS server: $ip"
  echo "Phone: set the Wi-Fi DNS to $ip (README step 4)"
}

adblock-off() {
  echo "Remember: set the phone DNS back to automatic."
  docker compose --project-directory "$ADBLOCK_DIR" down && echo "Ad blocker OFF"
}

adblock-status() {
  docker ps --filter name=adguardhome --format '{{.Names}}: {{.Status}}'
}

# ---------------------------------------------------------------------------
# adblock-setup: first-time setup with the recommended settings (README step 3).
# Asks only for a username and password. Never changes an existing setup;
# `adblock-setup --reapply` logs in and re-applies only the recommended settings.
# The password is sent only to AdGuard Home on this computer, never saved.

: "${ADBLOCK_URL:=http://127.0.0.1:3000}"   # admin panel (change only for testing)
ADBLOCK_UPSTREAM=https://dns.quad9.net/dns-query
ADBLOCK_LIST_NAME="HaGeZi's Pro Blocklist"
ADBLOCK_LIST_URL=https://adguardteam.github.io/HostlistsRegistry/assets/filter_48.txt

# Text as a JSON string
_adblock_json() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

# _adblock_api METHOD PATH [curl args]: prints the HTTP code (000 = no answer),
# the body goes to $_ab_tmp/body. JSON bodies come from stdin (--data-binary @-),
# so the password never shows up in the process list.
_adblock_api() {
  local m=$1 p=$2
  shift 2
  curl -s -o "$_ab_tmp/body" -w '%{http_code}' -X "$m" \
    -b "$_ab_tmp/jar" -c "$_ab_tmp/jar" -H 'Content-Type: application/json' \
    "$@" "$ADBLOCK_URL/control$p"
}

# The raw items of "user_rules":[...] from a filtering/status body
_adblock_user_rules() {
  awk 'BEGIN { RS = "\001" } {
    i = index($0, "\"user_rules\":["); if (!i) exit
    s = substr($0, i + 14); out = ""; q = 0; e = 0
    for (j = 1; j <= length(s); j++) {
      c = substr(s, j, 1)
      if (q) { if (e) e = 0; else if (c == "\\") e = 1; else if (c == "\"") q = 0 }
      else if (c == "\"") q = 1
      else if (c == "]") { printf "%s", out; exit }
      out = out c
    }
  }' "$1"
}

_adblock_fail() { echo "$*" >&2; exit 1; }

adblock-setup() (
  reapply=0
  case "${1:-}" in
    "") ;;
    --reapply) reapply=1 ;;
    *) echo "Usage: adblock-setup [--reapply]" >&2; exit 2 ;;
  esac
  _ab_tmp=$(mktemp -d) || exit 1
  trap 'rm -rf "$_ab_tmp"' EXIT
  command -v curl >/dev/null || _adblock_fail "curl is missing. Install it and try again."

  code=$(_adblock_api GET /install/get_addresses)
  [ "$code" = 000 ] && _adblock_fail "The blocker is not running. Run adblock-on first."
  if [ "$code" = 200 ]; then
    fresh=1
  elif [ "$reapply" = 1 ]; then
    fresh=0
  else
    echo "Already set up: nothing changed."
    echo "To re-apply the recommended settings (asks for your login): adblock-setup --reapply"
    exit 0
  fi

  # Credentials, typed by the user only
  if [ "$fresh" = 1 ]; then
    echo "Create the login for the blocker's panel ($ADBLOCK_URL)."
    printf 'Username: '
  else
    printf 'Panel username: '
  fi
  IFS= read -r user || exit 1
  [ -n "$user" ] || _adblock_fail "The username can't be empty."
  while :; do
    printf 'Password: '
    IFS= read -rs pass || exit 1
    echo
    case $pass in *[[:cntrl:]]*) echo "Use letters, numbers and symbols only."; continue ;; esac
    [ "$fresh" = 1 ] || break
    if [ "${#pass}" -lt 8 ]; then echo "At least 8 characters, try again."; continue; fi
    if [ "${#pass}" -gt 72 ]; then echo "At most 72 characters, try again."; continue; fi
    printf 'Same password again: '
    IFS= read -rs pass2 || exit 1
    echo
    [ "$pass" = "$pass2" ] && break
    echo "They don't match, try again."
  done
  pass2=

  if [ "$fresh" = 1 ]; then
    echo "Setting up..."
    code=$(printf '%s' "{\"web\":{\"ip\":\"0.0.0.0\",\"port\":3000},\"dns\":{\"ip\":\"0.0.0.0\",\"port\":53},\"username\":$(_adblock_json "$user"),\"password\":$(_adblock_json "$pass")}" |
      _adblock_api POST /install/configure --data-binary @-)
    case $code in
      200) ;;
      422) _adblock_fail "AdGuard Home says the password is too weak: $(cat "$_ab_tmp/body"). Run adblock-setup again with a stronger one." ;;
      400) _adblock_fail "Could not use port 53 or 3000 ($(cat "$_ab_tmp/body")). Close the program using them, then run adblock-off, adblock-on and adblock-setup." ;;
      *) _adblock_fail "Setup failed (HTTP $code): $(cat "$_ab_tmp/body")" ;;
    esac
    # The panel restarts after the first setup
    i=0
    until [ "$(_adblock_api GET /status)" != 000 ]; do
      i=$((i + 1))
      [ "$i" -gt 30 ] && _adblock_fail "The panel did not come back. Check with adblock-status."
      sleep 1
    done
  fi

  code=$(printf '%s' "{\"name\":$(_adblock_json "$user"),\"password\":$(_adblock_json "$pass")}" |
    _adblock_api POST /login --data-binary @-)
  pass=
  case $code in
    200) ;;
    400|401|403) _adblock_fail "Wrong username or password." ;;
    429) _adblock_fail "Too many login attempts. Wait a few minutes and try again." ;;
    *) _adblock_fail "Login failed (HTTP $code)." ;;
  esac

  # Upstream DNS
  code=$(printf '%s' "{\"upstream_dns\":[\"$ADBLOCK_UPSTREAM\"]}" | _adblock_api POST /dns_config --data-binary @-)
  [ "$code" = 200 ] || _adblock_fail "Could not set the upstream DNS (HTTP $code): $(cat "$_ab_tmp/body")"
  echo "  ✓ Upstream DNS: Quad9"

  # Blocklist (only if it isn't there yet)
  code=$(_adblock_api GET /filtering/status)
  [ "$code" = 200 ] || _adblock_fail "Could not read the blocklists (HTTP $code)."
  cp "$_ab_tmp/body" "$_ab_tmp/filtering"
  if grep -qF "\"$ADBLOCK_LIST_URL\"" "$_ab_tmp/filtering"; then
    echo "  ✓ $ADBLOCK_LIST_NAME (already there)"
  else
    code=$(printf '%s' "{\"name\":$(_adblock_json "$ADBLOCK_LIST_NAME"),\"url\":\"$ADBLOCK_LIST_URL\",\"whitelist\":false}" |
      _adblock_api POST /filtering/add_url --data-binary @-)
    [ "$code" = 200 ] || _adblock_fail "Could not download $ADBLOCK_LIST_NAME. Check the internet connection, then run: adblock-setup --reapply"
    echo "  ✓ $ADBLOCK_LIST_NAME"
  fi

  # Extra rules from the repo, added to the user's own rules (no duplicates)
  existing=$(_adblock_user_rules "$_ab_tmp/filtering")
  missing="" added=0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in ""|"#"*|"!"*) continue ;; esac
    item=$(_adblock_json "$line")
    case ",$existing,$missing," in *",$item,"*) continue ;; esac
    missing="$missing${missing:+,}$item"
    added=$((added + 1))
  done < "$ADBLOCK_DIR/rules/extra-rules.txt"
  if [ "$added" -gt 0 ]; then
    code=$(printf '%s' "{\"rules\":[$existing${existing:+${missing:+,}}$missing]}" |
      _adblock_api POST /filtering/set_rules --data-binary @-)
    [ "$code" = 200 ] || _adblock_fail "Could not add the extra rules (HTTP $code): $(cat "$_ab_tmp/body")"
  fi
  echo "  ✓ Extra rules: $added added"

  # Query log: on, 24 hours
  code=$(_adblock_api GET /querylog/config)
  [ "$code" = 200 ] || _adblock_fail "Could not read the query log settings (HTTP $code)."
  cp "$_ab_tmp/body" "$_ab_tmp/querylog"
  sed -e 's/"interval":[0-9.eE+]*/"interval":86400000/' -e 's/"enabled":false/"enabled":true/' "$_ab_tmp/querylog" |
    _adblock_api PUT /querylog/config/update --data-binary @- >"$_ab_tmp/code"
  [ "$(cat "$_ab_tmp/code")" = 200 ] || _adblock_fail "Could not set the query log (HTTP $(cat "$_ab_tmp/code"))."
  echo "  ✓ Query log: 24 hours"

  ip=$(adblock-ip 2>/dev/null)
  echo "Done. Panel: $ADBLOCK_URL (user: $user)"
  [ -n "$ip" ] && echo "Phone: set the Wi-Fi DNS to $ip (README step 4)"
)
