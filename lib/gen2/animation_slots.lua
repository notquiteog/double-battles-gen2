-- Sequential native send-out scripts expose one public afterSendOut owner.
-- Map that original primary-side BG stream to the exact paired actor, while
-- leaving move scripts (which need an attacker/target map) untouched.
local M={}
local function base(side)return side=='enemy2'and'enemy'or side=='player2'and'player'or side end
local function active(s)return s.battle and s.battle.doubles and not s.tutorial end
local function pack(...)return{n=select('#',...),...}end
function M.install(State)
 if State.nativeAnimationSlotsInstalled then return end
 State.nativeAnimationSlotsInstalled=true
 function State:nativeAnimationSlot()
  local a=self.afterSendOut;local r=self.anim
  if not(active(self)and a and r and r.animId=='ANIM_SEND_OUT_MON'
   and(a.side=='player'or a.side=='player2'or a.side=='enemy'or a.side=='enemy2'))then return end
  if self:activeMon(a.side)==a.mon then return a.side end
 end
 local turn=State.turnFor
 if type(turn)=='function'then
  State.turnFor=function(s,side,...)return turn(s,active(s)and base(side)or side,...)end
 end
 local pic=State.animPicState
 if type(pic)=='function'then
  State.animPicState=function(s,side,...)
   local slot=s:nativeAnimationSlot()
   if slot then if side~=slot then return end;side=base(slot)end
   return pic(s,side,...)
  end
 end
 local reveal=State.revealSentOut
 if type(reveal)=='function'then
  State.revealSentOut=function(s,...)
   local slot=s:nativeAnimationSlot()
   if slot and slot~=base(slot)then
    local bg=s.anim.bg
    if s.picHidden[slot]and bg and bg.picSize and bg.picSize[base(slot)]~=nil then s.picHidden[slot]=false end
    return
   end
   return reveal(s,...)
  end
 end
 local finish=State.finishSendOut
 if type(finish)=='function'then
  State.finishSendOut=function(s,after,...)
   if not(active(s)and after and after.side~=base(after.side))then return finish(s,after,...)end
   local side=base(after.side);local hidden=s.picHidden[side]
   local normalized={};for k,v in pairs(after)do normalized[k]=v end;normalized.side=side
   local result=pack(pcall(finish,s,normalized,...));s.picHidden[side]=hidden
   if not result[1]then error(result[2],0)end
   return unpack(result,2,result.n)
  end
 end
end
return M
