# Audio implementation manifest

Official Creator Store metadata checked 2026-10-03. Public APM/PSE listings are evidence of provenance, **not** evidence that this experience can load them. All runtime, listening, seamless-loop, loudness and mobile-speaker checks remain pending user-operated Studio testing. Licensed audio may only be used within Roblox while available under [Roblox's licensed-music terms](https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use).

| ID / official source | Name | Use |
|---|---|---|
| [1842331399](https://create.roblox.com/store/asset/1842331399) | The Enchanted Wood (b), APM | Meadow day |
| [9044525961](https://create.roblox.com/store/asset/9044525961) | Make a Wish, APM | Meadow/Frozen night |
| [9043174547](https://create.roblox.com/store/asset/9043174547) | Broken Rebellion Electro Mix, APM | Volcano, Storm day |
| [9046499987](https://create.roblox.com/store/asset/9046499987) | Oceanic Underscore C, APM | Frozen day, Storm night |
| [1837417199](https://create.roblox.com/store/asset/1837417199) | The Return of the Dead King, APM | Eclipse choir |
| [9120750810](https://create.roblox.com/store/asset/9120750810) | Wind Chimes 4, PSE | Meadow/Frozen ambience, Rare bind, Reward |
| [9113203785](https://create.roblox.com/store/asset/9113203785) | Attic Wind Whistley Cold Hollow 1, PSE | Cold wind/shadow ambience |
| [9112822944](https://create.roblox.com/store/asset/9112822944) | Lava Fire Deep Rumbling 1, PSE | Volcano ambience |
| [9112853422](https://create.roblox.com/store/asset/9112853422) | Rain Heavy Rainfall Grass Wooden Roof 1, PSE | Storm ambience with low thunder |
| [9046458489](https://create.roblox.com/store/asset/9046458489) | The Revolutionary Army, APM | Spire loop |
| [9119802009](https://create.roblox.com/store/asset/9119802009) | Synth Chime Single Synth Tone 3, PSE | Common bind, Index entry |
| [1839010065](https://create.roblox.com/store/asset/1839010065) | Orchestral Fantasy, APM | Epic–Primordial bind, FloorClear |
| [9120771062](https://create.roblox.com/store/asset/9120771062) | Wing Flaps 17, PSE | Roost flight/takeoff |
| [9113985445](https://create.roblox.com/store/asset/9113985445) | Creature Roar Constant Deep Throaty Growls 2, PSE | Roost roar |
| [9125596224](https://create.roblox.com/store/asset/9125596224) | Growls Tiny Creature Cartoon Various Versions 4, PSE | Hatchling chirp |

The 3 pre-existing world IDs (150367086 Torch_Burn, 92474343494275 Healing Winds & Soft Chimes, 9116496316 Medium Size Waterfall 1) and unchanged Feedback IDs (4612374495 LevelUp, 135165335432475 Buy, 128502047397803 Arm, 80454497832356 ClimbStart, 9040271484 Rebirth) are retained, not newly verified. Runtime preloading includes these IDs and exposes their failures too. No models or third-party scripts imported.

## Behavior and limitations

- Four current-area day/night channels crossfade; old channels fade and are destroyed. Unknown/missing area falls back to StarterMeadow. Volcano/Eclipse share their musical theme across day/night; ambience/day-night gains still blend.
- The verified candidates approximate the requested themes. Frozen's cue is reflective orchestral rather than a dedicated icy-chime score; Meadow uses chimes/wind rather than retained unverified birds/insects. Listening approval is pending, not fabricated.
- BindResult triggers rarity/mutation-aware fanfare without modifying the protected ceremony. Existing ceremony sounds remain; check their combined loudness. Long feedback sources are time-limited (FloorClear 2 s, Reward 2.5 s).
- Spire Fight starts battle music; Won retains it. Ended fades back, except Top with AutoRepeat, which retains battle music through the repeat gap (6 s defensive timeout). Turning repeat OFF during the gap returns to area music; a new Fight invalidates the timeout.
- Roost-only hooks play nearby positional wing/roar/chirp sounds, capped at 3 simultaneous voices, 65 studs, per-model cooldowns. Companions and dragon models are untouched.
- MusicVolume controls musical loops; SoundVolume controls ambience, world, moments and feedback, including changes while playing.

## User-operated Hakai Test validation

Verify the correct place and feature-branch Rojo connection, with a recoverable backup and isolated Studio profiles. No publication needed.

1. Play, wait for preload completion, switch Command Bar to **Client**, then run:

   ```luau
   local a = require(game.Players.LocalPlayer.PlayerScripts.Controllers.AudioController)
   for id, status in a.GetLoadReport() do print(id, status) end
   ```

   Every configured ID must report `Loaded` (PreloadAsync Success AND Sound.IsLoaded). Record all warnings/failures; do not infer success from silence. A missing/pending ID is not a pass.
2. Visit all 5 areas; test day and night, missing AreaSpawn fallback, and rapid travel. Listen to complete loops for clicks/gaps. Check old loops disappear after fading.
3. Test music/sound sliders at 0, half and full during existing loops/cues. Verify music mute leaves sound effects independently controllable and vice versa.
4. Receive Common/Rare/Epic/Legendary/Mythic/Primordial dragons; check duration/intensity and ceremony overlap, including quick/skip/reduced-motion options.
5. Start Spire, clear/loss/Stop/death, then stage100 with AutoRepeat OFF and ON. Verify no area-track restart in repeat gap and OFF during the gap restores area music.
6. Observe nearby hatchlings/fliers/roar animations; move beyond65 studs, crowd a roost, and remove/stream models. Check positional attenuation, no more than3 voices and no lingering sources. Listen for age-appropriate voice suitability.
7. Trigger floor clear, Index discovery and reward separately; confirm unique, short sounds and no 27/48-second feedback playback.

CLI config checks and syntax compilation cannot validate audio permissions, actual loading, loop seams or subjective suitability. These remain explicitly unverified until the steps above are measured.
