# Generation option support

Implementation inventory for the working tree against engine 0.3.1. This is
code/isolated-contract coverage, not a claim that the new gameplay or rendering
paths have completed cart testing.

| Setting | Gen1 | Gen2 | Native Gen3 |
| --- | --- | --- | --- |
| MODERN BATTLE UI | Existing modern presentation | Independent four-slot cards, target cursor, optional Battle Art theme/anchors | Independent native healthbox cards; yields to Battle Art's public modern-UI ownership/preferences |
| WILD DOUBLES: OFF/SOMETIMES/ALWAYS | Existing organic encounter policy | Native grass/water rolls; 0/30/100%; optional explicitly tagged owner encounters | Native step encounter identity; 0/30/100%; optional explicitly tagged owner encounters |
| YOUR SIDE: PAIR/SOLO | Existing ally selection | Second healthy non-egg ally, two move/switch selections; SOLO excludes the partner slot during replacement | Native slots 0/2 with both native command menus; SOLO keeps slot 2 absent |
| TRAINER 2V2 | Existing trainer-party adapter | Existing trainer's second healthy mon | Detached request enables native four-slot state for ordinary trainer parties |
| TRAINER PAIRS | Existing adjacent trainer convention | Two visible unbeaten ordinary trainers, separate rosters/rewards and both defeat events | Two visible unbeaten ordinary trainers, separate replacement pools/rewards and both native defeat flags |
| PAIR DISTANCE: 1/2/3 | Existing cell range | Same cell-distance bound | Same cell-distance bound |
| DOUBLES EXP: FULL/HALF | Existing experience hook | Actual native battle context now participates in shared hook | Native experience hook; link battles excluded |
| CRYSTAL 2V2 | Not applicable | Gates automatic local doubles | Not applicable |
| ONLINE DOUBLES | Negotiated provider | Negotiated provider | Native link-doubles capability preference |

Defaults preserve existing shared preferences. Native Gen3's previous saved
`gen3_trainer_doubles` value initializes the shared trainer setting when no
shared value exists. Original authored native trainer doubles remain native.

Ordinary fishing, visible ground spawns, scripts, tutorials, contest/Safari,
roamers and explicitly marked special battles retain their owner's encounter.
A provider can opt its own encounter into doubles. Tagged aerial encounters
require a registered partner source; they do not fabricate a ground opponent.
A ball in Gen2/Gen3 is refused before inventory/RNG use while two wild foes
remain. The last opponent, including slot 2/3, uses native catching, storage
and completion. Gen1 retains its existing targeted-ball flow.

Local Gen2 collects both allies' move/switch commands and lets B return from
the partner's menu. Native item effects still apply immediately: an item used
before selecting the first ally consumes the team's turn; one used after the
first selection retains that selected action. Native Gen3 uses its original
four-slot item/move/target UI; a last-wild ball consumes the team's turn.

The test.5 native wild-intro adapter reuses the engine's multi-ID ally throw,
cry and healthbox steps and synchronizes the second enemy's opening slide.
It applies only to Doubles-owned wild doubles and ends at intro completion or
reset, preserving independent move/faint/capture presentation afterward.
Trainer/link intros, absent SOLO allies and already-complete native sequences
are preserved. Published test.4 exhibited invisible slots 2/3 in local wild
doubles; post-publication test.5 visual verification is pending.

## Independence and optional contracts

No companion mod is required. Battle Art supplies presentation only. Doubles
uses `battlePresentation.modernUIEnabled()` and, in native Gen3,
`battlePresentation.nativeHudOwned()` to cooperate with its HUD. Turning off
or removing Battle Art leaves the native scene and Doubles' own cards usable.

Online owns consent, transport, compatibility, cloned parties, and teardown.
Doubles supplies only its `exports.online` mechanics provider. Automatic local
decoration excludes native link/Online construction; local SOLO, encounter
rates and trainer pairing never change a negotiated link match.

All generations expose partner-source, trainer-pair-source and double-veto
registration. Gen2 source context includes `generation=2`; native Gen3 includes
`generation=3`, `kind`, and `enemy.mon` with the native encounter descriptor.
Native Gen3 partner sources return numeric species, level. Native trainer-pair
sources return one native trainer ID; Gen1/Gen2 return trainer class and member.
Registration/unregistration works without the producer mod being installed.

`tagOrganic()` retains the existing Gen1/Gen2 one-second, single-construction
opt-in used by Wild Skies and Ride. Native Gen3 instead requires the exact
encounter table: `tagOrganic(encounter, {map=..., terrain='air',
requirePartnerSource=true})`. The tag is consumed by the next start for that
object and never leaks to a later encounter with the same species. Wild Skies
owns shared flyer claims; Doubles never consumes remote shared entities.

## Validation and remaining checks

- `luajit tests/gen3_intro_unit.lua ENGINE_ROOT`: 26 checks using the official
  State/IntroSeq interpreter plus two already-complete-engine guards; original
  invisible partners reproduced before adaptation, actual native slide/throw/
  cry/healthbox progression, SOLO, reset and later hidden-move preservation.

- `luajit tests/gen3_parity_unit.lua ENGINE_ROOT`: actual official native State
  with mocked external services; wild flags, source scope, solo slots, wild RUN odds, trainer
  pools/rewards/flags, experience, HUD fallback, capture inventory and slot 3.
- `luajit tests/run_gen2_core.lua ENGINE_ROOT`: official native Gen2 combat
  primitives, 50 deterministic core contracts including owner-specific reserves
  and healthy-primary promotion.
- `luajit tests/gen2_commands_unit.lua`: 15 command/cancellation/item contracts.
- `luajit tests/gen2_pairs_unit.lua`: 11 distance/roster/reward/flag contracts.

Published test.4 passed FireRed and Crystal two-endpoint online doubles with
party restoration and persistent rooms. Those checks did not exercise the
local wild intro; the new test.5 presentation fix needs post-publication
FireRed/LeafGreen visual acceptance. Native capture animation, naming/PC storage,
authored trainer combinations, map scripting and switch/item menu edge cases
still need broader coverage. Gen2 spread moves and the full doubles move
interaction matrix are not certified. Existing prior online checks do not
validate the newly added local/native adapters.
