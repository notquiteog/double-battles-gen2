-- Gen2's visible trainer objects supply the same adjacent-pair convention as
-- Gen1. Each trainer keeps a detached roster, reward, and native defeat flag.
return function(mod,sources)
 local Trainers=require('src.world.gen2.Trainers')
 local Prize=require('src.battle.gen2.Prize')
 local excluded={}
 for id in ('FALKNER BUGSY WHITNEY MORTY CHUCK JASMINE PRYCE CLAIR BROCK MISTY LT_SURGE ERIKA JANINE SABRINA BLAINE BLUE WILL KOGA BRUNO KAREN CHAMPION RED RIVAL1 RIVAL2 CAL EXECUTIVEM EXECUTIVEF MYSTICALMAN'):gmatch('%S+')do excluded[id]=true end
 local function plain(t)return t and not excluded[t.classId]and not t.story and not t.doubleBattle and t.party and #t.party>0 end
 local function copy(t)local c={};for k,v in pairs(t or{})do c[k]=v end;return c end
 local M={}
 function M.combine(world,opts)
  local lead=opts.trainer
  if not mod.options:get('gen2_doubles')or not plain(lead)or opts.battleTower or opts.battleType or opts.tutorial then return opts end
  local second,record
  for _,source in ipairs(sources or{})do
   local ok,cls,member=pcall(source.provide,world.game,{kind='trainer',generation=2,trainer=lead,oppClass=lead.class,partyIndex=lead.memberId})
   if ok and cls and member then
    local row=world:trainerParty(cls,member)
    if row then second=copy(row);second.party=Trainers.party(world.game.data,row);if plain(second)then break else second=nil end end
   end
  end
  if not second and mod.options:get('trainer_pairs')then
   local engaged=world.trainerNpc or world.talkNpc
   local er=engaged and engaged.def and engaged.def.trainer
   local engagedRecord=er and world:trainerParty(er.class,er.member)
   if not(er and er.class==lead.class and engagedRecord and engagedRecord.id==lead.memberId)then return opts end
   local distance=tonumber(mod.options:get('pair_distance'))or 1
   for _,npc in ipairs(world.npcs or{})do
    local r=npc.def and npc.def.trainer
    if npc~=engaged and r and r.event and not npc.hiddenByMovement and not world:trainerBeaten(r)and not world:trainerRefused(r)
     and math.abs((npc.cellX or 99)-(engaged.cellX or 0))<=distance and math.abs((npc.cellY or 99)-(engaged.cellY or 0))<=distance then
     local row=world:trainerParty(r.class,r.member)
     if row then
      local candidate=copy(row);candidate.party=Trainers.party(world.game.data,row)
      if plain(candidate)then second,record=candidate,r;break end
     end
    end
   end
  end
  if not second then return opts end
  local combined=copy(lead);combined.party={};local owner={}
  local function add(mon,slot)combined.party[#combined.party+1]=mon;owner[#combined.party]=slot end
  add(lead.party[1],'enemy');add(second.party[1],'enemy2')
  for i=2,#lead.party do add(lead.party[i],'enemy')end
  for i=2,#second.party do add(second.party[i],'enemy2')end
  combined.name=(lead.name or'TRAINER')..' & '..(second.name or'TRAINER')
  local out=copy(opts);out.trainer=combined
  local info={owner=owner,classA=lead.class,classB=second.class,partyIndexB=second.member,record=record,
   rewards={{baseMoney=lead.baseMoney,level=Prize.rewardLevel(lead.party)},{baseMoney=second.baseMoney,level=Prize.rewardLevel(second.party)}}}
  return out,info
 end
 function M.decorate(battle,info)
  battle.__dbPairInfo=info
  battle.doubles.enemyOwner=info.owner
  battle.awardPrizeMoney=function(self)
   if info.paid then return self.prize end
   info.paid=true
   for _,reward in ipairs(info.rewards)do
    local award=Prize.award(self.save,{baseMoney=reward.baseMoney,level=reward.level,amuletCoin=self.amuletCoin})
    self.prize=award;self:emit({kind='money',award=award,text=Prize.message(award,self.save.player and self.save.player.name)})
   end
   return self.prize
  end
 end
 function M.finish(world,info,result)
  if info and result=='win'and info.record and info.record.event then world.events:set(info.record.event,true)end
 end
 return M
end
