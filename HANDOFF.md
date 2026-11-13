# The Last Emporium — Gate C visual iteration 2

## Owner decisions / status
Shop Floor approved with future expansion capacity. Counter B+ approved: face-to-face tableau, independent physical item stage, expandable ledger, persistent thumbnail/asking HUD. This is a **runtime-tested offline implementation candidate**, not final art sign-off. Creative canon, resolution, palette, portrait rig and exact balance remain provisional. PR #1 stays draft; main unchanged.

## Delivered
- One shared Shop session, thin presentation adapter, contextual stock/status controls, player save/load menu and separate developer panel. Floor owner movement and Vessa visibility are presentation-driven. Original graybox scene retained.
- Counter B+ with original temporary concept backdrop, staged item anchored to counter, bounded thumbnail and current asking price, ledger overlay, serif hierarchy, subtle ambient motes, authored offline responses, confirmation and rejection. The stage supports an aspect-fit large-object mode; no additional item catalog.
- Original domain rules preserved; only shop save decoding changed to use non-logging JSON parser for intentional corrupt-save recovery. No AI, roster, barter UI, expedition, rumor simulation or debt expansion.
- Save/load persists authoritative domain state and a revision-matched UI sidecar. Tests cover exact-once sale, navigation, stage bounds, history and restoration.

## Real evidence
Godot 4.3 stable CI: https://github.com/flyingdurian/THE_LAST_EMPORIUM/actions/runs/43510086991
37 domain checks passed; 8 presentation checks passed; import, main scene and resolution smoke passed. Screenshot capture under Xvfb at 1280x720 and 960x540 succeeded; visual iteration fixed thumbnail overflow and floating item, confirmed by actual captures. Windows x86_64 export succeeded for build commit b3cbd30c28bbdd3cc407f7394b16dc043b59efd0: https://github.com/flyingdurian/THE_LAST_EMPORIUM/actions/runs/43510289070. Artifact: https://github.com/flyingdurian/THE_LAST_EMPORIUM/actions/runs/43510289070/artifacts/14076789146. Archive verified: EXE and PCK present. Windows launch itself has not been manually tested.

## Remaining fidelity work
The counter background is a static illustrated shop concept plate with ambient animation, not the actual shared geometry from the shop floor. Background figures are decorative, not simulated customers. The temporary floor has static furniture and clerk art, dynamic owner/customer cutouts, and approximate collision footprints. It is not yet a modular expandable world. Vessa is a single painted pose with state-driven expression text, not a neutral/alternate expression rig. Portrait and pixel-sprite match, larger item art and live background require the Gate D benchmark and approval. UI is fixed logical canvas scaled at supported sizes; manual long text, keyboard focus, accessibility, interactive resize and visual playtest remain. No claim of final fidelity.

## Run
Godot 4.3: import project.godot, F5. Original harness: ui/Main.tscn F6. Windows export: unpack both EXE and PCK into same folder, run EXE (unsigned prototype). Stockroom > Appraise > Display > Shop status > Open > Serve > Respond > enter 650 > Show appraisal > Acknowledge need > Confirm sale. Switch views and toggle ledger while pending; gold must stay 120g until confirmation, then 770g. Menu Save/Load; WASD floor movement. Debug Reset creates a fresh fixture. Test both target window sizes. Run GODOT=/path/to/godot4 bash tests/run_all.sh.
