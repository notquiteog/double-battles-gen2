-- Keep original ROM cards and positions, but avoid throwing away glyph pixels
-- in the 160x144 panel before the engine scales that panel to the window.
local M={}
local phases={menu=true,moves=true,db2_target=true}
local function eligible(s)
 return s and phases[s.phase] and not s.anim and not s.expBurst
  and type(s.nativeSceneLayout)=='function'and s:nativeSceneLayout()=='gen2-native-pair'
  and not(s.wideLayout and s:wideLayout())
  and not(s.exitFadeBgp and s:exitFadeBgp())
end
function M.install(State,mod)
 if State.nativePairHudResolutionInstalled or not(mod and mod.hooks)
  or type(State.drawSceneBody)~='function'then return false end
 local Chrome=require('src.ui.gen2.Chrome')
 if type(Chrome.fitOrigin)~='function'or type(State.battlePanelScale)~='function'then return false end
 State.nativePairHudResolutionInstalled=true
 local pending
 for _,name in ipairs({'drawEnemyHud','drawPlayerHud'})do
  local draw=State[name]
  State[name]=function(s,...)
   if not s.nativePairHudDeferred then return draw(s,...)end
  end
 end
 local body=State.drawSceneBody
 State.drawSceneBody=function(s,...)
  pending=nil
  if not eligible(s)then return body(s,...)end
  local previous=s.nativePairHudDeferred
  s.nativePairHudDeferred=true
  local result={pcall(body,s,...)}
  s.nativePairHudDeferred=previous
  if not result[1]then error(result[2],0)end
  if not previous then pending={screen=s,battle=s.battle}end
  return unpack(result,2)
 end
 mod.hooks:wrap('render.hud',function(nextFn,game,viewport)
  local result=nextFn(game,viewport)
  local queued=pending;pending=nil
  local s=queued and queued.screen
  if not(s and s.battle==queued.battle and eligible(s)
   and game.stack and game.stack:top()==s)then return result end
  local g=love.graphics
  local w,h=g.getDimensions()
  local scale=s:battlePanelScale(w,h)
  local x,y=Chrome.fitOrigin(w,h,scale)
  g.push('all');g.origin();g.setShader();g.setColor(1,1,1,1)
  g.setScissor(x,y,160*scale,144*scale);g.translate(x,y);g.scale(scale,scale)
  local ok,err=pcall(function()s:drawEnemyHud();s:drawPlayerHud()end)
  g.pop()
  if not ok then error(err,0)end
  return result
 end)
 return true
end
return M
