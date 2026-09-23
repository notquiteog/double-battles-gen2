> Test build 0.12.0-test.5 fixes hidden native wild-double partners during the battle intro. Official intro-interpreter and parity tests pass; exact published FireRed/LeafGreen captures verify all four battlers visible and both foes animated. Native authored trainer doubles also passed. [Release notes](RELEASE_NOTES_0.12.0-test.5.md).

## Fix Gen 1 online faint synchronization and partner HUD anchors — 0.12.0-test.3

Online Gen 1 doubles now orders the same living actors on both peers. Previously a dead local partner’s empty action could consume an extra speed-tie random roll after bench replacement, ending the next turn with a state mismatch. Both sides now use host-first slot order and exclude empty/dead actions.

The optional Battle Art adapter reports both sprite heads and preserves back-sprite orientation, allowing four projected status cards. Includes the Gen 2 modern UI opt-out correction. No companion becomes required.

Verified with two native 0.3.1 clients: reproduced the divergent random-roll count, then passed paired turns through faints, bench replacement and completion with matching signatures and unchanged owned parties. Targeted Gen 2 HUD fallback/FX tests pass. Advanced move and disconnect coverage remains incomplete.

## Respect modern battle UI opt-out — 0.12.0-test.2

Gen 2 modern HUD now respects OFF during doubles as well as singles, and honors Battle Art’s shared MODERN BATTLE UI setting when that optional mod is present. Standalone operation remains supported.

TEST PRERELEASE: gameplay checks follow publication.

> Test build 0.12.0-test.1: Gen 1 online doubles mechanics provider: both players choose both moves and targets, cloned-party switches, deterministic ordering and bench refill. Native Gen 3 doubles retained. Gameplay verification pending.

**0.11.0: Crystal online paired turns.** Adds an optional Crystal link provider for Online rooms: two owned Pokemon per side, explicit target selection, paired commands, deterministic mirrored ordering, native battle effects and cloned-party restoration. Partner actions and speed use independent native stat contexts; empty online slots refill from the bench.

Historical 0.11.0 limits: Crystal doubles remain experimental; advanced move-effect combinations and the full disconnect matrix have not been exhaustively verified. FireRed/LeafGreen continue using the native doubles engine.

Requires Gen1Recomp 0.3.1 for the verified Gen 3 path. Other mods are optional; no ROM, player save or import cache is included.

**Working-tree parity update:** Gen2 and native Gen3 now consume the shared encounter, ally, trainer-pair, distance, experience, and HUD preferences. See [the option/support inventory](docs/GENERATION_OPTION_SUPPORT.md) for implementation boundaries, independent/optional contracts, and pending gameplay checks.

Gen1/Gen2 expose optional Online mechanics providers; native Gen3 uses the engine link implementation.

# Double Battles

Wild and trainer battles against two Pokémon at once: 1v2, full 2v2,
trainer doubles and two-trainer pairs, in the classic layout, the wide
layout and Dramatic Shape's 3D battle modes.

> **3D battles:** with Dramatic Shape or the Battle Art voxel fork
> installed, both Pokémon on each side stand together on the arena,
> the aim frame blinks on the mon you're targeting, and the HUD
> follows whoever is acting. On the
> STADIUM rungs a side showing two Pokémon rides the flat battle cards
> (the 3D models pose one mon a side); the models return the moment
> that side is back down to one. Camera mods that ride Dramatic
> Shape's battle camera (Battle Cinematics, for example) frame the
> same scene and need nothing extra.

Turn it on in Mod Settings: WILD DOUBLES set to SOMETIMES (about 30% of
wild encounters) or ALWAYS. A second foe from the map's own encounter
table appears beside the first, with its own HP bar. Both foes pick
moves every turn, and turn order runs across all three battlers using
the engine's normal speed rules. Each defeated foe pays out experience.
When the lead foe faints, the second steps up and the battle carries on
as a normal 1v1, so catching and running work as usual from there.

