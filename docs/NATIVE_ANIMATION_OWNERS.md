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

The current native core passes 89 contracts. The rule table stays in the user's
isolated import, not this repository. Focused tests also cover stale identities,
failed scripts, pending animations, friendly targets, detached palette ownership
and single-battle fallback.

Standalone secondary damage events now keep the actual HP target and explicitly
select the native logical hit script/source slot. Explicit self-hit and residual
`animSide` keys are rewritten with the original event context. Custom scripts,
disabled hit animations and the original duplicate-hit latch remain unchanged;
the presentation adapter uses a detached event rather than rewriting the queue's
original event record.

Native 0.3.91 G/S/C damage replays passed with staging OFF/ON: partner-to-enemy
49/49 frames, enemy-to-partner 42/42, and friendly-target 49/49. All four actors,
identity, exact picture ownership and restoration passed. Twenty-one final
captures were inspected (`damage-0391` scratch batch). These are explicit
presentation replays of real damage events, not exhaustive battle simulation.
Native display copies created by the original public `push(event)` method now
retain proven owner identity through Transform/identity events. No metatable,
upvalue or species matching is used. Unproven copies and replaced actors still
fall back. G/S/C original Transform replays pass 116/116 OFF/ON native frames;
all four cards, old/new form order and actor identity pass. Nine final captures
were inspected (`transform-0391`).
