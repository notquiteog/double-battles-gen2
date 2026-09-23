-- Isolated adapter contracts using the official 0.3.1 State implementation.
-- No gameplay, display, profile, ROM, save, or network writes.
local root=arg[1]or'/tmp/release-031-20260922/engine'
local N=0
local function check(v,m)N=N+1;assert(v,m)end
local function stub(name,value)package.loaded[name]=value;return value end
local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local mon=function(s)return {species=s,level=10,hp=25,maxHp=25,moves={33},pp={35}}end
stub('src.core.game3.battle.damage',{ensureStats=function(m)return m or mon(1)end})
stub('src.core.game3.pokemon',{_types={},types=function()return{0,0}end,speciesFromName=function(s)return tonumber(s)end,name=function(s)return tostring(s)end})
local rng=stub('src.core.game3.rng',{Random=function()return 0 end,compat=function()return 0 end})
local State=stub('src.core.game3.battle.state',assert(loadstring(read(root..'/src/core/game3/battle/state.lua')))())
local session={party={mon(1),mon(4),mon(7)},bag={balls=3}}
stub('src.core.game3.runtime',{getSession=function()return session end})
stub('src.core.game3.party',{})
local events={}
stub('src.mods.Runtime',{wants=function()return true end,emit=function(k,v)events[#events+1]={k,v}end})
local Battle=stub('src.core.game3.battle',{_headless=true,_adapter={rng=function()return rng.compat end}})
function Battle.getState()return Battle.st end
local seen
function Battle.start(opts)
 seen=opts
 local source=opts.foe.party or {opts.foe};local party={}
 for i,desc in ipairs(source)do local m={};for k,v in pairs(desc)do m[k]=v end;m.hp=m.hp or 25;m.maxHp=m.maxHp or 25;party[i]=m end
 Battle.st=State.new({wild=opts.wild,double=opts.double and not opts.wild,playerParty=opts.playerParty,foeMon=party[1],foeParty=party})
 Battle.st.trainerId=opts.foe.trainerId;return Battle.st
end
local Bridge=stub('src.core.game3.battle_bridge',{})
local done
function Bridge.start(_,_,foe,opts)
 done=opts.done
 return Battle.start({foe=foe,wild=opts.wild,double=opts.double or foe.doubleBattle,playerParty=session.party,link=opts.link})
end
local Engine=stub('src.core.game3.battle.engine',{replacementCandidates=function()return{3,4,5,6}end,planTurnActions=function(_,_,chosen)local a={};for _,v in pairs(chosen)do a[#a+1]=v end;return a end})
local Enc=stub('src.core.game3.encounters',{onStep=function()return mon(16)end,tableFor=function()return{land={slots={{species=19,minLevel=5,maxLevel=8}}}}end})
local npcA={cellX=4,cellY=4,trainerId=10};local npcB={cellX=6,cellY=4,trainerId=11}
stub('src.core.game3.objects',{forDraw=function()return{npcA,npcB}end})
stub('src.core.game3.trainer_sight',{getTrainerId=function(n)return n.trainerId end,isTrainerType=function()return true end,battleType=function()return 0 end,isDefeated=function(n)return n.defeated end})
local foes={[10]={trainerId=10,trainerClass=5,trainerName='A',party={mon(16),mon(19)}},[11]={trainerId=11,trainerClass=6,trainerName='B',party={mon(21),mon(23)}}}
stub('src.core.game3.scripting.trainers',{foeFromId=function(id)return foes[id]end})
stub('src.core.game3.scripting.space',{store={}})
local flags={}
stub('src.core.game3.scripting.flags',{trainerFlagId=function(id)return id+500 end,setFlag=function(_,_,id,v)flags[id]=v end})
local payouts={}
local Prize=stub('src.core.game3.battle.prize',{awardTrainerWin=function(_,id,opts)payouts[#payouts+1]={id=id,opts=opts};return 100 end})
local Ui=stub('src.core.game3.battle.ui',{takeCommand=function()return nil end,push=function(t,cb)UiText=t;if cb then cb()end end,openMenu=function(id)UiSlot=id end})
local caught=true;local stored;local catchCalls=0
stub('src.core.game3.battle.catching',{isBall=function(id)return id==4 end,tryCatch=function(_,target,st)catchCalls=catchCalls+1;check(st.wild,'catch remains wild');return caught,4 end})
stub('src.core.game3.battle.catch_seq',{begin=function(view,_,success,_,opts)check(opts.target==3,'slot 3 passed to native animation');if success then stored=view.enemy end end})
stub('src.core.game3.bag',{has=function(b)return b.balls>0 end,remove=function(b)b.balls=b.balls-1;return true end})
stub('src.core.game3.battle.commands',{enemyAction=function(_,id)return{kind='move',battler=id}end})
local nativeDraws=0
local HB=stub('src.core.game3.battle.healthbox',{draw=function()nativeDraws=nativeDraws+1 end,center=function()return{x=100,y=40}end})
stub('src.core.game3.battle.anim',{stage=function()return{}end,displayHpRatio=function(_,b)return 1,b.mon.hp,b.mon.maxHp end})
local drawCount=0
love={graphics=setmetatable({push=function()end,pop=function()end,rectangle=function()drawCount=drawCount+1 end},{__index=function()return function()end end})}
stub('src.core.game3.summary_data',{statusAilment=function()return 0 end})
stub('src.ui.game3.frlg_font',{draw=function()end})
local values={wild_doubles='always'};local hooks={}
local mod={events={on=function()end},exports={},log={info=function()end},options={get=function(_,k)return values[k]end,define=function(_,schema)for _,s in ipairs(schema)do if values[s.key]==nil then values[s.key]=s.default end end end},hooks={wrap=function(_,k,fn)hooks[k]=fn end}}
function mod:read(p)if p=='lib/InGameOptions.lua'then return 'return {install=function()end}'end;return read(p)end
assert(loadstring(read('lib/gen3/init.lua')))()(mod)
local enc=Enc.onStep('route1','land');local st=Bridge.start(nil,nil,enc,{wild=true})
check(st.double and st.wild and st.kind=='wild','real native State is a wild double')
check(State.isAlive(st,2)and State.isAlive(st,3),'four living slots')
check(st.enemy.species==16 and State.battler(st,3).species==19,'native map second encounter')
check(enc.party==nil and seen.foe~=enc,'original encounter descriptor unchanged')
st=Bridge.start(nil,nil,mon(16),{wild=true});check(not st.double,'script/visible encounter preserved')
values.wild_doubles='off';st=Bridge.start(nil,nil,Enc.onStep('r','land'),{wild=true});check(not st.double,'OFF stays single')
values.wild_doubles='always';values.your_side='solo'
st=Bridge.start(nil,nil,Enc.onStep('r','land'),{wild=true});check(st.double and State.isAbsent(st,2),'SOLO leaves partner absent');check(#Engine.replacementCandidates(st,2)==0,'SOLO never refills slot 2')
values.your_side='pair';st=Bridge.start(nil,nil,Enc.onStep('r','land'),{wild=true,safari=true});check(not st.double,'Safari preserved')
st=Bridge.start(nil,nil,Enc.onStep('r','land'),{wild=true,link=true});check(not st.double,'link constructor untouched')
local direct=State.new({wild=true,playerParty=session.party,foeMon=mon(16)});check(not direct.double,'request scope cleaned after construction')
values.trainer_doubles=false;values.pair_distance=1
st=Bridge.start(nil,nil,foes[10],{});check(not st.double,'distance 1 refuses trainer 2 cells away')
values.pair_distance=2;st=Bridge.start(nil,nil,foes[10],{});check(st.double and st.__dbPairInfo,'distance 2 makes adjacent pair independently of trainer 2v2')
check(#foes[10].party==2 and st.foeParty[2].species==21,'detached pair roster order')
local c=Engine.replacementCandidates(st,1);check(#c==1 and c[1]==3,'trainer A replacement pool');c=Engine.replacementCandidates(st,3);check(#c==1 and c[1]==4,'trainer B replacement pool')
Prize.awardTrainerWin(session,10,{double=true,moneyMultiplier=2});done('win');check(not payouts[1].opts.double and payouts[2].id==11 and payouts[2].opts.moneyMultiplier==2,'one native prize per trainer with same multiplier');check(flags[511],'trainer B native defeat flag');done('win');check(#payouts==2,'pair reward once')
values.trainer_pairs=false;st=Bridge.start(nil,nil,foes[10],{});check(not st.double,'pairs OFF')
values.trainer_doubles=true;st=Bridge.start(nil,nil,foes[10],{});check(st.double,'trainer 2v2 ON')
values.double_exp='half';check(hooks['exp.gain'](function()return 81 end,{battle=st})==40,'HALF experience');values.double_exp='full';check(hooks['exp.gain'](function()return 81 end,{battle=st})==81,'FULL experience')
HB.draw(1,st.enemy,{st=st});check(drawCount>0,'modern HUD draws');values.modern_hud=false;HB.draw(1,st.enemy,{st=st});check(nativeDraws==1,'modern HUD OFF native fallback')
st=Bridge.start(nil,nil,Enc.onStep('r','land'),{wild=true});local choose=mod.exports.gen3Capture.choose
local before=session.bag.balls;check(choose({kind='bag',itemId=4,battler=0})==false,'two wild targets refuse ball');check(session.bag.balls==before and catchCalls==0,'refusal costs no ball/RNG')
st.enemy.mon.hp=0;st.absent[1]=true;caught=false;local lead=st.enemy
check(choose({kind='bag',itemId=4,battler=0})==true,'last slot3 breakout handled');check(session.bag.balls==before-1 and st.enemy==lead and not st.over,'breakout preserves live slots and consumes one ball');check(#Battle._actions==1 and Battle._actions[1].battler==3 and Battle._phase=='actions','breakout schedules remaining native foe')
caught=true;check(choose({kind='bag',itemId=4,battler=0})==true,'last slot3 catch handled');check(stored==State.battler(st,3)and st.result=='catch'and st.wild and Battle._phase=='ending','native catch receives correct mon and completion');check(session.bag.balls==before-2,'one ball per attempt')
local organic=mon(21);mod.exports.tagOrganic(organic,{terrain='air',requirePartnerSource=true})
st=Bridge.start(nil,nil,organic,{wild=true});check(not st.double,'organic sky without an available source stays exact single')
mod.exports.registerPartnerSource({id='test-flight',provide=function(_,ctx)if ctx.enemy.mon.species==21 then return 22,9 end end})
organic=mon(21);mod.exports.tagOrganic(organic,{terrain='air',requirePartnerSource=true})
st=Bridge.start(nil,nil,organic,{wild=true});check(st.double and State.battler(st,3).species==22,'explicit sky provenance uses registered flock source')
check(mod.exports.unregisterPartnerSource('test-flight'),'optional source unregisters')
local run=hooks['battle.run'];st.enemy.mon.speed=20;State.battler(st,3).mon.speed=40
check(run(function()return false end,{battle=st,pSpd=50,attempts=0})==true,'owned wild double can flee when faster than both foes')
check(run(function()return false end,{battle=st,pSpd=10,attempts=0,rng=function()return 255 end})==false,'slower run can fail')
check(run(function()return false end,{battle=st,pSpd=10,attempts=0,rng=function()return 0 end})==true,'slower run uses native odds and supplied RNG')
st.link=true;check(run(function()return 'native' end,{battle=st})=='native','link run hook untouched')
print('gen3_parity_unit: '..N..' contracts passed')
