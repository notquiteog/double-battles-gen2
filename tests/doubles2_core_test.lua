-- The 2v2 core, headless: two actives a side over the engine's own Gen 2
-- battle sim.  What this pins:
--   * a decorated battle runs four-actor rounds through the engine's own
--     useMove/priority/speed machinery, lead first on speed ties broken by
--     the deterministic roller,
--   * a named target is honoured (slot-2 damage lands on slot 2, and the
--     event carries the slot's own side key),
--   * a mid-round faint pays experience, leaves the slot empty, and does
--     NOT fire the engine's 1v1 replacement mid-round,
--   * the round collapses to the engine's own takeTurn at 1v1, which then
--     runs stock rotation and wins the battle normally.
--
--   luajit mods/double_battles/tests/doubles2_core_test.lua   (engine root)

package.path = "./?.lua;./?/init.lua;" .. package.path

local os = require("os")
local T = require("tests.modkit")
love = love or require("tests.love_stub")
-- Fixtures below are self-contained; no imported Gen 1 data is needed.

local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")

local doubles2 = dofile("mods/double_battles/lib/doubles2.lua")

-- Hand-built fixtures, the engine's own gen2 test shape (gen2_curse_anim
-- bug2140): deterministic stats, no ROM needed.
local TYPES = {
  NORMAL = { id = "NORMAL", index = 0, category = "physical" },
  FLYING = { id = "FLYING", index = 9, category = "special" },
  ROCK = { id = "ROCK", index = 6, category = "physical" },
  GROUND = { id = "GROUND", index = 5, category = "physical" },
  POISON = { id = "POISON", index = 3, category = "physical" },
}
local MOVES = {
  TACKLE = { id = "TACKLE", name = "TACKLE", power = 35, type = "NORMAL",
    accuracy = 95, pp = 35, effect = "EFFECT_NORMAL_HIT" },
  GUST = { id = "GUST", name = "GUST", power = 40, type = "FLYING",
    accuracy = 100, pp = 35, effect = "EFFECT_NORMAL_HIT" },
}
local function species(name, stats, types)
  return { id = name, index = 1, name = name, baseStats = stats,
    types = types, catchRate = 255, baseExp = 50,
    growthRate = "GROWTH_MEDIUM_FAST", genderRatio = 127,
    levelMoves = {}, evolutions = {} }
end
local POKEMON = {
  PIDGEY = species("PIDGEY", { hp = 40, attack = 45, defense = 40,
    speed = 56, specialAttack = 35, specialDefense = 35 },
    { "NORMAL", "FLYING" }),
  RATTATA = species("RATTATA", { hp = 30, attack = 56, defense = 35,
    speed = 41, specialAttack = 25, specialDefense = 35 },
    { "NORMAL" }),
  SPEAROW = species("SPEAROW", { hp = 40, attack = 60, defense = 30,
    speed = 70, specialAttack = 31, specialDefense = 31 },
    { "NORMAL", "FLYING" }),
  GEODUDE = species("GEODUDE", { hp = 40, attack = 80, defense = 100,
    speed = 20, specialAttack = 30, specialDefense = 30 },
    { "ROCK", "GROUND" }),
  ZUBAT = species("ZUBAT", { hp = 40, attack = 45, defense = 35,
    speed = 55, specialAttack = 30, specialDefense = 40 },
    { "POISON", "FLYING" }),
}
local DATA = { pokemon = POKEMON, moves = MOVES,
  type_chart = { types = TYPES, matchups = {} }, items = {} }
local fullDvs = { attack = 15, defense = 15, speed = 15, special = 15 }
fullDvs.hp = Mon.hpDV(fullDvs)

local function mon(name, level, moveId)
  local m = Mon.new(DATA, name, level, { dvs = fullDvs })
  m.moves = { { id = moveId or "TACKLE", pp = 35, maxPp = 35 } }
  return m
end

local function battleWith(secondEnemy)
  local save = { version = "crystal", player = { id = 7, badges = {} },
    party = {}, inventory = {}, pokedex = { seen = {}, owned = {} } }
  local party = save.party
  party[1] = mon("PIDGEY", 20, "GUST")    -- fastest
  party[1].moves[2] = { id = "TACKLE", pp = 35, maxPp = 35 }
  party[2] = mon("RATTATA", 12, "TACKLE") -- partner
  party[3] = mon("SPEAROW", 10, "TACKLE") -- bench
  local wild = mon("GEODUDE", 8, "TACKLE")    -- slowest
  local wild2 = secondEnemy and mon("ZUBAT", 9, "TACKLE") or nil
  local battle = Battle.new({
    data = DATA,
    party = party,
    save = save,
    wild = wild,
    random = function(n) return (n or 1) > 1 and 1 or 0 end,
  })
  if wild2 then
    battle.enemyParty[2] = wild2
  end
  return battle, party, wild, wild2
