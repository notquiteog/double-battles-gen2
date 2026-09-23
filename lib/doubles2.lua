-- Real 2v2 for Crystal: a layer over the engine's own Gen 2 battle sim.
--
-- The engine's Battle is singles-only: one active mon per side, the round
-- sequenced inside a local runTurn() we cannot reach.  What it DOES expose
-- is a method-level primitive set -- useMove(attacker, defender, moveId),
-- effectiveSpeed, movePriority, awardExperience, the per-mon residual
-- ticks -- all driven by self.  So instead of forking 5,484 lines of cart
-- mechanics, this file decorates the engine's own battle instance in place
-- (the way double_battles decorates Gen 1's BattleState) and adds the
-- pieces the engine cannot do:
--
--   * two actives per side (player2 / enemy2) with their own party indexes
--   * a four-actor round: non-move arms first, then moves ordered by the
--     engine's own priority + speed (Quick Claw included, ties by roll)
--   * targeting: each action names its defender; a fainted target falls
--     through to the side's other slot, then fails quietly
--   * per-attack faint handling that does NOT trigger the engine's 1v1
--     replacement machinery: the slot stays empty until the round ends
--   * end-of-round send-ins from the bench, and collapse: the moment both
--     sides stand exactly one mon, the engine's own takeTurn takes the
--     battle back (party rotation, catching, running -- all stock again)
--
-- Everything else -- damage, accuracy, crits, effects, items, weather,
-- experience curves -- IS the engine's code, running on the same battle
-- object the real battle stage renders.
--
-- What the core deliberately leaves to the layers above: the second HP
-- plates and sprite slots (presentation), the aim menu (UI), and where the
-- second combatants come from (startWildDouble / trainer 2v2 wiring).

local V = ...

local M = {}
M.__index = M

local Runtime = require("src.mods.Runtime")
local Strings = require("src.core.Strings")
local Battle, Effects
local function engine()
  if not Battle then
    Battle = require("src.battle.gen2.Battle")
    Effects = require("src.battle.gen2.Effects")
  end
  return Battle
end

local SLOTS = { "player", "player2", "enemy", "enemy2" }
local MIRROR_SLOTS = { "enemy", "enemy2", "player", "player2" }
local function slotOrder(battle)return battle.linkBattle and battle.mirrored and MIRROR_SLOTS or SLOTS end

-- Native effects index the two active lead contexts. Bind the relevant
-- slots while an action runs, including separate stages for each partner.
local function slotOf(b,mon)
 for _,key in ipairs(SLOTS)do if mon and b.doubles[key]==mon then return key end end
end
local function context(b,first,second,fn)
 local d=b.doubles
 local pk,ek='player','enemy'
 for _,key in ipairs({first or '',second or ''})do
  if key=='player'or key=='player2'then pk=key elseif key=='enemy'or key=='enemy2'then ek=key end
 end
 local op,oe=b.player,b.enemy
 local opk,oek=slotOf(b,op),slotOf(b,oe)
 local pi,ei=b.playerIndex,b.enemyIndex
 local ps,es=b.stages.player,b.stages.enemy
 local rewrite=d.rewrite
 b.player,b.enemy=d[pk],d[ek];b.playerIndex,b.enemyIndex=d.index[pk],d.index[ek]
 b.stages.player,b.stages.enemy=d.stages[pk],d.stages[ek]
 d.rewrite={player=pk,enemy=ek}
 local ok,result=pcall(fn)
 d[pk],d[ek]=b.player,b.enemy;d.index[pk],d.index[ek]=b.playerIndex,b.enemyIndex
 d.stages[pk],d.stages[ek]=b.stages.player,b.stages.enemy
 b.player2,b.enemy2=d.player2,d.enemy2
 b.player,b.enemy=opk and d[opk]or op,oek and d[oek]or oe
 b.playerIndex,b.enemyIndex=opk and d.index[opk]or pi,oek and d.index[oek]or ei
 b.stages.player,b.stages.enemy=opk and d.stages[opk]or ps,oek and d.stages[oek]or es
 b.stages.player2,b.stages.enemy2=d.stages.player2,d.stages.enemy2
 d.rewrite=rewrite
 if not ok then error(result,0)end
 return result
end

-- The engine's own lead fields are the source of truth for slot 1; call
-- after anything mutates them (switches, send-ins).
local function syncLeads(battle)
  local d = battle.doubles
  d.player, d.index.player = battle.player, battle.playerIndex
  d.enemy, d.index.enemy = battle.enemy, battle.enemyIndex
end

-- The four actives, alive ones only, in the layer's canonical slot order.
local function actives(battle)
  local d = battle.doubles
  local out = {}
  for _, slot in ipairs(slotOrder(battle)) do
    local mon = d[slot]
    if mon and (mon.hp or 0) > 0 then out[#out + 1] = { slot = slot, mon = mon } end
  end
  return out
end

local function livingCount(battle, side)
  local d = battle.doubles
  local n = 0
  for _, slot in ipairs({ side, side .. "2" }) do
    local mon = d[slot]
    if mon and (mon.hp or 0) > 0 then n = n + 1 end
  end
  return n
end

-- A side record shaped like Battle:sideRecord's, for the slot the engine
-- does not know about.  Same payload shape battler_switched carries.
local function slotSideRecord(battle, slot)
  local d = battle.doubles
  local sideKey = (slot == "player" or slot == "player2") and "player" or "enemy"
  local side
  for _, s in ipairs(battle.sides or {}) do
    if s.key == sideKey then side = s end
  end
  side = side or { index = sideKey == "player" and 1 or 2, key = sideKey }
  return {
    index = side.index, key = sideKey,
    slot = slot,
    battlers = { d[slot] },
    screens = side.screens or {},
    hazards = side.hazards or {},
    tokens = side.tokens or {},
  }
end

-- Faint a mid-round slot: the cart's doubles never send a replacement into
-- a round that already started, so the slot just goes empty until the
-- end-of-round send-in.  Experience and the faint events are the engine's
-- own, awarded here while the attacker context is still live.
local function announceFaint(battle, slot)
  local d = battle.doubles
  local mon = d[slot]
  if not mon or (mon.hp or 0) > 0 or d.fainted[slot] then return end
  d.fainted[slot] = true
  local wildText = (slot == "enemy" or slot == "enemy2")
  local template = wildText
    and Strings.source("Wild %s fainted!")
    or Strings.source("%s fainted!")
  battle:emit({ kind = "faint", side = slot,
    text = Strings(template, battle:monName(mon)) })
  Runtime.emit("battle.fainted", { battle = battle, battler = mon,
    side = slotSideRecord(battle, slot) })
  if wildText and not battle.linkBattle then battle:awardExperience(mon)
  elseif not wildText and not battle.linkBattle then battle:faintHappiness(mon) end
end

-- Every actor on `side` is down and no bench member stands ready: the
-- battle ends here, with the cart's own win/loss plumbing.
local function checkSideWipe(battle, side)
  local d = battle.doubles
  if livingCount(battle, side) > 0 then return false end
  local bench
  if side == "player" then
    bench = battle.party
  else
    bench = battle.enemyParty or {}
  end
  local nextIndex = Battle.firstHealthy(bench)
  -- Someone is waiting: NOT a wipe.  The end-of-round send-in moves them up.
  if nextIndex then
    -- A fainted mon must not still sit in the party slot the rotation reads.
    return false
  end
  if side == "player" then
    battle:endBattle("lose")
  else
    battle:emit({ kind = "message",
      text = Strings("%s was defeated!", battle.trainer and battle.trainer.name or "Foe") })
    if battle.trainer and not battle.linkBattle then
      battle:printWinLossText("win")
      battle:awardPrizeMoney()
    end
    local Prize = require("src.battle.gen2.Prize")
    local coins = not battle.linkBattle and Prize.payDay(battle.save, battle.payDay, battle.amuletCoin)
    battle.payDay = nil
    battle:endBattle("win")
  end
  return true
end

-- Mid-round faint sweep: announce, pay out, end the battle if a side is
-- wiped with no bench.  Returns true when the battle ended.
local function sweepFaints(battle)
  for _, slot in ipairs(slotOrder(battle)) do announceFaint(battle, slot) end
  if checkSideWipe(battle, "enemy") then return true end
  return checkSideWipe(battle, "player")
end

-- The attack arm, shared by all four slots.  Everything up to useMove is
-- runTurn's own pre-move plumbing, generalised from the player/enemy pair
-- to any attacker; what differs for the player slots is the obedience roll,
-- which the cart runs for the player's LEAD only in a singles round.  A
-- partner here obeys the same check as the lead on the player side and is
-- skipped on the enemy side, matching enemyAttack().
local function attack(battle, actor, defender)
  local mon, move = actor.mon, actor.move
  local d = battle.doubles
  local forced = battle:forcedMove(mon)
  if forced then move = forced end
  local stored = battle:volatile(mon).chargeMove
  if stored then move = stored end
  if not battle:canAct(mon, move) then return end
  local charging = battle:volatile(mon).chargeMove == move
    or battle:lockedInMove(mon) == move
  local bideLocked = battle:fightLockedMove(mon) == move
  if not charging and not bideLocked and not battle:hasUsableMoves(mon) then
    battle:emit({ kind = "message",
      text = Strings("%s has no moves left!", battle:monName(mon)) })
    move = Battle.STRUGGLE
  end
  if battle:moveDisabled(mon, move) then
    local state = battle:volatile(mon)
    state.chargeMove, state.vanished = nil, nil
    local moveDef = battle:moveDef(move)
    local moveName = (moveDef and moveDef.name) or move or "?"
    battle:emit({ kind = "message",
      text = Strings("%s's %s is DISABLED!", battle:monName(mon), moveName) })
    return
  end
  if not battle.linkBattle and (actor.slot == "player" or actor.slot == "player2") then
    -- CheckObedience: the cart runs it at the head of the move's effect
    -- list for the player's side.  The lead's roll is the engine's own
    -- (it reads the battle's player context); a partner rolls through the
    -- same gate by temporarily standing in that context.
    local lead, leadIndex = battle.player, battle.playerIndex
    local wasParticipants = battle.participants
    battle.player, battle.playerIndex = mon, d.index[actor.slot]
    local interrupted = battle:checkObedience(move)
    battle.player, battle.playerIndex = lead, leadIndex
    battle.participants = wasParticipants
    if interrupted then return end
  end
  battle:useMove(mon, defender, move)
end

-- Resolve an action's defender at the moment it fires: a named target that
-- fainted earlier in the round falls through to the side's other standing
-- slot; nothing standing means the move fails quietly.
local function defenderFor(battle, actor, targetSlot)
  local d = battle.doubles
  local side = (actor.slot == "player" or actor.slot == "player2")
    and "enemy" or "player"
  local other=side.."2"
  local order = targetSlot==other and {other,side} or {side,other}
  for _, slot in ipairs(order) do
    local mon = d[slot]
    if mon and (mon.hp or 0) > 0 then return mon, slot end
  end
  return nil
end

-- End-of-round: bench members walk into empty slots (the cart's own send
-- shape, emitted on the slot's side key), and a 2v2 that has become 1v1
-- hands the battle back to the engine's own turn loop.
local function sendInsAndCollapse(battle)
  local d = battle.doubles
  local sides=battle.linkBattle and battle.mirrored and {"enemy","player"} or {"player","enemy"}
  for _, side in ipairs(sides) do
    local paired = side == "enemy" and d.enemyOwner ~= nil
    local desired = side == "player" and d.solo and 1 or 2
    if livingCount(battle, side) < ((battle.linkBattle or paired) and desired or 1) and not battle.over then
      local bench = side == "player" and battle.party or (battle.enemyParty or {})
      local used = {}
      for _, slot in ipairs(slotOrder(battle)) do if d[slot] then used[d[slot]] = true end end
      for _, emptySlot in ipairs({side, side .. "2"}) do
        local cur = d[emptySlot]
        if not (cur and (cur.hp or 0)>0) and not (desired==1 and emptySlot==side.."2") then
          local nextIndex
          for i, mon in ipairs(bench) do
            if (mon.hp or 0)>0 and not used[mon] and not mon.isEgg
                and (not paired or d.enemyOwner[i]==emptySlot) then nextIndex=i;break end
          end
          if nextIndex then
            local mon = bench[nextIndex]
            d[emptySlot], battle[emptySlot] = mon, mon
            d.stages[emptySlot]=Battle.newStages()
            battle.stages[emptySlot]=d.stages[emptySlot]
            d.fainted[emptySlot]=nil;d.index[emptySlot]=nextIndex
            if emptySlot==side then battle[side.."Index"]=nextIndex end
            battle:emit({kind="send",side=emptySlot,mon=mon,replacement=true,
              hp=mon.hp or 0,status=mon.status or false,level=mon.level,experience=mon.experience,
              text=Battle.sentOutText(battle.trainer and battle.trainer.name or "Foe",battle:monName(mon))})
            Runtime.emit("battle.battler_switched",{battle=battle,side=slotSideRecord(battle,emptySlot),battler=mon})
            syncLeads(battle);used[mon]=true
            if not (battle.linkBattle or paired) then break end
          end
        end
      end
    end
  end
  -- Native menu entry expects a healthy primary ally. If its partner is
  -- the only active survivor, promote it before handing input back.
  if not battle.linkBattle and not (d.player and d.player.hp>0) and d.player2 and d.player2.hp>0 then
    d.player,d.player2=d.player2,d.player
    d.index.player,d.index.player2=d.index.player2,d.index.player
    d.stages.player,d.stages.player2=d.stages.player2,d.stages.player
    d.fainted.player,d.fainted.player2=d.fainted.player2,d.fainted.player
    battle.player,battle.player2=d.player,d.player2;battle.playerIndex=d.index.player
    battle.stages.player,battle.stages.player2=d.stages.player,d.stages.player2
    battle:emit({kind="send",side="player",mon=battle.player,replacement=true,
      hp=battle.player.hp,status=battle.player.status or false,level=battle.player.level,
      text=Strings("%s steps forward!",battle:monName(battle.player))})
  end
  -- Collapse: one standing mon a side, both sides -- the engine's own 1v1
  -- turn loop takes over from here, party rotation and all.
  if not battle.linkBattle and not d.enemyOwner and livingCount(battle, "player") == 1 and livingCount(battle, "enemy") == 1 then
    if battle.doubles.takeTurn then
      -- Singles must inherit the SURVIVOR, not a fainted lead whose partner
      -- is still hidden in slot 2. Keep references to the actual party mons.
      for _,side in ipairs({"player","enemy"}) do
        if not (d[side] and d[side].hp>0) then
          battle[side],battle[side.."Index"]=d[side.."2"],d.index[side.."2"]
          local mon=battle[side]
          battle:emit({kind="send",side=side,mon=mon,replacement=true,
            hp=mon.hp,status=mon.status or false,level=mon.level,
            experience=mon.experience,text=Strings("%s steps forward!",battle:monName(mon))})
        end
        battle[side.."2"],d[side.."2"]=nil,nil
      end
      syncLeads(battle)
      battle:syncSides()
      battle.isDoubleBattle=false
      battle.takeTurn = battle.doubles.engineTakeTurn
      battle.doubles.takeTurn = nil
      battle.collapsed = true
      Runtime.emit("battle.doubles_collapsed", { battle = battle })
    end
  end
end

-- The four-actor round.  `actions` = { player=?, player2=?, enemy=?, enemy2=? }
-- with each a runTurn action table ({kind="move", move=, target=} |
-- {kind="switch", index=} | {kind="skip"}); a slot's nil action is a skip.
function M.takeTurn2v2(self, actions)
  actions = actions or {}
  -- BattleState submits the native singles action shape. Explicit four-slot
  -- callers remain supported, but a UI move must never become a silent skip.
  if actions.kind then actions={player=actions} end
  if self.over then return self:takeEvents() end
  local d = self.doubles
  syncLeads(self)
  self.turn = self.turn + 1

  local okB, BattleE = pcall(engine)
  local BattleLocal = BattleE or Battle

  -- BerserkGene, player slots then enemy slots, first turn out only.
  for _, slot in ipairs(slotOrder(self)) do
    local mon = d[slot]
    if mon then self:checkBerserkGene(mon) end
  end
  for _, slot in ipairs(slotOrder(self)) do
    local mon = d[slot]
    if mon then self:volatile(mon).tookThisTurn = nil end
  end
  self.faintInterrupt = nil

  -- Non-move arms first: switches and items resolve before any move, in
  -- slot order (the cart's own "switch resolves first" rule, generalised).
  local moveActions = {}
  for _, slot in ipairs(slotOrder(self)) do
    local act = actions[slot]
    local mon = d[slot]
    if not mon or (mon.hp or 0) <= 0 then
      -- an empty slot's action is dropped
      act = nil
    end
    if act == nil and mon and (mon.hp or 0) > 0
        and (slot == "enemy" or slot == "enemy2") then
      -- no collected action for a standing foe slot: the AI picks, exactly
      -- as the singles round does when the caller hands only the player
      -- action.  An EMPTY slot still skips -- there is nobody to choose.
      act = { kind = "move" }
    end
    act = act or { kind = "skip" }
    if act.kind == "switch" then
      if slot == "player" then
        self:switch(tonumber(act.index) or 0)
        syncLeads(self)
      elseif slot == "enemy" then
        self:switchEnemy(tonumber(act.index) or 0)
        syncLeads(self)
      elseif slot == "player2" or slot == "enemy2" then
        -- Slot switch: stand the slot's mon in the engine's lead context,
        -- run the engine's own switch primitive, read the replacement back.
        local side = slot == "player2" and "player" or "enemy"
        local lead = side == "player" and self.player or self.enemy
        local leadIndex = side == "player" and self.playerIndex or self.enemyIndex
        if side == "player" then
          self.player, self.playerIndex = d[slot], d.index[slot]
        else
          self.enemy, self.enemyIndex = d[slot], d.index[slot]
        end
        if side == "player" then
          self:switch(tonumber(act.index) or 0)
          d[slot], d.index[slot] = self.player, self.playerIndex
        else
          self:switchEnemy(tonumber(act.index) or 0)
          d[slot], d.index[slot] = self.enemy, self.enemyIndex
        end
        self[side .. "2"] = d[slot]
        if side == "player" then
          self.player, self.playerIndex = lead, leadIndex
        else
          self.enemy, self.enemyIndex = lead, leadIndex
        end
        Runtime.emit("battle.battler_switched", { battle = self,
          side = slotSideRecord(self, slot), battler = d[slot] })
        syncLeads(self)
      end
    elseif act.kind == "item" then
      -- X-item happiness lands on whoever is out (runTurn's tail); the
      -- item's own effect is the caller's to apply, exactly as in 1v1.
      if slot == "player" or slot == "player2" then
        self:cancelBide(d[slot])
      end
      moveActions[#moveActions + 1] = { slot = slot, mon = mon, act = act,
        kind = "skip" }
    elseif act.kind == "move" then
      moveActions[#moveActions + 1] = { slot = slot, mon = mon, act = act,
        kind = "move", move = act.move, target = act.target }
    else
      moveActions[#moveActions + 1] = { slot = slot, mon = mon, act = act,
        kind = "skip" }
    end
  end

  if Runtime.wants("battle.turn_started") then
    Runtime.emit("battle.turn_started", { battle = self, turn = self.turn,
      doubles = true, actions = actions })
  end
  self.turnOpen = true

  -- RUN: a whole-battle arm.  Only meaningful against wild foes; the failed
  -- roll costs the turn exactly as the singles round does.
  if (actions.player and actions.player.kind == "run") then
    if self:tryRun() then return self:takeEvents() end
    if self.runRefused then return self:takeEvents() end
    -- the run consumed the player lead's action: drop it from the order
    for i, ma in ipairs(moveActions) do
      if ma.slot == "player" then ma.kind = "skip" end
    end
  end

  -- Enemy move choice through the engine's own AI, one slot at a time: the
  -- AI reads its attacker and the opposing lead off the battle, so each
  -- enemy slot stands in that context while its move is picked.
  for _, ma in ipairs(moveActions) do
    if ma.kind == "move" and ma.mon and (ma.mon.hp or 0) > 0
        and (ma.slot == "enemy" or ma.slot == "enemy2") and not ma.move then
      local side, lead, leadIndex = "enemy", self.enemy, self.enemyIndex
      self.enemy, self.enemyIndex = ma.mon, d.index[ma.slot]
      -- The opposing lead the AI measures against: the player side's lead.
      ma.move = self:enemyMove()
      self.enemy, self.enemyIndex = lead, leadIndex
    end
  end

  -- Order the moves: the engine's own priority, then effective speed, then
  -- the same random tie the cart rolls.  The tie is rolled ONCE per actor
  -- before the sort -- a comparator that rolls twice is not an order.
  for i, ma in ipairs(moveActions) do
    ma.tie = self:roller()(2);ma.order=i
    ma.priority=ma.kind=="move" and self:movePriority(ma.move) or 0;ma.speed=ma.mon and self:effectiveSpeed(ma.mon) or 0
  end
  table.sort(moveActions, function(a, b)
    if a.kind ~= b.kind then return a.kind == "move" end
    if a.kind ~= "move" then return a.slot < b.slot end
    local pa, pb = a.priority, b.priority
    if pa ~= pb then return pa > pb end
    local sa, sb = a.speed, b.speed
    if sa ~= sb then return sa > sb end
    if a.tie ~= b.tie then return a.tie < b.tie end
    return a.order < b.order
  end)

  -- The attack phase.  A fainted attacker is skipped; the battle ending
  -- (flee, wipe) stops the phase where it stands.
  for _, ma in ipairs(moveActions) do
    if self.over then break end
    if ma.kind == "move" and ma.mon and (ma.mon.hp or 0) > 0 then
      local defender, defSlot = defenderFor(self, ma, ma.target)
      if defender then
        if sweepFaints(self) then return self:takeEvents() end
        context(self,ma.slot,defSlot,function()return attack(self,ma,defender)end)
        if self.over then break end
        if sweepFaints(self) then return self:takeEvents() end
      end
    end
  end
  if self.over then return self:takeEvents() end

  -- End-of-round, in the cart's own order, per standing mon: weather once,
  -- then status, seed/curse, wrap, held item, Future Sight, Perish, then
  -- screens and counters.
  self:tickWeather()
  local d = self.doubles
  local standing = actives(self)
  for _, a in ipairs(standing) do
    d.rewrite = (a.slot == "player2" and { player = "player2" })
      or (a.slot == "enemy2" and { enemy = "enemy2" }) or nil
    context(self,a.slot,nil,function()
    self:tickStatus(a.mon)
    self:tickSeedAndCurse(a.mon)
    self:tickWrap(a.mon)
    self:tickHeldItem(a.mon)
    self:tickFutureSight(a.mon)
    self:tickPerish(a.mon)
    end)
  end
  d.rewrite = nil
  self:tickScreens()
  for _, a in ipairs(standing) do
    d.rewrite = (a.slot == "player2" and { player = "player2" })
      or (a.slot == "enemy2" and { enemy = "enemy2" }) or nil
    context(self,a.slot,nil,function()self:tickCounters(a.mon)end)
  end
  d.rewrite = nil
  if sweepFaints(self) then return self:takeEvents() end
  sendInsAndCollapse(self)
  return self:takeEvents()
end

-- Decorate an engine battle in place.  secondPlayer: a party mon (nil keeps
-- the player side 1v1); secondEnemy: a mon for the foe's second slot.
-- The second slots' party indexes are remembered so switches and the AI
-- context swaps can restore the leads exactly.
function M.decorate(battle, secondPlayer, secondEnemy, options)
  engine()
  local d = {
    index = {},
    fainted = {},
    engineTakeTurn = battle.takeTurn,
    solo = options and options.solo or false,
  }
  battle.doubles = d
  d.stages={player=battle.stages.player,enemy=battle.stages.enemy,player2=Battle.newStages(),enemy2=Battle.newStages()}
  battle.stages.player2,battle.stages.enemy2=d.stages.player2,d.stages.enemy2
  d.player, d.index.player = battle.player, battle.playerIndex
  d.enemy, d.index.enemy = battle.enemy, battle.enemyIndex
  d.player2 = secondPlayer
  d.enemy2 = secondEnemy
  -- The engine screen's activeMon(side) reads battle[side], so the second
  -- slots live here too: the staged-battle textures and any plate wrap
  -- resolve their mon through that seam without touching the screen.
  battle.player2 = secondPlayer
  battle.enemy2 = secondEnemy
  if secondPlayer then
    for i, mon in ipairs(battle.party or {}) do
      if mon == secondPlayer then d.index.player2 = i end
    end
    d.index.player2 = d.index.player2 or 2
  end
  if secondEnemy then
    for i, mon in ipairs(battle.enemyParty or {}) do
      if mon == secondEnemy then d.index.enemy2 = i end
    end
    d.index.enemy2 = d.index.enemy2 or 2
  end
  battle.takeTurn = M.takeTurn2v2
  battle.doubles.takeTurn = M.takeTurn2v2
  battle.isDoubleBattle = true
  if secondPlayer then
    battle.participants[d.index.player2] = true
  end
  -- Slot context for events: while a slot-2 mon is the attacker or the
  -- defender, events the engine stamps with the lead's side key are
  -- rewritten to the slot's own key, so damage/heal/status land on the
  -- right battler for anything consuming the event stream (the flat
  -- screen today, the doubled HUD later).
  local d2 = battle.doubles
  local engineEmit = battle.emit
  -- While a slot-2 mon is on either end of an effect, events the engine
  -- stamps with the lead's side key are rewritten to the slot's own key.
  d2.rewrite = nil
  battle.emit = function(self, event)
    local rw = d2.rewrite
    if rw and event and rw[event.side] then event.side = rw[event.side] end
    return engineEmit(self, event)
  end
  local engineUseMove = battle.useMove
  battle.useMove = function(self, attacker, defender, moveId)
    return context(self,slotOf(self,attacker),slotOf(self,defender),function()
      return engineUseMove(self,attacker,defender,moveId)
    end)
  end
  local engineSpeed=battle.effectiveSpeed
  battle.effectiveSpeed=function(self,mon)
    return context(self,slotOf(self,mon),nil,function()return engineSpeed(self,mon)end)
  end
  Runtime.emit("battle.doubles_started", { battle = battle,
    player2 = secondPlayer, enemy2 = secondEnemy })
  return battle
end

-- Is this battle currently running the layer's own rounds?
function M.isActive(battle)
  return battle and battle.doubles and battle.doubles.takeTurn ~= nil
end

return M
