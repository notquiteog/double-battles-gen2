# Native GSC animation ownership

Native battle screens expose two optional, read-only presentation readers:

- `screen:nativeAnimationSlot()` returns the exact slot for an original paired
  send-out (`player`, `player2`, `enemy`, `enemy2`).
- `screen:nativeAnimationActors()` returns the context of a queued native move
  or its chained after-animation: `{player=slot, enemy=slot, playerMon=mon,
  enemyMon=mon}`. These keys describe the runner's logical picture boxes.
  Friendly-target moves can map both boxes to one actual team.

Both readers return nil for unsupported, stale or unrelated state. Consumers
must preserve native fallback and must not mutate the descriptor, mons or runner.
The companion itself routes native picture/HUD, cry/flying and palette readers
through detached context; the live battle slots are never changed by presentation.
`nativeSceneLayout()` remains the independent native paired HUD descriptor.

Native 0.3.91 Linux NVIDIA checks passed on Gold, Silver and Crystal with Battle
Art and the other five independent companions. Opposing Tackle, Growl, friendly
player Tackle and friendly enemy Tackle retain original OFF/ON script clocks:
81/81, 212/212, 81/81 and 74/74 frames. Exact actor identity and UI ownership
passed; 27 final captures were inspected in the voxel parity evidence batch.
This is bounded presentation verification, not exhaustive move coverage.

The fixture-only native core runner accepts the imported original rule table:

```
luajit tests/run_gen2_core.lua ENGINE_ROOT IMPORTED_GEN2_TYPE_CHART
```

The current native core passes 88 contracts. The rule table stays in the user's
isolated import, not this repository. Focused tests also cover stale identities,
failed scripts, pending animations, friendly targets, detached palette ownership
and single-battle fallback. Secondary damage events and native form proxies
remain separate audit cases.
