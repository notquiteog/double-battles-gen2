# Double Battles 0.14.5 — 2026-10-20

Native GSC move scripts and their chained hit animations retain the exact two
actors that generated the queued event. Partner and friendly-target damage
uses the correct native picture, cry, palette and HUD context. Proven display
copies produced by the original Transform/identity queue retain that ownership;
stale records, replaced battles and unsupported scripts keep native fallback.

Static original paired HUD cards compose their ROM glyphs at window resolution
through the public HUD hook. Animation/fade paths, wide layout, covered screens
and modern providers retain their existing ownership. When the optional Modern
UI provider supplies a safe viewport, its paired cards subtract the viewport
origin before positioning projected heads and translate the complete HUD into
the usable area. No other mod is required.

## Verification

Official Gen1Recomp 0.3.91, LÖVE 11.5, Linux NVIDIA RTX 5060 Ti. Isolated copied
Gold/Silver/Crystal profiles; no player progress was saved. The frozen source
passed four native runners: G/S/C with optional Modern UI and Gold with Double
Battles alone. All 37 captures were inspected:

- Original trainer doubles: all four identities and HP readers, command HUD at
  640×480, 360×640 and 320×240, plus the original move menu.
- Three real native damage-event replays per runner: partner→foe,
  foe→partner, and friendly target, completing in 49, 42 and 49 native frames.
  Picture ownership, actor identity and completed-runner cleanup pass.
- Optional Modern UI: landscape/portrait captures using a simulated public
  safe-area response, four cards retained, followed by OFF restoring native
  paired cards. These desktop fixtures do not certify physical phone usability.

Thirteen focused Lua suites pass, covering queued actor provenance, Transform,
stale/error restoration, native/modern HUD fallback, safe-area projected heads,
command/target ownership, trainer pairs, source argument forwarding and option
overflow. The original imported GSC rule table passes 89 native core contracts;
the current engine's Gen3 parity adapter passes 57 contracts. The older Gen3
intro harness targets 0.3.1 and requires its legacy trainer-art fixture; it is
not counted as a current-engine pass.

Earlier bounded GSC Transform/OFF/ON checks remain recorded in
[native animation ownership](docs/NATIVE_ANIMATION_OWNERS.md). This release does
not certify every move, form, multiplayer/disconnect interaction or mobile
device. Gen1/Gen3 gameplay and their original fallback paths are retained.

No ROMs, extracted original assets, saves or QA captures are included.
