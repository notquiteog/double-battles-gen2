> Test build 0.12.0-test.1: Gen 1 online doubles mechanics provider: both players choose both moves and targets, cloned-party switches, deterministic ordering and bench refill. Native Gen 3 doubles retained. Gameplay verification pending.

**0.11.0: Crystal online paired turns.** Adds an optional Crystal link provider for Online rooms: two owned Pokemon per side, explicit target selection, paired commands, deterministic mirrored ordering, native battle effects and cloned-party restoration. Partner actions and speed use independent native stat contexts; empty online slots refill from the bench.

Known limits: Gen 1 online doubles are not implemented. Crystal doubles remain experimental; advanced move-effect combinations and the full disconnect matrix have not been exhaustively verified. FireRed/LeafGreen continue using the native doubles engine.

Requires Gen1Recomp 0.3.1 for the verified Gen 3 path. Other mods are optional; no ROM, player save or import cache is included.

**0.10.0: Native Gen 3 doubles and restored settings.** Adds a native Gen 3 double-battle adapter and optional Online integration. Preserves native trainer double battles and exact visible-spawn encounters. Restores independent in-game settings in GB and Gen 3.

Gen 1/2 online doubles are not implemented. Local Gen 1/2 doubles and native Gen 3 doubles remain separate paths.

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

The four-slot simulation exists, but normal Crystal UI still commands one
player-side active Pokémon; collecting both allies' commands is unfinished.
Spread-move parity and the full set of doubles interactions are not certified.
Online+ and native link battles remain singles: their protocol has no doubles
command/target exchange, and automatic doubles must not modify them. Local
simulation checks are not a two-computer Internet multiplayer verification.
