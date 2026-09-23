# Double Battles 0.12.0-test.4

Development test build for engine 0.3.1. New gameplay testing is pending.

- Native Gen3 consumes the shared encounter, ally, trainer, distance, experience
  and HUD preferences. Wild doubles use the native four-slot State/turn engine;
  wild flags and native last-opponent catching/storage remain intact. Normal
  RUN uses native wild odds against the fastest living foe.
- Gen2 now collects both local allies' commands, keeps SOLO replacements solo,
  promotes a surviving ally into the native menu position and applies HALF EXP.
- Gen2/Gen3 adjacent trainer pairs keep separate reserve pools and award both
  native prizes and defeat flags. Story and authored trainer battles are excluded
  from automatic pairing.
- Optional owner-tagged aerial encounters use registered flockmate sources and
  vetoes. Battle Art HUD ownership/preferences and Online negotiated mechanics
  remain optional; no companion mod becomes required.

Validation: native State/adapter 44, Gen2 native core 50, local command UI 15,
trainer pairing 11 isolated contracts; LuaJIT compilation. Existing previous
Online checks do not validate these new adapters. Gameplay, capture animation,
PC/name flow, trainer scripting, menu edge cases and combined multiplayer still
need acceptance testing. Gen2 spread-move/full interaction coverage remains
uncertified. See docs/GENERATION_OPTION_SUPPORT.md for exact boundaries.
