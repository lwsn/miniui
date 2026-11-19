# miniui

A personal WoW UI in one addon. The client is `_forever_` (product wowf), a
12.0-era client with secret values. It runs the Mainline UI and also loads
Blizzard_GamepadActionBars ("Camelot").

## Principles

- **Zero in-game setup.** Hardcode layout, positions and behaviour in Lua. Don't
  add config panels, slash-command settings or SavedVariables options unless
  asked.
- **Typography.** IBM Plex Sans Condensed, Regular and SemiBold only
  (`ns.media.font.regular` / `.semibold`). Create text with `ns.CreateText`.
  Backgrounds are always dark, so text has no shadow or outline. The exception
  is text drawn on icons or the map (aura timers and counts, action button
  text, minimap text, chat tabs and the chat's tab-row buttons, which sit on
  the game world), which uses `'OUTLINE'`, never a drop shadow. Don't put
  text on bright fills.
- **Muted colours.** Bars use a dark fill. The background is the fill times
  `ns.colors.BG_SHADE`, and text is the fill mixed toward white by
  `ns.colors.TEXT_TINT`. Tone down Blizzard's bright defaults; see the
  overrides in `unitframes/colors.lua`.

## Pixel-perfect layout

- Work in physical pixels. `ns.Pixels(frame, n)` converts pixels to UI units.
  `ns.Snap` and `ns.SnapEven` round sizes.
- Every position chains from a pixel-aligned origin. Place odd-width frames by
  a corner (TOPLEFT/BOTTOMLEFT with a floored offset), never by CENTER.
- Borders are 1px black. Neighbouring buttons share a border
  (`ns.layout.buttonSpacing = -1`). Separate groups get a 1px gap.
- Sizes come from `ns.layout` in `core.lua`. `healthHeight` drives the action
  button size (`ns.layout.ButtonPixels`, `GridPixels`) and the minimap width.
  The cast bar height is health minus power minus 1px, so frames line up with
  the bars.

## Hard-won rules

- **Never build on Blizzard's button templates or mixins.** For example,
  `ActionBarButtonTemplate` registers buttons into Blizzard's shared dispatch,
  and an addon-created entry taints it. Blizzard's own buttons then throw
  "attempt to perform boolean test on a secret boolean value (execution
  tainted by 'miniui')". Use bare `SecureActionButtonTemplate` and keep all
  display code here (see `actionbars/skin.lua`, `actionbars/actionbars.lua`,
  `actionbars/stance.lua`, `bags/bags.lua`).
- **Secret values.** Tainted code can't branch on secret values. Guard with
  `issecretvalue` and skip, or pass the value straight to a widget setter.
  Prefer client-evaluated helpers: colour curves
  (`EvaluateCurrentHealthPercent`), duration objects, `SetAlphaFromBoolean`,
  `SetTimerDuration`.
- **oUF unit field.** The embedded oUF never sets `frame.unit`. Use
  `frame.__unit`. Don't use Blizzard `UnitFrame_*` helpers on oUF frames.
  `style.lua` has its own tooltip handlers.
- **oUF style errors.** An error in the style function leaves that frame's
  elements disabled, because oUF enables them after the style runs. Symptoms
  look unrelated, such as colours "breaking".
- **Protected frames.** Secure buttons, and anything anchored to them, can only
  be moved, shown or rebound out of combat. Defer the change until
  `PLAYER_REGEN_ENABLED`.
- **Hiding Blizzard frames.** Reparent them to a hidden frame. Hooking
  `SetPoint` with a reentrancy guard keeps Blizzard from moving frames we've
  repositioned (see `minimap/minimap.lua`).
- **Checking media files.** Use `C_UIFileAsset.IsKnownFile(path)`.
  `SetFont`/`GetFont` probing gives false negatives in this client.
- **Aura containers.** Aura data (lookups, `UNIT_AURA` payloads) is fully
  secret in combat, so aura-driven display goes through `AuraContainer`
  (`CustomAuraContainerTemplate`): the client filters and shows buttons, Lua
  only builds them. Rules, learned the hard way (see `auras/procs.lua`):
  build containers and groups at login or out of combat; use `AddAuraGroup`
  with `candidateFilters.includeSpellIDs` to watch one spell (`AddAuraSlot`
  showed nothing); size buttons through the group's `layout.elementWidth` /
  `elementHeight`; no script handlers on buttons (the client then refuses
  to show them); everything made in `initializeFrame` is forbidden to addon
  code afterwards, so build it complete and anchor it to frames you own;
  animate with `button:AddAuraShownAnimation(group)`. Buttons that overlap
  by their 1px edge need half-pixel hit rect insets on every side, or the
  tooltip drops when the mouse crosses between them. The AuraTimers addon
  (`../auratimers`) is a working reference.
- **Chat lines.** Don't override `CHAT_*_GET` strings or replace a chat
  frame's `AddMessage`: either taints Blizzard's chat handler, which then
  fails on secret values. To change how lines look, post-hook `AddMessage`
  and rewrite the newest history entry (`frame.historyBuffer:GetEntryAtIndex(1)`,
  index 1 is the newest; count with `GetNumElements()`), skipping secret
  messages. The window draws it on its next update (see `chat/format.lua`).
  To react to new lines while scrolled up, hook the `Flash` of the
  shrunk-out-of-sight `ScrollToBottomButton` (`chat/chat.lua`).
- **Errors at logout are invisible.** Code run on `PLAYER_LOGOUT` (saving
  SavedVariables) should `pcall` and store the error in the saved table, so
  `/dump` can show it.
- **Timer text formatters.** `C_StringUtil.CreateSecondsFormatter()` is opaque
  and always puts a space before the unit ("42 m"). For custom text use
  `C_StringUtil.CreateNumericRuleFormatter()` with `AddBreakpoint({threshold,
  format, step, rounding, components = {{div, mod, step, rounding}}})`, as in
  `auras/button.lua` (AuraTimers and Plater do the same).

## Workflow

- `/rl` reloads. `.toc` changes and new Lua files load with `/rl`; no client
  restart is needed. A brand-new media file (font, texture) may still need a
  restart.
- Dev tools: `/mfonts` (font sampler), `/mtest` (unit frame colour grid; uses
  the real `Layout` and colour functions).
- Load order lives in `miniui.toc`. Modules share state through `ns` (for
  example `ns.actionbar`, `ns.minimap`, `ns.layout`, `ns.colors`).
  Frames that follow a protected bar without anchoring to it register in
  its `onLayout` list (`ns.actionbar.onLayout`, `ns.stancebar.onLayout`) and
  position from its edges.
