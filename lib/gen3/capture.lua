-- Last-wild capture uses the native odds, storage and catch presentation. A
-- ball is refused before removal while two wild opponents remain, matching
-- the shared doubles rule. No trainer/wild flag is temporarily rewritten.
return function(mod)
 local Battle=require('src.core.game3.battle')
 local State=require('src.core.game3.battle.state')
 local Engine=require('src.core.game3.battle.engine')
 local Commands=require('src.core.game3.battle.commands')
 local Ui=require('src.core.game3.battle.ui')
 local Catching=require('src.core.game3.battle.catching')
 local CatchSeq=require('src.core.game3.battle.catch_seq')
 local Bag=require('src.core.game3.bag')
 local Runtime=require('src.core.game3.runtime')
 local ModRuntime=require('src.mods.Runtime')
 local function alive(st)
  local out={};for _,id in ipairs({1,3})do if State.isAlive(st,id)then out[#out+1]=id end end;return out
 end
 local function refuse(text,id)
  Ui.push(text,function()Ui.openMenu(id or 0)end)
  return false,text
 end
 local function choose(cmd)
  local st=Battle.getState()
  if not(st and st.__doubleBattles and st.double and st.wild and not st.link and cmd and cmd.kind=='bag'and Catching.isBall(cmd.itemId))then return nil end
  local remaining=alive(st)
  if #remaining~=1 then return refuse('Only one wild POKéMON\ncan remain before catching.',cmd.battler)end
  local session=Runtime.getSession();local bag=session and session.bag
  if not bag or not Bag.has(bag,cmd.itemId,1)then return refuse("You don't have that item.",cmd.battler)end
  local targetId=remaining[1];local target=State.battler(st,targetId)
  -- Prepare only opponents' actions. Throwing a ball uses the team's turn;
  -- a breakout resumes the engine's normal action/faint/residual sequence.
  local chosen={}
  for _,id in ipairs(remaining)do chosen[id]=Commands.enemyAction(st,id)end
  local actions=Engine.planTurnActions(st,Battle._adapter,chosen)
  if not Bag.remove(bag,cmd.itemId,1)then return refuse("You don't have that item.",cmd.battler)end
  st.turn=st.turn+1;st._modTurnOpen=true;st.lastUsedItem=cmd.itemId
  if ModRuntime.wants('battle.turn_started')then ModRuntime.emit('battle.turn_started',{battle=st,turn=st.turn,playerAction=cmd,actions=chosen})end
  local rng=Battle._adapter and Battle._adapter:rng()or st.rng
  local caught,shakes=Catching.tryCatch(cmd.itemId,target,st,session,rng)
  -- Native CatchSeq still looks up .enemy for storage/text. A detached view
  -- selects slot 3 without replacing either live battler during a breakout.
  local view={};for k,v in pairs(st)do view[k]=v end;view.enemy=target
  Battle._dblSel=nil;st.activeBattler=nil;Battle._actions=actions;Battle._actionI=1
  CatchSeq.begin(view,cmd.itemId,caught,shakes,{target=targetId,session=session,headless=Battle._headless,pushMsg=function(t)Ui.push(t)end})
  if caught then
   -- Native post-catch naming/registration also reads .enemy. Combat is over;
   -- preserve the caught mon there until native writeback completes.
   st.enemy=target;st.over=true;st.result='catch';Battle._pendingEnd='catch';Battle._actions={}
   if Battle._headless then Battle._phase='ending'else Battle._phase='catching'end
  elseif Battle._headless then Battle._phase='actions'
  else Battle._phase='catching'end
  return true
 end
 local take=Ui.takeCommand
 Ui.takeCommand=function()
  local cmd=take();if choose(cmd)~=nil then return nil end;return cmd
 end
 mod.exports.gen3Capture={choose=choose,livingTargets=alive}
end
