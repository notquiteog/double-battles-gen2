-- Official 0.3.1 initializes four presentations for doubles, but its wild
-- intro still slides/throws only the two singles slots. Extend that sequence
-- for our wild encounters; trainer/link/native-authored intros remain owners.
return function()
 local Intro=require('src.core.game3.battle.intro_seq')
 local Anim=require('src.core.game3.battle.anim')
 local State=require('src.core.game3.battle.state')
 local Strings=require('src.core.Strings')
 local active
 local function ids(st,candidates)
  local out={};for _,id in ipairs(candidates)do if not State.isAbsent(st,id)and State.battler(st,id)then out[#out+1]=id end end
  return out
 end
 local function syncEnemy()
  if not active or State.isAbsent(active,3)then return end
  local lead,second=Anim.present(1),Anim.present(3)
  if lead and second then
   -- These are only intro slide/emergence values. Copying stops when the
   -- sequence finishes, before moves, fainting, switching or capture own them.
   for _,key in ipairs({'visible','ox','oy','darken','scale'})do second[key]=lead[key]end
  end
 end
 local reset=Intro.reset
 Intro.reset=function(...)active=nil;return reset(...)end
 local begin=Intro.begin
 Intro.begin=function(st,opts)
  local started=begin(st,opts)
  if not(started and st and st.__doubleBattles and st.wild and st.double and not st.link)then return started end
  local steps=Intro._steps
  if type(steps)~='table'then return started end
  -- Respect an engine that already builds the multi-battler wild sequence.
  local needsPatch=false
  for _,step in ipairs(steps)do
   if (step.kind=='player_throw'or step.kind=='healthbox')and not(step.data and step.data.ids)then needsPatch=true end
  end
  if not needsPatch then return started end
  local foes,players=ids(st,{1,3}),ids(st,{0,2})
  local messages={}
  for _,step in ipairs(steps)do
   local d=step.data or{};step.data=d
   if step.kind=='player_throw'then d.ids=players
   elseif step.kind=='healthbox'or step.kind=='cry'then d.ids=d.side=='player'and players or foes
   elseif step.kind=='msg'then messages[#messages+1]=d end
  end
  if not st.ghostBattle and messages[1]and #foes==2 then
   messages[1].text=Strings('Wild %s and\n%s appeared!',State.displayName(State.battler(st,1)),State.displayName(State.battler(st,3)))
  end
  if messages[#messages]and #players==2 then
   messages[#messages].text=Strings('Go! %s and\n%s!',State.displayName(State.battler(st,0)),State.displayName(State.battler(st,2)))
  end
  active=st;syncEnemy()
  return started
 end
 local update=Intro.update
 Intro.update=function(...)
  local done=update(...)
  syncEnemy()
  if done or not Intro.busy()then active=nil end
  return done
 end
end
