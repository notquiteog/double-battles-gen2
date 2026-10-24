# Gen3 double-battle Poké Ball refusal

Verified against the latest official Gen1Recomp release, **0.3.96**, using its
native LÖVE runtime, genuine FireRed/LeafGreen import caches and separate
throwaway QA saves. No ROM/cache pixels or player saves are included.

## Cause and fix

With two wild opponents remaining, the capture extension intercepted the real
Bag command and queued a refusal using `Ui.push`. It left `Ui._mode` as `none`.
Native double-command update returns before the ordinary turn-message pump, so
the queue never displayed or drained: the player saw a blank textbox and A/B
could not restore the command menu.

The refusal now uses the native selection-message lifecycle, matching
`Ui.refuseItems`: clear the pending selection command, return to `menu`, enter
`selmsg`, then queue the message. The active battler is retained. It does not
call `Ui.openMenu`, which would discard `_partnerAction`; both the first
queued ally action and the partner's UI context/cursor survive acknowledgment.
The refusal consumes no ball, turn or catch RNG. Native trainer, link and
unowned battles retain their existing command handling. Catch odds, storage,
animation, partner selection and wild-source rules are unchanged.

## Reproduction and validation

Unfixed native FireRed reproduces through **BAG → POKé BALL → USE**. The command
phase remains active with `mode=none`, one queued message and no displayed
message even after repeated real A presses. The fixed version displays the
refusal, accepts actual acknowledgment and returns to the same ally's menu.

Focused tests:

```
luajit tests/gen3_capture_message_unit.lua <official-engine-source>
luajit tests/gen3_parity_unit.lua <official-engine-source>
```

The first runs **23 contracts with the actual official Ui module**, including
its `takeCommand`, `selectionPump` and `pump`; only rendering/data dependencies
and the message surface are stubbed. It checks lead/partner refusal, held text,
acknowledgment, missing inventory, untouched partner action/cursor/selection,
zero item/RNG use and native trainer/link/unowned pass-through. The second runs
**77 parity contracts** with official State, covering last-wild breakout and
catch behavior in addition to encounter and partner boundaries. Both pass.

`tests/gen3_capture_native_driver.lua` drives real native controls. It does not
stub odds, messages, menus, controller input or turn execution. Party/bag and
battle descriptors are disposable fixtures. A legitimate FAST text preference
is set; real bag opening/pocket/exit animations are awaited. It accepts
`QA_UTIL`, `SHOT_DIR`, and optional `QA_CAPTURE_CASE=refusal|catch1|catch3|trainer`.
Default `all` covers:

- Bag B cancellation before item use.
- Two-wild refusal from lead and partner; acknowledgment retains both current
  battler and previous ally command/partner UI context. B then cancels the
  partner's selection through the native controller.
- Poké Ball capture with only slot1 or slot3 living. The fixture is sleeping
  at1HP with native catch odds>=255, without overriding the catch function or
  RNG. Native animation/nickname completion returns from battle; exactly one
  ball is consumed and the correct Pokémon is added once to the owned party.
- Trainer ball refusal through a complete native paired turn; the ball's
  normal trainer-use consumption remains one, no Pokémon is caught, and the
  next native command menu becomes available.

Final standalone FireRed and LeafGreen runs each pass **85 checks**, with no
loader errors. Bag/USE, both restored ally menus, partner cancellation, catch
presentation/field return and trainer return captures were inspected. The driver
handles optional enabled Modern UI menu directions; `MENU_BAG_KEY=down` can
explicitly select its vertical BAG position. Other companion mods are optional.
Combined and immutable-ZIP acceptance is coordinated by the release owner and
is separate from these standalone source results.
