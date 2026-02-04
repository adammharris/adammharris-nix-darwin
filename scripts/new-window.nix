{ pkgs }:

let
  new-window-script = pkgs.writeShellScriptBin "new-window" ''
    if [ -z "$1" ]; then
      echo "Usage: $0 \"Application Name\"" >&2
      exit 1
    fi
    APP_NAME="''${1%.app}"
    osascript - "$APP_NAME" <<'EOF'
    on run {appName}
        tell application appName
            if it is running then
                activate
                delay 0.1
                tell application "System Events" to keystroke "n" using {command down}
            else
                activate
            end if
        end tell
    end run
    EOF
  '';
in
{
  inherit new-window-script;
}