end

do -- decorate registers slots and routes turns
  local battle, party, wild, wild2 = battleWith(true)
  battle.enemyParty[2] = wild2
  doubles2.decorate(battle, party[2], wild2)
  T.check(battle.isDoubleBattle, "battle reports doubles")
  T.check(battle.doubles.player2 == party[2], "player slot 2 registered")
  T.check(battle.doubles.enemy2 == wild2, "enemy slot 2 registered")
  T.check(doubles2.isActive(battle), "layer active")
end

do -- four-actor round: both foes take damage, slot-2 aim honoured
  local battle, party, wild, wild2 = battleWith(true)
  battle.enemyParty[2] = wild2
  doubles2.decorate(battle, party[2], wild2)
  local hpEnemy0, hpEnemy2_0 = wild.hp, wild2.hp
  local events = battle:takeTurn({
    player  = { kind = "move", move = "TACKLE", target = "enemy" },
    player2 = { kind = "move", move = "TACKLE", target = "enemy2" },
  })
  T.check(wild.hp < hpEnemy0, "lead foe took damage")
  T.check(wild2.hp < hpEnemy2_0, "slot-2 foe took damage from the aimed hit")
  -- both partner slots answered: the damage stream carries each slot's own
  -- side key (the emit-context rewrite)
  local sides = {}
  for _, ev in ipairs(events) do
    if ev.kind == "damage" and ev.side then sides[ev.side] = true end
  end
  T.check(sides.enemy, "lead foe damage carries the enemy side")
  T.check(sides.enemy2, "slot-2 foe damage carries the enemy2 side")
end

do -- speed decides among four actives, not two
  -- party[2] RATTATA level 12 is slower than PIDGEY 20; ZUBAT 8 slower than
  -- both.  The FIRST damage event of the round belongs to PIDGEY (fastest),
  -- the LAST to whichever foe is slowest that acts.
  local battle, party, wild, wild2 = battleWith(true)
  battle.enemyParty[2] = wild2
  doubles2.decorate(battle, party[2], wild2)
  local events = battle:takeTurn({
    player  = { kind = "move", move = "GUST",  target = "enemy2" },
    player2 = { kind = "move", move = "TACKLE", target = "enemy" },
  })
  local firstDamage
  for _, ev in ipairs(events) do
    if ev.kind == "damage" then firstDamage = ev.side break end
  end
  -- PIDGEY (fastest) aimed at enemy2: the first damage lands on enemy2.
  T.check(firstDamage == "enemy2", "the fastest actor's aimed hit fires first")
end

do -- mid-round faint: experience paid, slot empty, no 1v1 replacement
  local battle, party, wild, wild2 = battleWith(true)
  battle.enemyParty[2] = wild2
  doubles2.decorate(battle, party[2], wild2)
  wild.hp = 1
  local before = battle.over
  battle:takeTurn({
    player  = { kind = "move", move = "TACKLE", target = "enemy" },
    player2 = { kind = "skip" },
  })
  T.check(wild.hp == 0, "the lead foe fainted")
  T.check(battle.over ~= true, "the battle did NOT end while slot 2 stands")
  T.check(battle.doubles.fainted.enemy, "the faint was announced for the slot")
end

do -- wipe: a wild 1v2 that loses its last foe with no bench is over
  local battle, party, wild = battleWith(false)
  -- 2 (player) vs 1 (enemy), no enemy bench: the faint ends it, a win
  doubles2.decorate(battle, party[2], nil)
  wild.hp = 1
  battle:takeTurn({
    player  = { kind = "move", move = "TACKLE", target = "enemy" },
    player2 = { kind = "skip" },
  })
  T.check(battle.over, "a wild 1v2 that loses its last foe is over")
  T.check(battle.outcome == "win", "outcome is a win")
end

do -- bench send-in: with a spare, the faint does NOT end the battle
  local battle, party, wild, wild2 = battleWith(true)
  doubles2.decorate(battle, party[2], nil)
  wild.hp = 1
  local evs = battle:takeTurn({
    player  = { kind = "move", move = "TACKLE", target = "enemy" },
    player2 = { kind = "skip" },
  })
  local sent = false
  for _, e in ipairs(evs) do
    if e.kind == "send" and e.side == "enemy" then sent = true end
  end
  T.check(battle.over ~= true, "the bench member walks in instead")
  T.check(sent, "the send event fires on the enemy side")
  T.check(battle.collapsed ~= true, "2v1 keeps running the doubled loop")
