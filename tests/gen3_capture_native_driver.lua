-- Actual native command/Bag/target/acknowledgment input regression.
-- Requires disposable *-qa identity + external QA_UTIL. No odds/message/input
-- functions are stubbed. Fixture setup only supplies party, bag and battle.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'),'disposable QA identity required')
 local U=dofile(assert(os.getenv('QA_UTIL')));local dir=assert(os.getenv('SHOT_DIR'));local ed=require('src.core.GameVersion').get()
 local Battle=require('src.core.game3.battle');local Ui=require('src.core.game3.battle.ui');local Bridge=require('src.core.game3.battle_bridge');local State=require('src.core.game3.battle.state');local Bag=require('src.core.game3.bag');local BagMenu=require('src.ui.game3.bag_menu');local Pokemon=require('src.core.game3.pokemon');local Party=require('src.core.game3.party');local Anim=require('src.core.game3.battle.anim');local Message=require('src.ui.game3.message')
 local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
 local function shot(n)check(U.shot(game,dir..'/'..n..'.png'),'capture missing '..n)end
 game:_handleBootAction({action='new_game',start={map='FR_PALLET_TOWN',x=7,y=8,facing='down'}});U.wait(30)
 require('src.ui.game3.map_preview_screen').dismiss();require('src.ui.game3.map_name_popup').dismiss();require('src.ui.game3.start_menu').close()
 local session=game.session;require('src.core.game3.options').set(session,'textSpeed',2)
 game.options.modOptions=game.options.modOptions or{};game.options.modOptions.double_battles={wild_doubles='always',your_side='pair',trainer_doubles=true}
 game.mods.modOptions=game.mods.modOptions or{};game.mods.modOptions.double_battles={wild_doubles='always',your_side='pair',trainer_doubles=true}
 local export=assert(game.mods.exports.double_battles)
 local modern=game.mods.exports.MODERN_POKEMON_UI
 local modernMenu=modern and modern.enabled and modern.enabled()or false
 local ba=game.mods.exports.BATTLE_ART_VOXEL_FORK;local presentation=ba and ba.battlePresentation
 if presentation and presentation.nativeHudOwned and presentation.nativeHudOwned()then modernMenu=false end
 local mapKey={up='left',down='right',left='up',right='down'}
 local function menuKey(key)return modernMenu and mapKey[key]or key end
 local bagKey=os.getenv('MENU_BAG_KEY')or menuKey('right')
 local function waitFor(fn,limit,label,ack)
  for n=1,limit do if fn()then return end
   if ack and n%12==0 then U.tap(game,ack=='b'and'b'or'a')else U.wait(1)end
  end
  error(label..' phase='..tostring(Battle._phase)..' mode='..tostring(Ui._mode)..' queue='..#Ui._queue)
 end
 local function menu(id)return Battle._phase=='command'and Ui._mode=='menu'and Battle._dblSel and Battle._dblSel.active==(id or 0)end
 local function openBag()
  check(Ui._mode=='menu','BAG requires actual command menu')
  if Ui._menuIndex>2 then U.tap(game,menuKey('up'))end
  if Ui._menuIndex~=2 then U.tap(game,bagKey)end
  check(Ui._menuIndex==2,'menu BAG navigation key '..bagKey)
  U.tap(game,'a');waitFor(function()return BagMenu.isOpen()end,300,'native bag open');waitFor(function()return not(BagMenu._open or BagMenu._exit or BagMenu._switch)end,500,'native bag opening animation')
  for _=1,5 do if BagMenu.currentPocket()=='POKE_BALLS'then break end;U.tap(game,'right');waitFor(function()return not BagMenu._switch end,300,'native bag pocket animation')end
  check(BagMenu.currentPocket()=='POKE_BALLS','native ball pocket')
 end
 local function throwBall(name)
  openBag();shot(name..'-bag');U.tap(game,'a');U.wait(12);shot(name..'-use');U.tap(game,'a');U.wait(4)
  waitFor(function()return not BagMenu.isOpen()end,300,'native bag close')
 end
 local function fight(target)
  check(Ui._mode=='menu','FIGHT requires actual command menu')
  if Ui._menuIndex>2 then U.tap(game,menuKey('up'))end
  if Ui._menuIndex==2 then U.tap(game,menuKey('left'))end
  check(Ui._menuIndex==1,'native FIGHT selection')
  U.tap(game,'a');waitFor(function()return Ui._mode=='moves'end,200,'native move menu');U.tap(game,'a')
  waitFor(function()return Ui._mode=='target'or Ui._mode=='menu'or Battle._phase~='command'end,200,'native move target')
  if Ui._mode=='target'then
   if target and Ui._target.cursor~=target then U.tap(game,'right')end
   U.tap(game,'a')
  end
 end
 local function start(trainer)
  if Battle.isActive()then Battle.abort('run');U.wait(30)end
  session.party={};check(Party.giveMon(session,Pokemon.speciesFromName('BULBASAUR'),20),'fixture lead');check(Party.giveMon(session,Pokemon.speciesFromName('SQUIRTLE'),20),'fixture partner')
  for _,m in ipairs(session.party)do m.moves={45};m.pp={40};m.ppBonuses=0 end
  Bag.set(session.bag,4,20)
  local foe=trainer and{trainerClass=5,trainerName='QA',party={{species=16,level=5},{species=19,level=5}}}or{species=Pokemon.speciesFromName('CATERPIE'),level=2}
  if not trainer then check(export.tagOrganic(foe,{map='FR_ROUTE_1',terrain='land',requirePartnerSource=false}),'fixture native encounter provenance')end
  local ok,err=Bridge.start(nil,game,foe,{wild=not trainer,done=function(r)print('[CAPTURE NATIVE DONE]',r)end});check(ok,err or'battle start')
  waitFor(function()return menu(0)end,3000,'native double intro/command','a');U.wait(3)
  local st=assert(Battle.getState());check(st.__doubleBattles and st.double and st.wild==not trainer,'owned native double state');return st
 end
 local function refusal(st,id,name)
  local before,turn=Bag.get(session.bag,4),st.turn;local sel=Battle._dblSel;local chosen=sel.chosen[0];local partnerAction=Ui._partnerAction
  throwBall(name)
  waitFor(function()return Message.isOpen()end,200,'refusal text displayed');check(Ui._mode=='selmsg','native selection message mode');shot(name..'-message')
  waitFor(function()return menu(id)and#Ui._queue==0 end,5000,'refusal acknowledgment','a');shot(name..'-returned')
  check(Bag.get(session.bag,4)==before and st.turn==turn,'refusal consumed item/turn')
  check(Battle._dblSel==sel and sel.chosen[0]==chosen and Ui._partnerAction==partnerAction,'refusal lost partner selection context')
  check(Ui._active==id and State.isAlive(st,1)and State.isAlive(st,3),'refusal changed acting battler/opponents')
  print('[CAPTURE NATIVE PASS]',name)
 end
 local selected=os.getenv('QA_CAPTURE_CASE')or'all'
 if selected=='all'or selected=='refusal'then
  local st=start(false);local count=Bag.get(session.bag,4)
  openBag();U.tap(game,'b');waitFor(function()return menu(0)end,500,'native BAG cancel');check(Bag.get(session.bag,4)==count,'bag cancel spent ball')
  refusal(st,0,'two-wild-lead')
  fight(1);waitFor(function()return menu(2)end,300,'native partner command')
  check(Battle._dblSel.chosen[0]and Ui._partnerAction==Battle._dblSel.chosen[0],'partner selection fixture missing')
  refusal(st,2,'two-wild-partner')
  U.tap(game,'b');waitFor(function()return menu(0)end,300,'native partner B cancel');check(Battle._dblSel.chosen[0]==nil,'partner cancel retained first action')
  check(Bag.get(session.bag,4)==count,'refusal/cancel inventory changed');shot('partner-cancel-returned')
  Battle.abort('run');U.wait(30)
 end
 for _,targetId in ipairs({1,3})do if selected=='all'or selected=='catch'..targetId then
  local st=start(false);local absent=targetId==1 and 3 or 1;local dead=State.battler(st,absent);dead.mon.hp=0;st.absent[absent]=true
  local target=State.battler(st,targetId);target.mon.hp=1;target.status='SLP';target.mon.status='SLP';Anim.syncDisplayFromState(st)
  local expectedSpecies=target.mon.species;local before=Bag.get(session.bag,4);local partyBefore=#session.party
  check(require('src.core.game3.battle.catching').catchOdds(4,target,st,session)>=255,'fixture must guarantee native Poké Ball catch without RNG override')
  throwBall('last-wild-'..targetId);waitFor(function()return Battle._phase=='catching'end,200,'native catch presentation');shot('last-wild-'..targetId..'-throw')
  local seenCaught=false
  for n=1,14000 do
   if not Battle.isActive()then break end
   if Battle._phase=='catch_nickname_prompt'then seenCaught=true end
   if n%12==0 then U.tap(game,Battle._phase=='catch_nickname_prompt'and'b'or'a')else U.wait(1)end
  end
  check(not Battle.isActive(),'native catch completion stuck '..tostring(Battle._phase))
  check(Bag.get(session.bag,4)==before-1,'native catch spent other than one ball')
  check(#session.party==partyBefore+1 and session.party[#session.party].species==expectedSpecies,'last-wild caught/stored wrong native battler')
  shot('last-wild-'..targetId..'-field');print('[CAPTURE NATIVE PASS]','last-wild-'..targetId,expectedSpecies,seenCaught)
 end end
 if selected=='all'or selected=='trainer'then
  local st=start(true);local before=Bag.get(session.bag,4);local turn=st.turn;local partyBefore=#session.party
  throwBall('trainer');waitFor(function()return menu(2)end,300,'trainer native partner selection');fight(1)
  waitFor(function()return Message.isOpen()end,500,'native trainer refusal');shot('trainer-refusal')
  waitFor(function()return menu(0)and st.turn>turn end,14000,'native trainer turn completion','a')
  check(not st.wild and#session.party==partyBefore,'trainer refusal caught trainer Pokemon')
  check(Bag.get(session.bag,4)==before-1,'native trainer ball consumption changed');shot('trainer-returned');print('[CAPTURE NATIVE PASS]','trainer-native-refusal')
  Battle.abort('run');U.wait(30)
 end
 check(#game.mods.errors==0,'loader errors')
 print('[GEN3 CAPTURE NATIVE] PASS',ed,selected,checks,'checks','menuBagKey='..bagKey);love.event.quit()
end
