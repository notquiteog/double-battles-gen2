-- Exercise the official native selection-message pump, not a synchronous
-- callback mock. Only rendering/data dependencies and its message surface
-- are stubbed; actual Ui.takeCommand/selectionPump/pump remain in use.
local root=assert(arg[1],'official engine source path required')
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function stub(n,t)package.loaded[n]=t;return t end
local Message=stub('src.ui.game3.message',{open=false})
function Message.isOpen()return Message.open end
function Message.isHeld()return false end
function Message.show(t,o)Message.open=true;Message.text=t;Message.done=o.done end
function Message.reset()Message.open=false;Message.done=nil end
function Message.advance()Message.open=false;local f=Message.done;Message.done=nil;if f then f()end end
stub('src.ui.game3.choice',{active=false})
local names={'commands','moves','bg','healthbox','types','ball_open','oak_advice','battle_text','anim','pic_coords','level_up_streaks'}
for _,n in ipairs(names)do stub('src.core.game3.battle.'..n,{})end
for _,n in ipairs({'frlg_font','window','summary_chrome'})do stub('src.ui.game3.'..n,{})end
for _,n in ipairs({'display','battle_chrome','pokemon','rom_text','trainer_pic','audio','se_ids'})do stub('src.core.game3.'..n,{})end
stub('src.core.Strings',{})
stub('src.mods.Runtime',{wants=function()return false end})
local State=stub('src.core.game3.battle.state',{isAlive=function(st,id)return st.alive[id]end})
local Ui=assert(loadfile(root..'/src/core/game3/battle/ui.lua'))();stub('src.core.game3.battle.ui',Ui)
local Battle=stub('src.core.game3.battle',{_phase='command'})
function Battle.getState()return Battle.st end
local spent=0;local rolls=0
stub('src.core.game3.battle.engine',{})
stub('src.core.game3.battle.catching',{isBall=function(id)return id==4 end,tryCatch=function()rolls=rolls+1;error('refusal rolled catch odds')end})
stub('src.core.game3.battle.catch_seq',{})
local session={bag={balls=3}}
stub('src.core.game3.runtime',{getSession=function()return session end})
stub('src.core.game3.bag',{has=function(b)return b.balls>0 end,remove=function()spent=spent+1;error('refusal spent item')end})
local mod={exports={}};assert(loadfile('lib/gen3/capture.lua'))()(mod)
local partner={kind='move',battler=0,slot=1,target=3};local sel={active=2,chosen={[0]=partner},pos=2}
local function setup(id)
 Message.reset();Ui._queue={};Ui._showing=false;Ui._headless=false;Ui._selCmd={stale=true};Ui._selReturn=nil
 Ui._st={};Ui._mode='none';Ui._active=id;Ui._partnerAction=partner;Ui._menuIndex=2
 Battle.st={__doubleBattles=true,double=true,wild=true,alive={[1]=true,[3]=true}};Battle._dblSel=sel
end
for _,id in ipairs({0,2})do
 setup(id);Ui._pendingCommand={kind='bag',itemId=4,battler=id}
 check(Ui.takeCommand()==nil,'refused command reached native turn engine')
 check(Ui._mode=='selmsg'and Ui._selReturn=='menu'and Ui._selCmd==nil,'refusal not routed to native selection pump')
 check(Ui._partnerAction==partner and Battle._dblSel==sel and sel.chosen[0]==partner and sel.pos==2,'partner selection context discarded')
 check(Ui._active==id and Ui._menuIndex==2,'acting battler or cursor reset')
 check(Ui.selectionPump()and Message.open and Message.text:find('Only one wild',1,true),'native pump did not display refusal')
 check(Ui._mode=='selmsg'and Ui.selectionPump(),'unacknowledged text did not block selection')
 Message.advance();check(Ui.selectionPump()and Ui._mode=='menu'and#Ui._queue==0,'acknowledgment did not restore native command menu')
 check(Ui._active==id and Ui._partnerAction==partner and sel.chosen[0]==partner,'acknowledgment changed double selection')
end
setup(2);Battle.st.alive[1]=false;session.bag.balls=0
check(mod.exports.gen3Capture.choose({kind='bag',itemId=4,battler=2})==false,'empty inventory not refused')
check(Ui.selectionPump()and Message.text=="You don't have that item.",'missing item message did not use native pump')
Message.advance();Ui.selectionPump();check(Ui._mode=='menu'and Ui._active==2,'missing item ack failed')
for _,field in ipairs({'wild','__doubleBattles'})do
 setup(0);Battle.st[field]=false;local cmd={kind='bag',itemId=4,battler=0};Ui._pendingCommand=cmd
 check(Ui.takeCommand()==cmd and#Ui._queue==0,'native trainer/unowned battle command intercepted')
end
setup(0);Battle.st.link=true;local cmd={kind='bag',itemId=4,battler=0};Ui._pendingCommand=cmd
check(Ui.takeCommand()==cmd,'native link refusal intercepted')
check(spent==0 and rolls==0,'refusal consumed item or catch RNG')
print('PASS '..checks..' official native capture selection-message/ack/partner/owner contracts')
