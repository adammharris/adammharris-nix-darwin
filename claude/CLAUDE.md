# Driving a GUI app on this machine

Applies to any desktop app on this Mac — a dev build, a shipping app, System
Settings. It replaces the older per-project recipes built on `/tmp/macshot.sh`,
`/tmp/macat.sh`, `/tmp/click.swift`, `/tmp/press.swift`, `/tmp/rclick.swift`
and region `screencapture`. Those still run; prefer this.

## Two tools, two jobs

**Computer-use MCP (`mcp__computer-use__*`) is the eyes and hands.** Call
`request_access` for the apps you need, then `screenshot`, `left_click`,
`type`, `scroll`. Its screenshots exclude every app you were not granted, at
the compositor, so they cannot capture the wrong window — unlike
`screencapture -R x,y,w,h`, which grabs whatever is on top and will happily
hand you the user's browser instead of the app you are debugging.

**The accessibility tree is the ruler.** Read exact frames with `osascript` →
`System Events`, and never measure a layout by eye off a screenshot. A
screenshot tells you something looks wrong; the AX tree tells you by how much,
and is the only evidence worth writing down.

```bash
osascript -e 'tell application "System Events" to tell process "<App>" \
  to get {position, size} of window 1'
```

Walk into it with `UI element 1 of UI element 1 of window 1`, and recurse with
`UI elements of`. Compare a child's height to the window's rather than
trusting either alone.

The MCP does not replace this: it returns no element frames, cannot move or
resize a window (`set size of window 1` is the only way, and it will go below
the app's declared minimum), and cannot be called from inside a Bash loop — so
a sweep of a dozen sizes is one Bash call here and a dozen round-trips there.

Use the Bash tool for shell work. Never type shell into a terminal window
through computer use — terminals and IDEs are granted click-only for exactly
this reason.

## Keystrokes: the MCP's `key`, never osascript's

The computer-use `key` and `type` tools are gated on the granted app being
frontmost, so they cannot land in an unrelated window. Use them.

`System Events` `keystroke` / `key code` has no such gate — it goes to
**whatever is frontmost**, which may be the user's own window. Never use it.

`AXPress` is the third option, for acting without bringing the app forward, or
from inside a Bash loop:

```bash
osascript -e 'tell application "System Events" to tell process "<App>" \
  to perform action "AXPress" of <the button>'
```
