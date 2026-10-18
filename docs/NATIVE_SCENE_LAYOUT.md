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
