# The Last Emporium — Gate C candidate 0.1

## Status
Implementation candidate; Godot runtime and visual approval pending. Owner approved Shop Floor and Counter B+ with expandable ledger, large item stage and persistent HUD. No new roster, AI, debt or world simulation.

## Implemented source
`ui/GateC.tscn` and `ui/gate_c.gd` provide the two-view shell. Single Shop instance; navigation only changes presentation flags. Contextual stock/status drawers, waiting customer, item stage, ledger, structured offline responses and explicit confirmation. UI sidecar stores history, view and ledger state, matching the authoritative save revision. Original graybox `ui/Main.tscn`, domain modules, benchmark data and regression suite remain intact. Added presentation regression tests and CI.

## Evidence and limitations
Independent arithmetic and static checks passed; original domain files compared byte-for-byte. Godot not installed locally. Runtime tests authored, not locally executed. No exported executable or actual runtime screenshot. Temporary concept plates are not a live world render; static figures and props remain, portrait is a single pose, and walking remains in the legacy scene. Emotion cue is text. Item stage supports aspect-fit, not yet proven with large production assets. Art is temporary, not final. Actual shared background, modular floor geometry, expressions and character matching remain Gate D work. Free text explicitly disabled offline. No claim of final visual fidelity.

## Run
Godot 4: import project.godot, F5. Original harness: open ui/Main.tscn, F6. Run GODOT=/path/to/godot4 bash tests/run_all.sh. Stockroom -> Appraise -> Display -> Shop status -> Open -> Serve -> Respond -> enter 650 -> show appraisal -> acknowledge need -> confirm. Switch views and toggle ledger before confirmation. Debug panel provides save/load/reset. Test both 1280x720 and 960x540, long text, focus, persistence and exact-once settlement. Do not expand art or gameplay before the relevant approval gates.
