#!/bin/bash
# Downloads the CC0 audio packs used by the game and converts the chosen
# files to normalized mono OGG in assets/audio/. See CREDITS.md for sources.
# Needs: curl, unzip, ffmpeg (with libvorbis).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
M="$ROOT/assets/audio/music"
S="$ROOT/assets/audio/sfx"
mkdir -p "$M" "$S"
cd "$TMP"

dl() { curl -sSL -o "$2" "$1"; }
dl https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip rpg.zip
dl https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip impact.zip
dl https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip ui.zip
dl https://opengameart.org/sites/default/files/zombies.zip zombies.zip
dl "https://opengameart.org/sites/default/files/i%20became%20a%20zombie.mp3" ibecame.mp3
dl https://opengameart.org/sites/default/files/stumble_around_0.wav stumble.wav
dl https://opengameart.org/sites/default/files/sinister_abode_0.wav sinister.wav
dl "https://opengameart.org/sites/default/files/MonsterVania%208bit%20%231.zip" mv.zip
dl https://opengameart.org/sites/default/files/last_fight.mp3 lastfight.mp3
for z in rpg impact ui zombies mv; do unzip -o -q $z.zip -d $z; done

enc() { ffmpeg -hide_banner -loglevel error -y -i "$1" $3 -ac 1 -ar 44100 -c:a libvorbis -q:a $4 "$2"; }
enc ibecame.mp3 "$M/menu_i_became_a_zombie.ogg" "-af loudnorm=I=-18:TP=-2" 1
enc stumble.wav "$M/day_stumble_around.ogg" "-af loudnorm=I=-19:TP=-2" 1
enc "mv/MonsterVania 8-bit #1 - Stage 1.ogg" "$M/night_monstervania.ogg" "-af volume=0dB" 1
enc sinister.wav "$M/night_sinister_abode.ogg" "-af loudnorm=I=-18:TP=-2" 1
enc lastfight.mp3 "$M/gameover_last_fight.ogg" "-t 42 -af afade=t=out:st=36:d=6,loudnorm=I=-19:TP=-2" 1

R=rpg/Audio I=impact/Audio U=ui/Audio Z=zombies/zombies
s() { enc "$1" "$S/$2.ogg" "-af loudnorm=I=-16:TP=-1.5" 3; }
s $R/knifeSlice.ogg swing_1; s $R/knifeSlice2.ogg swing_2; s $R/chop.ogg chop_1
for i in 0 1 2; do
  s $I/impactWood_medium_00$i.ogg chop_$((i+2))
  s $I/impactMining_00$i.ogg mine_$((i+1))
  s $I/impactPunch_medium_00$i.ogg hit_$((i+1))
  s $I/impactPlank_medium_00$i.ogg build_$((i+1))
  s $I/impactWood_heavy_00$i.ogg barricade_hit_$((i+1))
  s $I/footstep_grass_00$i.ogg step_$((i+1))
  s $I/impactMetal_light_00$i.ogg spike_$((i+1))
done
s $U/pluck_001.ogg pickup_1; s $U/pluck_002.ogg pickup_2; s $R/handleCoins.ogg scrap
s $R/metalClick.ogg empty; s $R/metalLatch.ogg reload
s $I/impactSoft_heavy_000.ogg hurt_1; s $I/impactSoft_heavy_001.ogg hurt_2
s $U/confirmation_002.ogg eat; s $R/doorOpen_1.ogg search_house; s $R/creak1.ogg search_crate
s $I/impactPlate_heavy_000.ogg break; s $U/click_002.ogg click; s $U/error_004.ogg error
s $I/impactBell_heavy_000.ogg bell_night; s $U/maximize_006.ogg day_start; s $U/confirmation_004.ogg highscore
for i in 16 17 18 19 20 21; do s $Z/zombie-$i.wav groan_$i; done
for i in 3 5 6 7 10 11; do s $Z/zombie-$i.wav zattack_$i; done
for i in 1 8 9 12 15; do s $Z/zombie-$i.wav zdie_$i; done

python3 "$ROOT/tools/gen_sfx.py"
echo "audio ok"
