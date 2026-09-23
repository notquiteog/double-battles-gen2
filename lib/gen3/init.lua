-- Native Gen3 doubles extension. Native state, four-battler turn ordering,
-- move effects, switching, catch storage and battle writeback remain owners.
return function(mod)
 local function part(p)return assert((loadstring or load)(assert(mod:read(p)),'@doubles/'..p))()end
 local Bridge=require('src.core.game3.battle_bridge')
 local Battle=require('src.core.game3.battle')
 local State=require('src.core.game3.battle.state')
 local Engine=require('src.core.game3.battle.engine')
 local Party=require('src.core.game3.party')
 local Runtime=require('src.core.game3.runtime')
 local Encounters=require('src.core.game3.encounters')
 local Pokemon=require('src.core.game3.pokemon')
 local Rng=require('src.core.game3.rng')
 local oldTrainer=mod.options:get('gen3_trainer_doubles')
 local schema={
  {key='modern_hud',label='MODERN BATTLE UI',type='toggle',default=true},
  {key='wild_doubles',label='WILD DOUBLES',type='choice',default='sometimes',choices={{'OFF','off'},{'SOMETIMES','sometimes'},{'ALWAYS','always'}}},
  {key='your_side',label='YOUR SIDE',type='choice',default='pair',choices={{'PAIR','pair'},{'SOLO','solo'}}},
  {key='trainer_doubles',label='TRAINER 2V2',type='toggle',default=oldTrainer~=false},
  {key='trainer_pairs',label='TRAINER PAIRS',type='toggle',default=true},
  {key='pair_distance',label='PAIR DISTANCE',type='choice',default=1,choices={{'TOUCHING',1},{'2 CELLS',2},{'3 CELLS',3}}},
  {key='double_exp',label='DOUBLES EXP',type='choice',default='full',choices={{'FULL','full'},{'HALF','half'}}},
  {key='online_doubles',label='ONLINE DOUBLES',type='toggle',default=true},
 }
 mod.options:define(schema)
 part('lib/InGameOptions.lua').install(mod,schema,'DOUBLE BATTLES')
 local function opt(k)return mod.options:get(k)end
 local function copy(t)local out={};for k,v in pairs(t or{})do out[k]=v end;return out end
 local function usable(m)return m and not m.isEgg and not m.egg and(tonumber(m.hp)or 1)>0 end
 local function healthyCount(p)local n=0;for _,m in ipairs(p or{})do if usable(m)then n=n+1 end end;return n end
 local sources,pairSources,vetoes={},{},{}
 local function register(list,s)
  if type(s)~='table'or s.id==nil or type(s.provide)~='function'then return false,'source with id and provide required'end
  for i=#list,1,-1 do if list[i].id==s.id then table.remove(list,i)end end
  local entry=copy(s);entry.priority=tonumber(s.priority)or 75;list[#list+1]=entry
  table.sort(list,function(a,b)return a.priority<b.priority end);return true
 end
 local function unregister(list,id)for i=#list,1,-1 do if list[i].id==id then table.remove(list,i);return true end end;return false end
 mod.exports.registerPartnerSource=function(s)return register(sources,s)end
 mod.exports.unregisterPartnerSource=function(id)return unregister(sources,id)end
 mod.exports.registerDoubleVeto=function(v)
  if type(v)~='table'or v.id==nil or type(v.veto)~='function'then return false,'veto with id and veto required'end
  unregister(vetoes,v.id);vetoes[#vetoes+1]=copy(v);return true
 end
 mod.exports.unregisterDoubleVeto=function(id)return unregister(vetoes,id)end
 local function vetoed(g,foe)
  for _,v in ipairs(vetoes)do local ok,hit=pcall(v.veto,g,{kind='wild',generation=3,enemy={mon=foe}});if ok and hit then return true end end
 end
 mod.exports.registerTrainerPairSource=function(s)return register(pairSources,s)end
 mod.exports.unregisterTrainerPairSource=function(id)return unregister(pairSources,id)end
 local function partner(g,foe,context)
  for _,source in ipairs(sources)do
   local ok,sp,lv=pcall(source.provide,g,{kind='wild',enemy={mon=foe},generation=3})
   if ok and sp then
    if type(sp)=='string'then sp=Pokemon.speciesFromName(sp)end
    if tonumber(sp)then return {species=sp,level=math.max(2,math.min(100,tonumber(lv)or foe.level or 5))}end
   end
  end
  if context.requirePartnerSource then return nil end
  local t=Encounters.tableFor(context.map);local a=t and(context.terrain=='water'and t.water or t.land or t.grass)
  local slots=a and(a.slots or a.mons or a)
  if slots and #slots>0 then
   local weights=context.terrain=='water'and{60,30,5,4,1}or{20,20,10,10,10,10,5,5,4,4,1,1}
   local sum=0;for i in ipairs(slots)do sum=sum+(weights[i]or 1)end
   local roll=Rng.Random()%sum;local row=slots[#slots]
   for i,v in ipairs(slots)do roll=roll-(weights[i]or 1);if roll<0 then row=v;break end end
   local lo=tonumber(row.minLevel or row.level or row[2])or 2;local hi=tonumber(row.maxLevel or row.level or row[2])or lo
   if hi<lo then lo,hi=hi,lo end
   return {species=row.species or row[1],level=lo+Rng.Random()%(hi-lo+1),item=row.item}
  end
  return {species=foe.species,level=foe.level or 5}
 end
 -- Object-identity provenance scopes automatic wild doubles to a real native
 -- step encounter. Fishing, scripts and visible spawns never inherit a stale
 -- grass tag just because they share a species or map.
 local randomEncounter=setmetatable({},{__mode='k'})
 mod.exports.tagOrganic=function(encounter,context)
  if type(encounter)~='table'then return false,'native encounter table required'end
  local ctx=copy(context);ctx.requirePartnerSource=ctx.requirePartnerSource~=false
  randomEncounter[encounter]=ctx;return true
 end
 local onStep=Encounters.onStep
 Encounters.onStep=function(map,terrain,opts,...)
  local enc=onStep(map,terrain,opts,...)
  if not terrain and opts and opts.x and opts.y and Encounters.terrainAt then terrain=Encounters.terrainAt(opts.x,opts.y)end
  if type(enc)=='table'then randomEncounter[enc]={map=map,terrain=terrain}end
  return enc
 end
 local pairs=part('lib/gen3/pairs.lua')(mod,pairSources)
 local start=Bridge.start
 Bridge.start=function(nativeMod,g,foe,opts)
  opts=opts or{};local session=Runtime.getSession()
  if opts.link or(foe and foe.link)or not session then return start(nativeMod,g,foe,opts)end
  local request
  if opts.wild then
   local context=randomEncounter[foe];randomEncounter[foe]=nil
   if context and not vetoed(g,foe)and not(opts.safari or opts.legendary or opts.roamer or opts.wildScripted or opts.firstBattle or opts.oldManTutorial)
    and not(foe.safari or foe.legendary or foe.roamer or foe.wildScripted)
    and not(session.safari and session.safari.active)then
    local chance=opt('wild_doubles')=='always'and 100 or opt('wild_doubles')=='sometimes'and 30 or 0
    if chance>0 and(chance==100 or Rng.Random()%100<chance)then
     local second=partner(g,foe,context)
     if second and second.species then
      local lead=copy(foe);foe=copy(foe);foe.party={lead,second};request={wild=true,solo=opt('your_side')=='solo'}
     end
    end
   end
  elseif type(foe)=='table'and type(foe.party)=='table'and not foe.doubleBattle then
   local combined,info=pairs.combine(g,foe,opts)
   if combined then foe=combined;request={pair=info,solo=opt('your_side')=='solo'}
   elseif opt('trainer_doubles')and healthyCount(foe.party)>=2 then request={solo=opt('your_side')=='solo'}end
  end
  if request then
   -- A mod-owned marker on a detached descriptor travels through the native
   -- delayed transition. No engine-global double or wild flag is toggled.
   foe=copy(foe);foe.__doubleBattles=request
   opts=copy(opts)
   local done=opts.done
   opts.done=function(result)if request.pair then pairs.finish(request.pair,result)end;if done then return done(result)end end
  end
  return start(nativeMod,g,foe,opts)
 end
 local requests=setmetatable({},{__mode='k'})
 local battleStart=Battle.start
 Battle.start=function(opts)
  local request=opts and opts.foe and opts.foe.__doubleBattles
  if not request or opts.link then return battleStart(opts)end
  local party=opts.playerParty;requests[party]=request
  local result={pcall(battleStart,opts)};requests[party]=nil
  if not result[1]then error(result[2],0)end
  return unpack(result,2)
 end
 mod.events:on('battle.started',function(ev)
  if ev and ev.battle and ev.battle.__doubleBattles then ev.double=true end
 end)
 local new=State.new
 State.new=function(opts)
  local request=opts and requests[opts.playerParty]
  if not request then return new(opts)end
  local args=copy(opts);args.double=true;if request.solo then args.partnerIndex=0 end
  local st=new(args);st.__doubleBattles=request;st.__dbPairInfo=request.pair
  return st
 end
 local replacements=Engine.replacementCandidates
 Engine.replacementCandidates=function(st,id)
  local req=st and st.__doubleBattles
  if req and req.solo and id==2 then return{}end
  local out=replacements(st,id)
  if req and req.pair and(id==1 or id==3)then
   local filtered={};for _,i in ipairs(out)do if req.pair.owner[i]==id then filtered[#filtered+1]=i end end
   return filtered
  end
  return out
 end
 -- FRLG's unused wild-double branch hardcodes normal RUN failure. Keep
 -- native escape items/abilities, traps, attempts, messages and turn ownership;
 -- supply ordinary wild odds only for this mod's actual wild-double state.
 mod.hooks:wrap('battle.run',function(nextFn,c)
  local st=c and c.battle
  if not(st and st.__doubleBattles and st.double and st.wild and not st.link)then return nextFn(c)end
  local enemySpeed=0
  for _,id in ipairs({1,3})do
   local b=State.battler(st,id)
   if b and State.isAlive(st,id)then enemySpeed=math.max(enemySpeed,tonumber(b.mon.speed or b.mon.spe)or 0)end
  end
  local speed=tonumber(c.pSpd)or 0
  if speed>=enemySpeed then return true end
  local odds=(math.floor(speed*128/math.max(1,enemySpeed))+(tonumber(c.attempts)or 0)*30)%256
  return odds>(type(c.rng)=='function'and c.rng(0,255)or Rng.compat(0,255))
 end)
 mod.hooks:wrap('exp.gain',function(nextFn,c)
  local amount=nextFn(c)
  if c and c.battle and c.battle.double and not c.battle.link and opt('double_exp')=='half'then return math.max(1,math.floor((tonumber(amount)or 0)/2))end
  return amount
 end)
 part('lib/gen3/capture.lua')(mod)
 part('lib/gen3/hud.lua')(mod)
 mod.exports.pairInfo=function(st)return st and st.__dbPairInfo end
 mod.exports.online={protocol=1,generation=3,supportsDouble=function()return opt('online_doubles')~=false end}
 mod.exports.nativeDoubles=true
 mod.exports.optionSupport={generation=3,keys={'modern_hud','wild_doubles','your_side','trainer_doubles','trainer_pairs','pair_distance','double_exp','online_doubles'}}
 mod.log:info('Native Gen3 shared doubles settings, wild encounter/catch and trainer integration loaded')
end
