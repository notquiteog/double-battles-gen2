# Optional native scene layout

Gen2 BattleState exposes `state:nativeSceneLayout()`. It returns
`gen2-native-pair` when the native non-tutorial doubles HUD owns the screen,
and `nil` for singles, tutorials, a modern HUD provider, or a failing provider
reader. Scene companions may use this identifier to frame their actors in the
clear native picture regions. It does not change native drawing or gameplay;
companions must tolerate its absence in older installs.

The layout uses the existing 160×144 native canvas: enemy HUDs on the left,
player HUDs on the right, with picture feet centered near (120,42) and (41,94).
`tests/gen2_native_layout_test.lua` verifies ownership and idempotent install.

## Native text resolution — 2026-10-20

Static native command/move/target panels compose their original HUD methods at
window resolution through the public render.hud hook. Exact card transforms,
ROM glyphs, HP/status/EXP readers and native panel origin/scale remain unchanged.
This avoids permanently shrinking glyphs into160×144 before window enlargement.
Animations, fades, wide layout, modern providers, covered/replaced battles and
installations without the required hook retain the original drawing path.
There are no extra canvases or desktop-only APIs.

Official0.3.91 NVIDIA Gold/Silver/Crystal original trainer doubles pass native
identity/HP checks at640×480,360×640,320×240 and240×360; all12captures inspected.
Names and HP are legible in the first two sizes. At tiny1× sizes, native fractional
card text still has fewer pixels than its source glyphs; this change does not
reflow the native layout or certify phone readability. Physical Android/iOS
memory, touch and safe-area behavior remain unverified by these desktop captures.
All six Gen2 companion suites pass, including new queue ownership, return/error
restoration and animation/provider/fade fallback checks.
Scratch evidence: `voxel-parity-20261020/pair-hud-0391`.

## Optional safe viewport — 0.14.5

An optional theme's `viewport(windowWidth, windowHeight)` supplies the usable
window origin and size. Modern paired cards translate into that viewport and
subtract its origin from projected heads before dividing by HUD scale. Missing
themes keep the full window; disabling Modern UI restores the original paired
HUD. Focused tests check all four projected heads and graphics restoration.
Official 0.3.91 Gold/Silver/Crystal desktop captures verify the optional provider
with simulated landscape/portrait safe areas; physical-device readability and
touch/safe-area behavior remain unverified. Double Battles alone also passes a
Gold native trainer-double check with the original HUD and three damage replays.

## Optional modern safe area — 2026-10-20

The modern provider's optional viewport method supplies safe-area bounds.
Modern paired cards translate their origin and projected actor anchors together;
older providers retain the whole-window layout. Original native HUD and input
are unchanged. Official0.3.91 Crystal paired landscape640×360 and portrait360×640
public-inset simulations pass actual card/command bounds; four captures inspected.
All six Gen2 suites pass. Evidence: Battle Art
`docs/NATIVE_SAFE_AREA_HUD_2026-10-20.md`; physical phones remain unverified.
