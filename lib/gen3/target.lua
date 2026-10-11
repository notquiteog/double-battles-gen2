-- Keep native target legality/confirmation, but navigate the battlefield rows
-- instead of the engine's four-direction ring (which crosses into allies).
local M={}
function M.next(current,key,allowed,active,lastFoe)
 local foes,allies={},{}
 for _,id in ipairs({1,3,0,2})do if allowed[id]then
  local row=id%2==active%2 and allies or foes;row[#row+1]=id
 end end
 local function contains(row,id)for _,v in ipairs(row)do if v==id then return true end end end
 if key=='up'then return contains(foes,lastFoe)and lastFoe or foes[1]or current end
 if key=='down'then return allies[1]or current end
 if not contains(foes,current)then return current end
 local row=foes
 if #row<2 then return current end
 local index=1;for i,id in ipairs(row)do if id==current then index=i end end
 return row[(index+(key=='left'and -2 or 0))%#row+1]
end
function M.install(Ui)
 local original=Ui.handleInput
 Ui.handleInput=function(input,...)
  local t,st=Ui._target,Ui._st
  if Ui._mode~='target'or not(t and st and st.double)or not input then return original(input,...)end
  -- Native A/B priority and all non-directional ownership stay unchanged.
  if input:wasPressed('a')or input:wasPressed('b')then return original(input,...)end
  local key
  for _,dir in ipairs({'left','right','up','down'})do if input:wasPressed(dir)then key=dir;break end end
  if not key then return original(input,...)end
  local user=st.battlers and st.battlers[t.battler]or(t.battler==0 and st.player or st.enemy)
  local mv=user and user.mon and user.mon.moves and user.mon.moves[t.slot]
  local tt=Ui.moveTargetType(user,mv)
  local selfAllowed=math.floor((tonumber(tt)or 0)/2)%2==1
  local allowed={}
  for id=0,3 do
   local b=st.battlers and st.battlers[id]or(id==0 and st.player or id==1 and st.enemy)
   if b and not(st.absent and st.absent[id])and(id~=t.battler or selfAllowed)then allowed[id]=true end
  end
  if t.cursor%2~=t.battler%2 then t.rowFoe=t.cursor end
  local chosen=M.next(t.cursor,key,allowed,t.battler,t.rowFoe)
  if chosen~=t.cursor then t.cursor=chosen;t.hidden=false;t.blinkCounter=8 end
  return true
 end
 return function()Ui.handleInput=original end
end
return M
