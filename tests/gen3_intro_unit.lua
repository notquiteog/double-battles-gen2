-- Real official native State and IntroSeq, with deterministic presentation
-- tweens/audio/UI instead of GPU, ROM or a player's game profile.
local root=arg[1]or'/tmp/release-031-20260922/engine'
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function stub(k,v)package.loaded[k]=v;return v end
local function native(path)return assert(loadfile(root..'/'..path))()end
stub('src.core.game3.battle.damage',{ensureStats=function(mon)return mon end})
stub('src.core.game3.pokemon',{_types={},types=function()return{0,0}end,name=function(id)return 'MON'..id end})
stub('src.core.game3.rng',{compat=function()return 0 end})
stub('src.core.Strings',setmetatable({source=function(v)return v end},{__call=function(_,fmt,...)return string.format(fmt,...)end}))
local State=stub('src.core.game3.battle.state',native('src/core/game3/battle/state.lua'))
local cry,balls,messages={},{},{}
stub('src.core.game3.audio',{playCry=function(id)cry[#cry+1]=id end,playSe=function()end,isCryFinished=function()return true end})
stub('src.core.game3.se_ids',{})
stub('src.ui.game3.fade',{clear=function()end})
stub('src.ui.game3.battle_chrome',{hpBarLevel=function()return'green'end})
stub('src.core.game3.scripting.trainers',{introStrings=function()return{wants='TRAINER wants to battle!',sentOut='TRAINER sent out a mon!',info={className='TRAINER',name='A'}}end})
stub('src.core.game3.battle.ui',{dialogPending=function()return false end,pushTimed=function(t)messages[#messages+1]=t end})
local Battle=stub('src.core.game3.battle',{})
local presentations,stage,tweens
local Anim=stub('src.core.game3.battle.anim',{PLAYER_MON={x=48,y=80},ENEMY_MON={x=180,y=40}})
function Anim.present(id)return presentations[id=='player'and 0 or id=='enemy'and 1 or id]end
function Anim.stage()return stage end
function Anim.coords(_,id)return{x=40+id*40,y=60}end
function Anim.busy()return #tweens>0 end
function Anim.introSlideDone()return stage.slideDone end
function Anim.ballOpen(id)balls[#balls+1]=id end
function Anim.tweenStage(total,step,done)tweens[#tweens+1]={total=total,step=step,done=done,frames=0}end
local function tick()
 local running=tweens;tweens={}
 for _,t in ipairs(running)do
  t.frames=t.frames+1;t.step(math.min(1,t.frames/t.total),t)
  if t.frames>=t.total then if t.done then t.done()end else tweens[#tweens+1]=t end
 end
end
local Intro=stub('src.core.game3.battle.intro_seq',native('src/core/game3/battle/intro_seq.lua'))
local function mon(id)return{species=id,level=10,hp=25,maxHp=25,moves={33}}end
local function state(opts)
 opts=opts or{}
 local st=State.new{wild=opts.wild~=false,double=opts.double~=false,partnerIndex=opts.solo and 0 or nil,
  playerParty={mon(1),mon(7)},foeMon=mon(16),foeParty={mon(16),mon(19)}}
 st.__doubleBattles=opts.owned~=false and{}or nil;st.link=opts.link;return st
end
local function begin(st,headless)
 presentations={};for id=0,3 do presentations[id]={visible=true,ox=0,oy=0,scale=1,darken=0}end
 stage={trainer={player={},enemy={}},ball={},healthbox={},partyBar={player={},enemy={}}}
 for id=0,3 do stage.healthbox[id]={visible=true}end
 stage.healthbox.player=stage.healthbox[0];stage.healthbox.enemy=stage.healthbox[1]
 tweens={};cry={};balls={};messages={};Battle._st=st
 return Intro.begin(st,{headless=headless,pushMsg=function(t)messages[#messages+1]=t end})
end
local function finish()
 for frame=1,1200 do tick();if Intro.update()then return frame end end
 error('native intro did not complete')
end
begin(state());finish()
check(not Anim.present(2).visible and not Anim.present(3).visible,'official 0.3.1 reproduces hidden wild partners before adapter')
dofile('lib/gen3/intro.lua')()
local st=state();check(begin(st),'owned native intro starts')
check(Anim.present(3).visible and Anim.present(3).ox==-240,'both wild enemies begin offscreen slide together')
check(not Anim.present(2).visible,'partner is hidden until real native ball release')
for i=1,70 do tick();Intro.update()end
check(Anim.present(3).ox==Anim.present(1).ox and Anim.present(3).ox<0,'second foe follows native slide timing')
finish()
for id=0,3 do
 check(Anim.present(id).visible,'command phase sprite visible '..id)
 check(stage.healthbox[id].visible and stage.healthbox[id].ox==0,'native healthbox arrived '..id)
end
check(Anim.present(3).darken==0 and Anim.present(3).scale==1,'second wild enemy fully emerged')
check(#balls==2 and balls[1]==0 and balls[2]==2,'native throw releases both allies only')
check(#cry==4,'native cry queue covers all four battlers')
check(messages[1]:find('MON16',1,true)and messages[1]:find('MON19',1,true),'wild announcement includes both foes')
check(messages[2]:find('MON1',1,true)and messages[2]:find('MON7',1,true),'sendout announcement includes both allies')
Anim.present(3).visible=false;Anim.present(3).ox=27;Anim.present(3).oy=-18;Anim.present(3).scale=.4;Anim.present(3).darken=.8
Intro.update()
check(not Anim.present(3).visible and Anim.present(3).ox==27 and Anim.present(3).oy==-18
 and Anim.present(3).scale==.4 and Anim.present(3).darken==.8,'later hidden move/faint/catch presentation never overwritten')
begin(state({solo=true}));finish()
check(not Anim.present(2).visible and not stage.healthbox[2].visible and Anim.present(3).visible,'solo side stays absent while both foes show')
begin(state({wild=false}));finish()
check(Anim.present(2).visible and Anim.present(3).visible and messages[1]=='TRAINER wants to battle!','valid native trainer double sequence preserved')
begin(state({wild=false,link=true}));finish()
check(Anim.present(2).visible and Anim.present(3).visible,'native link double sequence preserved')
begin(state({owned=false}));finish()
check(not Anim.present(2).visible and not Anim.present(3).visible,'unowned wild intro untouched')
begin(state({double=false}));finish()
check(not stage.healthbox[2].visible or #balls==1,'native single throw remains one ally')
begin(state());Intro.reset();Anim.present(3).visible=false;Intro.update()
check(not Anim.present(3).visible,'reset cancels synchronization')
check(begin(state(),true)==false,'native headless intro remains skipped')
-- Simulate a future engine's complete multi-ID wild intro. It owns a distinct
-- second-enemy entrance, which the compatibility adapter must not mirror.
local already=stub('src.core.game3.battle.intro_seq',{
 reset=function()end,busy=function()return true end,
 begin=function(self)
  return true
 end,update=function()return false end,
 _steps={{kind='player_throw',data={ids={0,2}}},{kind='healthbox',data={side='enemy',ids={1,3}}},
  {kind='msg',data={text='ENGINE AUTHORED DOUBLE INTRO'}}},
})
dofile('lib/gen3/intro.lua')()
local nativeSteps=already._steps
Anim.present(1).visible=true;Anim.present(1).ox=-240
Anim.present(3).visible=false;Anim.present(3).ox=79
check(already.begin(state())==true and already._steps==nativeSteps and nativeSteps[3].data.text=='ENGINE AUTHORED DOUBLE INTRO','already multi-ID engine intro retained')
already.update()
check(not Anim.present(3).visible and Anim.present(3).ox==79,'native complete multi-ID presentation remains independently owned')
print('gen3_intro_unit: '..n..' native intro contracts passed')
