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

**Cua Driver (`mcp__cua-driver__*`) is the hands when the app must stay in the
background.** Computer use acts on the frontmost app, so it takes focus from
the user. When the user is working on this Mac at the same time, use Cua
Driver; see "Background driving" below.

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

## Background driving: Cua Driver

Cua Driver (`cua-driver` MCP, or `cua-driver call <tool> '<json>'` from Bash)
types and takes screenshots without taking focus. Tested on 2026-10-23 with
TextEdit and Leaf: this works with the window behind other windows, scrolled
out of an OmniWM column, on another OmniWM workspace, or on the DeskPad
display. OmniWM workspaces are not macOS Spaces: hidden windows stay on the
current Space, parked at the screen edge.

**Put test windows on the ❤️ workspace.** ❤️ is on the DeskPad display (a
virtual display; its mirror window floats on workspace 9). Move a test window
there by id: `omniwmctl window move-to-workspace <opaque-id> ❤️`. There it
counts as visible to macOS, the user cannot scroll it away by accident, and
the user's focus is not touched. Start DeskPad with Cua Driver's `launch_app`
if it is not running, so it does not take focus.

**Background clicks do not land in winit/Blitz apps (Diaryx, Leaf)** with Cua
Driver 0.36.0. The `click` tool presses the empty AXGroup that covers the
window and reports success. Raw mouse events arrive at screen coordinates, not
window coordinates, so they are off by the window's position. Keys and AX
actions work. So act through AX by `element_token`. A click that must land
needs `delivery_mode:"foreground"`, and the user's OK each time.

- Native text views (TextEdit) take AX insertion: pass an `element_token`.
  Apps whose AX tree has no text element (Leaf, other winit/Dioxus apps) get
  key events, which return `effect:"unverifiable"`, so read the text back.
- Minimized: raw keys are refused (`minimized_or_hidden_window`). AX actions
  still work, but Leaf's screenshot goes stale. Un-minimize the window
  (`AXMinimized` = false) instead.
- Background Cmd+W did not close TextEdit; press the close button through AX.
- `launch_app` keeps focus where it was, but opens the registered bundle. Run
  a worktree build of Leaf by its path; it then takes focus when it opens.

## Windows: OmniWM and `omniwmctl`

This Mac runs the OmniWM tiling window manager. Use `omniwmctl` to find,
focus, move and arrange windows, and to switch workspaces. `omniwmctl help`
lists every command.

- `omniwmctl query windows --format table` lists each window's opaque id,
  app, title, workspace and mode (tiling or floating). `query focused-window`,
  `workspaces` and `displays` work the same way; add `--format json` to parse.
- `omniwmctl window focus|navigate|move-to-workspace <opaque-id>` acts on one
  window by its id.
- `omniwmctl command ...` runs the same layout actions as the key bindings
  (focus, move, column spans, workspaces).

OmniWM sizes tiled windows itself, so it can undo a `set size of window 1`
from `System Events`. In a size sweep, read the frame back after each change.
If the size does not hold, make the window float with an `omniwmctl rule`
first.

# Writing

Use ASD-STE100 (Simplified Technical English) as a guide for your responses.
Write short sentences, use active voice, and keep terminology consistent.
Relax the vocabulary rules when they make explanations awkward. Preserve
technical precision and uncertainty.

# iOS simulators

Run simulators through `simslim`, which turns off the background daemons a
simulator doesn't need, so they use less memory. Boot with
`simslim boot <udid>` instead of `xcrun simctl boot`, or run `simslim watch` to
slim every simulator as it boots. `simslim list` shows each simulator's slim
status; `simslim help` has the rest.

# My shell

My interactive shell is Nushell. When you ask me to run a command myself,
write it in Nushell syntax, or say that it needs bash (e.g. `bash -c '...'`).
