# Portable API 3 audit — 2026-10-23

Engine baseline: official gen1recomp **0.3.96**, release commit `0e92b58`.
Manifest selects API 3 and requires `>=0.3.96 <2.0.0`; the mod version is unchanged.
References: [release](https://github.com/bryanthaboi/gen1recomp/releases/tag/v0.3.96),
[official modding documentation](https://github.com/bryanthaboi/gen1recomp/blob/v0.3.96/docs/modding.md).
The audit inspected the matching Loader, UnifiedWorld, UnifiedCallbacks,
UnifiedContent, UnifiedIds, Gen2Compat, native option rows and battle implementations.

## Public contracts used

- `mod.game` is the loader's live, generation-selected service owner. Seven
  singleton Game lookups now use it. Gen1 `overworld` and Gen2 `world` are
  resolved explicitly; native battle handles remain native.
- `ui.options.rows(game, rows)` now fires in Gen3, including Ruby/Sapphire's
  `Rows.withCart` path. The mod composes through that public hook in every
  generation and probes `mod:supports('hooks', 'ui.options.rows')`. Private
  `Rows.build`/`Rows.group` wrappers and custom page ownership were removed.
  Existing rows, later wrapper arguments, callbacks and cancel order survive.
- API3 canonical record conversion does not convert `context.battle` into a
  new simulation object. `battle.run` and `exp.gain` continue using that native
  battle handle; encounter hooks delegate canonical descriptors unchanged.
- API3 content command registrations and event subscriptions remain public.
  Existing compatibility battle engines still own the actual four-actor turn
  mechanics. Optional UI, voxel, riding, online and skies providers remain optional.

## Organic source protocol

Gen3 exports `organicProtocol = 1` and:

```lua
local ok, why = doubles.withOrganicSource(species, level, {
  map = nativeMapId, terrain = 'air', requirePartnerSource = true,
}, function()
  return mod.world:startWildBattle(species, level, onDone)
end)
```

`species` is a canonical string, and level is an integer in 1..100. The
synchronous scope matches the newly created native descriptor by resolved
species and level, consumes attribution once, and restores an outer scope
on return, refusal or error. It preserves callback return arity. This allows
public UnifiedWorld to allocate a fresh encounter table without losing the
same-flock/provider-only provenance. The ordinary option chance, vetoes,
script/tutorial exclusions and provider refusal remain authoritative; a
required source never falls back to an arbitrary grass/shared encounter.
The older `tagOrganic(nativeEncounter, context)` export is retained.

## Necessary internal seams / API gaps

- Native Gen3 `Encounters.onStep` and bridge start preserve object-identity
  provenance. Public `encounter.roll`/`encounter.species` are called before
  the engine constructs a fresh closed-field descriptor and cannot carry an
  opaque source marker to bridge start. An asynchronous timing/species guess
  would misclassify unrelated scripted encounters.
- Native battle creation, replacement candidates, four-actor turns, target
  selection and Gen2 World/BattleState adapters have no equivalent public
  roster-construction/turn-engine mutation API. Snapshot and intent APIs do
  not supply those features. `engine_internals` is retained deliberately.
- Public options supplies `get`/`define`, but no setter/persistence operation.
  Row callbacks retain native option storage, option-change emission and
  writeOptions/persistOptions. Native RS font label-overflow handling has no
  public renderer extension and remains narrowly bounded/unloadable.
- The Gen2 OverworldController class facade is retained where a class patch
  must reach native instances; it is distinct from replacing live Game reads.

## Evidence and limits

- Matching official 0.3.96 SDK: **14 suites / 444 assertions pass**. Three old
  test fixtures were refreshed to the existing left/right foe controls,
  engine BLINK_MON duration and official Gen2 battleRules fixture.
- `gen3_parity_unit.lua`: **77 contracts** with the actual 0.3.96 State,
  UnifiedWorld and UnifiedIds, including canonical FARFETCHD, a fresh native
  descriptor, chance/off/source refusal, once-only/nested/error scope cleanup.
- Native option callback tests cover eight representative editions; existing
  Gen1 spread, Gen2 commands/pairs/targets/animations/HUD and Gen3 targets pass.
- Native 0.3.96 standalone load/options registration passes Red, Gold,
  Crystal, FireRed and Emerald with exit 0, no loader errors and zero entries
  in `loader:legacyReport('double_battles')` on these exercised paths.
- Opened native options screens retain all eight rows in FireRed, LeafGreen,
  Ruby, Sapphire and Emerald. Captures show native fonts, labels and values;
  RS long labels remain clipped/scrolled within their label column.
- These checks do not claim completed two-client battles in all eleven
  editions or complete removal of engine internals. Release integration and
  broader combined native gameplay checks are coordinated separately.
