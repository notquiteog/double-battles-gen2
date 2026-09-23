# Double Battles 0.12.0-test.5

Test patch for official engine 0.3.1.

Native wild doubles previously reached the command menu with the second ally
and second enemy hidden. The engine initialized four sprite presentations,
but its wild intro animated only the two singles slots.

- Extend only Doubles-owned native wild intros with the native multi-battler
  ally throw, cry queue and healthbox steps. Both enemies follow the opening
  slide and fade, and the messages name both sides where applicable.
- Stop synchronization when the intro finishes or resets. Moves, fainting,
  switching and capture retain control of each battler's presentation.
- Preserve SOLO's absent ally, authored trainer and link doubles, headless
  intros, and engines that already provide complete multi-battler wild intros.
  No companion mod is required and the native combat state remains unchanged.

Validation: 26 checks using official native State and IntroSeq with deterministic
presentation/audio/UI fixtures, plus two guards for an already-complete engine
intro. The fixture reproduces the original invisible-slot failure before
installing the adapter. Existing 44 native parity contracts and LuaJIT
entry/library compilation pass. Post-publication FireRed/LeafGreen visual
verification of the new archive is pending; earlier online-double passes did
not exercise this local wild-intro path. No live game profile was changed.


Post-publication validation: exact test.5 with BAV test.11 passed FireRed and LeafGreen native wild-double fixtures with all four battlers visible at command and after 180 frames, both enemy canvases animating, and distinct normal/shiny same-species art. Single battles also animate. Native abort returned to field. A separate FireRed native-authored trainer double reached command with all four visible. All captures were inspected. These focused presentation checks do not certify every move, species or multiplayer disconnect path.