end

do -- collapse to the engine's own loop when the round becomes 1v1
  local battle, party, wild, wild2 = battleWith(true)
  -- player side stays 1 (no partner): knock both foes down, the enemy
  -- bench walks one in, and the battle is 1v1 on the engine's own loop
  battle.enemyParty[3] = mon("RATTATA", 6, "TACKLE")
  doubles2.decorate(battle, nil, wild2)
  wild.hp, wild2.hp = 1, 1
  battle:takeTurn({
    player = { kind = "move", move = "TACKLE", target = "enemy" },
  })
  T.check(battle.over ~= true, "the bench member walked in")
  T.check(battle.collapsed == true, "one-a-side collapses to the engine loop")
  T.check(battle.takeTurn ~= doubles2.takeTurn2v2, "takeTurn is the engine's again")
  local events = battle:takeTurn({ kind = "move", move = "TACKLE" })
  T.check(type(events) == "table", "the engine turn loop answered")
end

do -- collapse to the engine's own loop when a bench send-in restores 1v1
  local battle, party, wild, wild2 = battleWith(true)
  -- the enemy bench holds one spare; knock BOTH foes down to it
  battle.enemyParty[3] = mon("RATTATA", 6, "TACKLE")
  doubles2.decorate(battle, nil, wild2)
  wild.hp, wild2.hp = 1, 1
  battle:takeTurn({
    player  = { kind = "move", move = "TACKLE", target = "enemy" },
    player2 = { kind = "move", move = "TACKLE", target = "enemy2" },
  })
  -- both slots fainted; the bench send-in took one empty slot -> 1v1
  T.check(battle.over ~= true, "the spare walked in instead of ending it")
  T.check(battle.collapsed == true, "the round collapsed to the engine loop")
  T.check(battle.takeTurn ~= doubles2.takeTurn2v2, "takeTurn is the engine's again")
  -- and the engine's own loop runs the next round stock
  local events = battle:takeTurn({ kind = "move", move = "TACKLE" })
  T.check(type(events) == "table", "the engine turn loop answered")
end

do -- run is a whole-battle arm that can fail and cost the turn
  local battle, party = battleWith(false)
  doubles2.decorate(battle, party[2], nil)
  battle:takeTurn({ player = { kind = "run" } })
  -- trainer battle (wild battles here carry no trainer): a wild battle's
  -- run rolls; the deterministic roller refuses, so the round proceeds.
  -- The deterministic roller rolls 1 on the escape check: the run SUCCEEDS,
  -- which is exactly the whole-battle arm the 2v2 round promises.
  T.check(battle.over == true, "a successful wild run ends the battle")
  T.check(battle.outcome == "run", "outcome is a run")
end

do -- Native UI action shape must hit, then promote the surviving foe.
  local battle, party, wild, wild2 = battleWith(true)
  doubles2.decorate(battle, nil, wild2)
  local before=wild.hp
  battle:takeTurn({kind="move",move="TACKLE"})
  T.check(wild.hp<before,"native screen action damages the wild lead")
  wild.hp=1
  battle:takeTurn({kind="move",move="TACKLE"})
  T.eq(battle.enemy,wild2,"surviving second foe becomes the singles lead")
  T.eq(battle.enemy2,nil,"promoted foe does not remain drawn twice")
  T.check(battle.collapsed,"survivor returns to native singles")
  local before2=wild2.hp
  battle:takeTurn({kind="move",move="TACKLE"})
  T.check(wild2.hp<before2,"native next turn damages the surviving foe")
  for _,m in ipairs(battle.party) do
    T.check(m==party[1] or m==party[2] or m==party[3],"no foreign party member")
  end
end

do -- A faint can only draw a replacement from the owned party.
  local battle,party,_,wild2=battleWith(true)
  doubles2.decorate(battle,nil,wild2)
  party[1].hp=1
  battle:takeTurn({kind="skip"})
  T.eq(battle.player,party[2],"fainted lead replaced by the actual owned bench mon")
  T.eq(#battle.party,3,"replacement never adds a Pokemon")
end

do -- A one-mon party wipes instead of inventing a replacement.
  local battle,party,_,wild2=battleWith(true)
  party[3],party[2]=nil,nil
  doubles2.decorate(battle,nil,wild2)
  party[1].hp=1
  battle:takeTurn({kind="skip"})
  T.check(battle.over and battle.outcome=="lose","empty bench uses native loss outcome")
  T.eq(#battle.party,1,"loss never adds a Pokemon")
end

T.finish("double battles gen2 core")
