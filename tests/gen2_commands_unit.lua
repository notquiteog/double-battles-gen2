-- UI controller contracts: target/partner collection and cancellation never
-- execute a battle round until the final action is confirmed.
local N=0
local function check(v,m)N=N+1;assert(v,m)end
local hit={};local rounds=0;local last
local State={}
function State:submit(rows)last=rows;rounds=rounds+1;self.battle:takeTurn(rows);self.phase='resolving'end
function State:update()end
function State:activeMon(slot)return self.battle[slot]end
function State:useItem(id)self.battle:takeTurn({kind='item',item=id})end
function State:updateAlarm()end
function State:stepFrontAnim()end
function State:playSfx()end
local function m(n)return{name=n,hp=20,moves={{id=n,pp=10}}}end
local function create()
 local p,p2,e,e2=m('P'),m('P2'),m('E'),m('E2')
 local d={player=p,player2=p2,enemy=e,enemy2=e2,index={player=1,player2=2,enemy=1,enemy2=2},stages={player={},player2={}},takeTurn=true}
 local b={player=p,player2=p2,enemy=e,enemy2=e2,party={p,p2,m('BENCH')},doubles=d,stages={player=d.stages.player},wild=true}
 function b:lockedInMove()return nil end
 function b:takeTurn(rows)self.seen=rows;check(self.player==d.player,'lead restored before core');return{}end
 return setmetatable({battle=b,phase='moves',game={input={wasPressed=function(_,k)return hit[k]end},data={items={BALL={pocket='BALL'}}}}},{__index=State})
end
dofile('lib/gen2/commands.lua').install(State)
dofile('lib/gen2_target.lua').install(State)
local s=create();s:submit({kind='move',move='P'});check(s.phase=='db2_target'and rounds==0,'first target prompt defers turn')
s.doubleTargetSlot='enemy2';s:confirmDoubleTarget();check(s.doubleCommandSlot=='player2'and s.battle.player.name=='P2'and rounds==0,'partner gets own native menu')
check(s:activeMon('player').name=='P','art remains canonical during partner menu')
s:submit({kind='move',move='P2',target='enemy'});check(rounds==1 and last.player.target=='enemy2'and last.player2.target=='enemy','both named actions committed together')
check(s.battle.player.name=='P'and not s.doubleChosen,'selection restored after turn')
s=create();s:submit({kind='move',move='P',target='enemy'});hit.b=true;s:update(0);hit.b=nil;check(s.doubleCommandSlot=='player'and not s.doubleChosen and s.battle.player.name=='P','B from partner menu cancels first choice')
s:submit({kind='switch',index=3});s:submit({kind='switch',index=3});check(rounds==1 and s.message,'duplicate switch refused before turn')
s=create();s:submit({kind='move',move='P',target='enemy'});s:useItem('POTION');check(s.battle.seen.player.move=='P'and s.battle.seen.player2.item=='POTION','native item bypass includes first ally action')
s=create();s:useItem('BALL');check(not s.battle.seen and s.message,'two wild targets refuse ball before native inventory mutation')
s.battle.doubles.enemy.hp=0;s:useItem('BALL');check(s.battle.enemy.name=='E2'and s.battle.seen.player.item=='BALL','last wild slot promoted for native capture')
s=create();s.link={};s:submit({kind='move',move='P'});check(rounds==2,'link submission stays native')
print('gen2_commands_unit: '..N..' contracts passed')
