#!/bin/zsh
set -euo pipefail

LABEL="com.local.agent-sleep-guard"
SCRIPT_PATH="${0:A}"
PLIST_PATH="/Library/LaunchDaemons/${LABEL}.plist"
LOG_PATH="/var/log/${LABEL}.log"
ERROR_LOG_PATH="/var/log/${LABEL}.err.log"

usage() {
  /bin/cat <<'USAGE'
Usage:
  sudo ./agent-sleep-guard.zsh install
  ./agent-sleep-guard.zsh status
  sudo ./agent-sleep-guard.zsh uninstall

Behavior:
  - Disables system sleep when agy, codex, or claude is running.
  - Re-enables system sleep when none of those processes are running.
  - Leaves display sleep alone.
USAGE
}

require_root() {
  if [[ "$(/usr/bin/id -u)" != "0" ]]; then
    echo "This command must be run with sudo." >&2
    exit 1
  fi
}

agent_is_running() {
  /bin/ps -axo pid=,comm=,args= | /usr/bin/awk -v self="$$" '
    $1 == self { next }
    {
      comm = $2
      line = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]*/, "", line)

      if (comm ~ /(^|\/)(agy|codex|claude)$/ || line ~ /(^|[[:space:]\/])(agy|codex|claude)([[:space:]]|$)/) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  '
}

sleep_disabled_value() {
  /usr/bin/pmset -g live | /usr/bin/awk '/SleepDisabled/{print $2; found=1} END{if(!found) print 0}'
}

apply_sleep_policy() {
  local desired current

  if agent_is_running; then
    desired=1
  else
    desired=0
  fi

  current="$(sleep_disabled_value)"

  if [[ "$current" != "$desired" ]]; then
    /usr/bin/pmset -a disablesleep "$desired"
    echo "$(/bin/date -Is) set disablesleep=${desired}"
  fi
}

install_daemon() {
  require_root

  if [[ ! -x "$SCRIPT_PATH" ]]; then
    /bin/chmod 755 "$SCRIPT_PATH"
  fi

  /bin/cat >"$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
      <string>${SCRIPT_PATH}</string>
      <string>watch</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>StandardOutPath</key>
    <string>${LOG_PATH}</string>
    <key>StandardErrorPath</key>
    <string>${ERROR_LOG_PATH}</string>
  </dict>
</plist>
PLIST

  /usr/sbin/chown root:wheel "$PLIST_PATH"
  /bin/chmod 644 "$PLIST_PATH"

  /bin/launchctl bootout system "$PLIST_PATH" >/dev/null 2>&1 || true
  /bin/launchctl bootstrap system "$PLIST_PATH"
  /bin/launchctl kickstart -k "system/${LABEL}"

  echo "Installed ${LABEL}."
  status
}

uninstall_daemon() {
  require_root

  /bin/launchctl bootout system "$PLIST_PATH" >/dev/null 2>&1 || true
  /bin/rm -f "$PLIST_PATH"
  /usr/bin/pmset -a disablesleep 0

  echo "Uninstalled ${LABEL} and set disablesleep=0."
}

status() {
  local running="no"
  local loaded="no"

  if agent_is_running; then
    running="yes"
  fi

  if /bin/launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    loaded="yes"
  fi

  echo "agent_process_running=${running}"
  echo "launchdaemon_loaded=${loaded}"
  echo "SleepDisabled=$(sleep_disabled_value)"
}

case "${1:-install}" in
  install)
    install_daemon
    ;;
  uninstall)
    uninstall_daemon
    ;;
  status)
    status
    ;;
  watch)
    require_root
    apply_sleep_policy
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
