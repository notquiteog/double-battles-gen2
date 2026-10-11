-- Target wire slots are relative to the sender: foes 1/2, teammates 3/4.
local function mon()return {hp=50,moves={{id='TACKLE',pp=30}}}end
for generation=1,2 do
 local p,e={mon(),mon()},{mon(),mon()}
 local b={party=p,playerParty=p,enemyParty=e,player=p[1],enemy=e[1]}
 local api
 if generation==1 then
  local function battler(m)return {mon=m,curMoves=m.moves}end
  b.player,b.enemy=battler(p[1]),battler(e[1])
  function b:lockedAction()end
  package.loaded['src.battle.BattleState']={makeBattler=function(_,m)return battler(m)end}
  api=assert(dofile('lib/gen1_online.lua')(function(_,self,partner)
   self.player2,self.enemy2=battler(p[2]),partner
  end).attach(b))
 else
  function b:forcedMove()end;function b:lockedInMove()end
  function b:volatile()return {}end;function b:hasUsableMoves()return true end
  api=assert(dofile('lib/gen2_online.lua')({decorate=function(self,p2,e2)
   self.player2,self.enemy2=p2,e2
   self.doubles={player=p[1],player2=p2,enemy=e[1],enemy2=e2}
  end}).attach({battle=b}))
 end
 local function rows(a,c)return {{kind='move',slot=1,move=1,target=a},{kind='move',slot=1,move=1,target=c}}end
 for _,side in ipairs({'player','enemy'})do
  local result=assert(api.decode(rows(4,3),side))
  if generation==1 then
   assert(result[1].target==b[side..'2'] and result[2].target==b[side])
  else assert(result[side].target==side..'2' and result[side..'2'].target==side)end
  assert(api.decode(rows(1,2),side),'legacy foe slots work')
  for _,bad in ipairs({0,3,5,1.5,'4'})do assert(not api.decode(rows(bad,1),side),'invalid/self target accepted')end
 end
 if generation==1 then
  local encoded=api.encode({user=b.player,action=p[1].moves[1],target=b.player2},{user=b.player2,action=p[2].moves[1],target=b.player})
  assert(encoded[1].target==4 and encoded[2].target==3)
 else
  assert(api.encode({kind='move',move='TACKLE',target='player2'},1).target==4)
  assert(api.encode({kind='move',move='TACKLE',target='player'},2).target==3)
 end
 p[2].hp=0;assert(not api.decode(rows(4,1),'player'),'dead teammate accepted')
 print('Gen'..generation..' mirrored ally wire validation PASS')
end