When you pick a move with both foes up, a target prompt follows: a
menu names both Pokémon with a cursor on your aim (a blinking frame
marks the sprite too), any direction key moves the cursor, A locks it
in, B goes back to the move menu. Throwing a ball opens the same
prompt: aim at the Pokémon you want, A throws, B puts the ball back
in the bag. Catching one ends the battle and the other flees.

While aiming, the target's name, level and health show alongside the
blinking frame, and move animations follow your aim to the right
sprite. After a double battle ends you get a few calm steps before the
grass can roll the next encounter.

With [wild_skies](../wild_skies) installed, a wild double first looks
for a visible bird near you: the encounter holds a moment while it
flies to your side, and the battle starts against that exact bird.
Nobody nearby means the second foe rolls from the encounter list as
usual.

Trainers join in too: anyone with two or more able Pokémon sends two
out at once (TRAINER 2V2 in Mod Settings, on by default), refilling
from their bench as you knock them down, until the fight collapses to
a normal 1v1 against their last Pokémon.

In the target prompt you can also just click (or tap) a foe to aim at
it, and click it again to lock in.

Switching works the same way: with your pair up, picking a Pokémon
from the party menu asks which of yours steps back (LEFT/RIGHT to aim,
a green frame marks it, A locks in, B cancels; clicking works too).
The recall spends that Pokémon's turn and resolves before any move
lands, so the switch-in can still be hit, exactly like gen 1's own
free-hit rule. Your other Pokémon keeps its move.

For map authors: `double_battles:trainer_pair OPP_A idxA OPP_B idxB`
stages two trainers against your pair; nothing pairs up on its own.

## Known limits (roadmap items)

- Animations shift rigidly to the partner positions in the flat
  layouts; long beams can look approximate. In 3D the burst plays at
  the pair's cell rather than on the exact partner.
- Pointer aiming is classic/wide only; in 3D use LEFT/RIGHT and A.
- Link play with this mod enabled is refused by the handshake, by
  design: modded battle formats cannot stay in lockstep with unmodded
  peers.

## For mod authors

`exports.startWildDouble(speciesA, levelA, speciesB, levelB)` starts a
1v2 on demand, and the script command `double_battles:start` does the
same from map scripts. `exports.isDoubleBattle(battle)` tells you
whether a battle object is one of ours. `registerPartnerSource`
supplies the second foe, `registerAllySource` picks which of the
player's mons fights beside their lead, and `registerDoubleVeto`
keeps chosen encounters strictly 1v1; see INTEGRATION.md in the
monorepo for the full contract.

## Install

1. Download `double_battles-<version>.zip` from the
   [releases page](https://github.com/shanehudson-gen1recomp-mods/double_battles/releases).
2. In the game, open MODS from the pause menu (or press F10) and pick
   Import mod .zip.
3. Enable the mod in the same menu.

Pokémon is a trademark of Nintendo; the Gen 1 games are © Nintendo /
Creatures Inc. / GAME FREAK inc. Unofficial fan mod; no ROMs, no
copyrighted game content. See the repository NOTICE.md.

## Crystal doubles (this fork)

Crystal uses the native Gen 2 battle simulator with a doubles turn adapter.
Both opponents render with individual HP cards. After choosing a move, select
an opponent with the directional buttons, confirm with A, or cancel with B
without spending PP. The selected opponent's status card is highlighted.

Automatic wild doubles apply only to ordinary native random step encounters,
using that map's grass or water table. Visible overworld spawns, fishing,
scripted/special encounters, and battles supplied by other mods retain their
original Pokémon. ALWAYS does not override those boundaries. Trainer doubles
use the trainer's existing party. A surviving 1v1 returns to native singles.

The local Crystal menu collects both allies' move or switch choices before
committing a round. Press B at the partner's command menu to revise the first
choice. Nearby ordinary trainers may combine their separate rosters; both
native defeat events and prizes are handled on victory.

Online doubles use the existing optional negotiated mechanics provider; ordinary
local encounter settings do not modify link construction. Newly added local
and native Gen3 parity paths have isolated contract coverage. Their gameplay,
capture animation, and multi-client integration checks remain pending. Gen2
spread-move parity and the complete doubles interaction matrix are not certified.
