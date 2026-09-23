-- Only ordinary, unbeaten adjacent map trainers can pair automatically.
-- The two rosters remain detached from imported trainer data and keep their
-- own replacement pools; both native defeat flags are recorded on victory.
return function(mod,sources)
 local Sight=require('src.core.game3.trainer_sight')
 local Objects=require('src.core.game3.objects')
 local Trainers=require('src.core.game3.scripting.trainers')
 local Space=require('src.core.game3.scripting.space')
 local Flags=require('src.core.game3.scripting.flags')
 local Runtime=require('src.core.game3.runtime')
 local Prize=require('src.core.game3.battle.prize')
 local function copy(t)local c={};for k,v in pairs(t or{})do c[k]=v end;return c end
 local special={[84]=true,[87]=true,[97]=true,[81]=true,[89]=true,[90]=true,[24]=true,[23]=true,[30]=true}
 local function plain(foe)
  return foe and not special[tonumber(foe.trainerClass)]and not foe.doubleBattle and type(foe.party)=='table'and #foe.party>0
 end
 local function adjacent(foe)
  if not mod.options:get('trainer_pairs')or not plain(foe)then return end
  local engaged
  for _,npc in ipairs(Objects.forDraw()or{})do if Sight.getTrainerId(npc)==foe.trainerId then engaged=npc;break end end
  if not engaged or Sight.battleType(engaged)~=0 then return end
  local distance=tonumber(mod.options:get('pair_distance'))or 1
  for _,npc in ipairs(Objects.forDraw()or{})do
   if npc~=engaged and Sight.isTrainerType(npc)and Sight.battleType(npc)==0 and not Sight.isDefeated(npc,Space.store,nil)
    and math.abs((npc.cellX or 99)-(engaged.cellX or 0))<=distance
    and math.abs((npc.cellY or 99)-(engaged.cellY or 0))<=distance then
    local tid=Sight.getTrainerId(npc);local second=tid and Trainers.foeFromId(tid)
    if tid~=foe.trainerId and plain(second)then return second,tid end
   end
  end
 end
 local M={}
 local award=Prize.awardTrainerWin
 Prize.awardTrainerWin=function(session,id,opts)
  local Battle=require('src.core.game3.battle');local st=Battle.getState()
  local info=st and st.__dbPairInfo
  if info and id==info.trainerA then
   opts=copy(opts);opts.double=false;info.moneyMultiplier=opts.moneyMultiplier
  end
  return award(session,id,opts)
 end
 function M.combine(g,foe,opts)
  if not plain(foe)or opts.earlyRival or opts.trainerTower or opts.eReader then return end
  local second,tid
  for _,source in ipairs(sources)do
   local ok,id=pcall(source.provide,g,{kind='trainer',generation=3,trainerId=foe.trainerId,foe=foe})
   if ok and tonumber(id)then second=Trainers.foeFromId(id);tid=tonumber(id);if plain(second)then break else second=nil end end
  end
  if not second then second,tid=adjacent(foe)end
  if not second then return end
  local combined=copy(foe);combined.party={};local owner={}
  local function add(mon,id)combined.party[#combined.party+1]=copy(mon);owner[#combined.party]=id end
  add(foe.party[1],1);add(second.party[1],3)
  for i=2,#foe.party do add(foe.party[i],1)end
  for i=2,#second.party do add(second.party[i],3)end
  combined.trainerName=(foe.trainerName or'TRAINER')..' & '..(second.trainerName or'TRAINER')
  return combined,{classA=foe.trainerClass,classB=second.trainerClass,partyIndexB=tid,trainerA=foe.trainerId,trainerB=tid,owner=owner}
 end
 function M.finish(info,result)
  if result~='win'or info.recorded then return end
  info.recorded=true;Flags.setFlag(Space.store,nil,Flags.trainerFlagId(info.trainerB),true)
  local session=Runtime.getSession();if session then Prize.awardTrainerWin(session,info.trainerB,{double=false,moneyMultiplier=info.moneyMultiplier})end
 end
 return M
end
