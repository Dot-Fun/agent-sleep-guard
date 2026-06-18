# Agent Sleep Guard

Disable macOS system sleep while local coding agents are running, while leaving display sleep unchanged.

The watcher runs every 10 minutes through `launchd`. If it finds an `agy`, `codex`, or `claude` process, it runs:

```bash
pmset -a disablesleep 1
```

If none of those processes are running, it runs:

```bash
pmset -a disablesleep 0
```

## Install

```bash
chmod +x agent-sleep-guard.zsh
sudo ./agent-sleep-guard.zsh install
```

The installer writes a root LaunchDaemon to:

```text
/Library/LaunchDaemons/com.local.agent-sleep-guard.plist
```

The daemon starts immediately, runs every 10 minutes, and starts again after reboot.

## Status

```bash
./agent-sleep-guard.zsh status
```

Example:

```text
agent_process_running=yes
launchdaemon_loaded=yes
SleepDisabled=1
```

## Uninstall

```bash
sudo ./agent-sleep-guard.zsh uninstall
```

Uninstalling removes the LaunchDaemon and resets `disablesleep` to `0`.

## Notes

- This is for macOS.
- The script must be installed with `sudo` because `pmset disablesleep` and system LaunchDaemons require root.
- The script detects agent processes by process name and command line.
- The script intentionally does not change `displaysleep`.
- If a stale `agy`, `codex`, or `claude` process is still running, sleep remains disabled until that process exits or is killed.
