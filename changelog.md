list of additions:

* `silent load` has been re-worked an comes with different options for which parameters will be recalled when loading a track. these are found under `parameters > silent load` and are stored on a separate file, so they are independent from psets.
* hold the `Q` key to access the `timing` page. here you can set the `time signature` of the metronome (new) and `key quantization`.
* these are also found under `parameters > quantization` together with the quantization options for `snapshot recalls` and `splice changes`.
* snapshots are now configurable under under `parameters > macros`. you can choose which events will be recalled or not.
* the tape page has new actions:
  * `populate` let’s you load up to 8 files simultaniously, which are distributed along the 8 available tape splices.
  * `load` is not new but the startpoint is automatically set to the end of the previous splice, so you don’t have to worry about overwriting stuff.
  * `rename` let's you rename the focused splice.
  * `format >` sets the start point of the next splice to the end of the current splice and sets the length to the current length.
  * `format >>>` does the same as `format >` but for all consecutive splices.
* tracks can now share the same buffer, by default each track has it’s own buffer aka tape. change under `parameters > tracks > track options`.
* there’s a `popup screen` when clearing splices/tape/buffer. you need to confirm your actions to proceed.
* under `parameters > recording` there are two new options:
  * `rec pre filter` turns the pre-filter on/off. there is a lpf there by default. now you can turn that off.
  * when `auto-backup` is on the current splice is copied to the temporary buffer every time record is enabled (either manually via `rec` key or `oneshot rec`). holding the `mod` key and pressing the `rec` key will restore the previously saved audio. essentially you can undo one step.
* `rec` is now an event. this means that the rec state can be recalled in a snapshot or turning rec on/off recorded in a pattern.
* `lfo` state can be recorded into patterns and enabling an lfo can be synced to clock.
* pattern page redesign -> now includes p-macro setup keys (replaces quantization keys)
* `p-macros` accessable with `K1` hold 
