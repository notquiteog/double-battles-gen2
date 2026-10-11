local T=dofile('lib/gen3/target.lua')
local native=0
local U={_mode='target',_st={double=true,battlers={[0]={mon={moves={1}}},[1]={},[2]={},[3]={}}},_target={battler=0,slot=1,cursor=1},moveTargetType=function()return 0 end,handleInput=function()native=native+1;return 'native'end}
T.install(U)
local function press(k)return U.handleInput({wasPressed=function(_,x)return x==k end})end
press('right');assert(U._target.cursor==3)
press('left');assert(U._target.cursor==1)
press('right');press('down');assert(U._target.cursor==2)
press('right');assert(U._target.cursor==2,'horizontal must not cross sides')
press('up');assert(U._target.cursor==3,'restore selected foe row')
press('a');press('b');assert(native==2,'native confirmation/cancel retained')
U._st.absent={[3]=true};U._target.cursor=1;press('right');assert(U._target.cursor==1)
U._st.absent[2]=true;press('down');assert(U._target.cursor==1,'cannot aim absent teammate')
U._st.absent={};U._target.battler=2;U._target.cursor=1;press('down');assert(U._target.cursor==0,'partner turn cannot target itself')
U._target.battler=0;U.moveTargetType=function()return 2 end;press('down');assert(U._target.cursor==0,'native user-or-selected permits self')
press('right');assert(U._target.cursor==0,'horizontal must stay put even when self and teammate are both legal')
U._st.double=false;assert(press('left')=='native')
U._st.double=true;U._mode='moves';assert(press('left')=='native')
print('PASS Gen3 target rows, remembered foe, native legality, partner slot and A/B ownership')
