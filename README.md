# Zombie Dorp 🧟 — pixel zombie survival

**Verzamel spullen, bouw barricades en overleef zo lang mogelijk.**
Een top-down pixel-art survivalspel gemaakt in **Godot 4.3**, klaar om te uploaden op **CrazyGames** (HTML5).

Overdag hak je bomen, sla je rotsen kapot en doorzoek je huizen in het dorp.
Als de nacht valt, luidt de klok en schuifelen de zombies over de wegen het dorp in.
Zet barricades, stenen muren, spijkervallen, geschuttorens en kampvuren neer, en hou het zo lang mogelijk vol.

Verslagen zombies laten **munten** vallen. Daarmee koop je in de **wapenwinkel** (het paarse huisje met de
rood-witte luifel) betere wapens. In het dorp staat ook een **kapotte blauwe bus**: maak hem met schroot,
hout en steen, en rijd naar een **nieuw gebied** (Het Donkere Bos, De Oude Boerderij, De Rotsvallei, ...).
Je spullen, wapens en je team neem je mee; je barricades blijven achter. Een gemaakte bus blijft gemaakt.

Onderweg vind je **andere overlevenden** die "HELP!" roepen (een gele pijl aan de rand van het scherm wijst
de weg). Druk op **E** en ze gaan met je mee, ook naar volgende gebieden:

| Wie | Rol | Wat doet die? |
|---|---|---|
| Sam | schutter | schiet op zombies in de buurt |
| Noor | vechter | rent naar zombies en slaat ze met een knuppel |
| Mila | dokter | geneest jou en je team |
| Bram | bouwer | repareert barricades en hakt soms hout voor je |

Zombies vallen ook je teamleden aan. Raakt iemand gewond, dan ligt die even neer en staat de volgende ochtend weer op.

## Spelen

| Actie | Toetsenbord / muis | Telefoon / tablet |
|---|---|---|
| Lopen | WASD / ZQSD / pijltjes | joystick links |
| Bijl (zombies, bomen, rotsen, kratten) | linkermuisknop / spatie | bijl-knop |
| Schieten (kost kogels) | rechtermuisknop / F | pistool-knop (mikt automatisch) |
| Bouwen | 1-6 kiezen, klik om te plaatsen, rechts klikken stopt | tik een gebouw onderaan, dan **BOUW** |
| Houten barricade ijzer maken | E (naast de barricade) | E-knop |
| Huis / krat doorzoeken, winkel, bus maken / wegrijden, geschut bijvullen | E | E-knop |
| Ander geweer pakken | Tab / muiswiel | `<>`-knop |
| Eten (vult je honger, +15 HP) | R | appel-knop |
| Meteen de nacht starten (bonuspunten) | N | knop bovenaan |
| Pauze | P / Esc | pauzeknop |

### Gebouwen

| # | Gebouw | Kost | Wat doet het? |
|---|---|---|---|
| 1 | Barricade | 4 hout | blokkeert zombies (80 HP). Met **E** maak je er een **ijzeren barricade** van (4 schroot + 1 steen, 240 HP) |
| 2 | Poort | 6 hout + 2 schroot | jij en je team lopen erdoor, zombies niet; gaat vanzelf open |
| 3 | Stenen muur | 4 steen + 1 hout | heel sterke muur (220 HP) |
| 4 | Spijkerval | 2 hout + 2 schroot | zombies lopen erover en raken gewond |
| 5 | Geschut | 5 schroot + 3 hout + 2 steen | schiet automatisch (40 kogels, bijvullen met E) |
| 6 | Kampvuur | 5 hout + 2 steen | licht in de nacht + geneest je als je ernaast staat |

### Huizen en je eigen huis

- Bij elk huis kun je met **E naar binnen**. Kasten, kisten en boekenkasten die **glimmen** kun je doorzoeken:
  je vindt schroeven (schroot), kogels, munten, eten en soms zelfs een **wapen**. Elke ochtend liggen er weer nieuwe spullen.
- Je **eigen huis** is het groene huisje met het **hartje**. Daar begin je in elk dorp. Binnen ben je **veilig**,
  je geneest langzaam en **je team gaat mee naar binnen**.
- Zombies weten waar je bent en **bonken op de deur**. Bovenin zie je hoe sterk de deur nog is.
  Gaat hij kapot, dan moet je naar buiten. Elke ochtend is de deur weer heel. Tip: zet barricades voor je deur!

### Honger

Onder je levensbalk staat een **oranje hongerbalk**. Die loopt langzaam leeg (in ongeveer 4 minuten).
Is hij leeg, dan verlies je elke 2 seconden wat leven. Eet dus op tijd: appels vind je in fruitbomen,
bessenstruiken, kasten in huizen, bij zombies en in de winkel.

### Het Landgoed en het grote landhuis

Het tweede landje is **Het Landgoed**. Daar woon je in een **groot landhuis met 3 verdiepingen**:

- **Begane grond**: woonkamer met open haard en bank, veilig en je geneest er.
- **Eerste verdieping** (trap op met E): slaapkamers met kasten en kisten om te doorzoeken.
- **Zolder**: dozen, kisten en een gouden **schatkist** met altijd een wapen, munten en kogels.

### Elke nacht moeilijker

- Elke nacht komen er **meer zombies**, en ze worden **sterker, sneller en slaan harder**. De doodshoofdjes bovenin laten zien hoe gevaarlijk de nacht is.
- Een nacht duurt een vaste tijd (je ziet de klok). Bij **zonsopgang verbranden** de zombies die nog over zijn.

### Elk dorp is anders

Elke keer dat je met de bus wegrijdt, wordt het nieuwe dorp **opnieuw gemaakt**: andere wegen, een ander plein,
huizen op andere plekken, en de vijver en akker liggen ergens anders. Er zijn ook **seizoenen**: zomer, een
**herfstdorp** met oranje en rode bomen, en een **winterdorp** met sneeuw, besneeuwde daken en een bevroren vijver.

### Wapenwinkel

| Wapen | Prijs | Wat doet het? |
|---|---|---|
| Bijl | start | hakken en vechten |
| Knuppel | 25 munten | slaat zombies ver weg |
| Machete | 60 munten | hard en snel, hakt 2x zo snel |
| Kettingzaag | 150 munten | zaagt alles kapot (ook bomen) |
| Pistool | start | 1 kogel per schot |
| Jachtgeweer | 80 munten | 6 hagels per schot |
| Machinegeweer | 140 munten | supersnel schieten |
| 20 kogels / 2x eten | 10 / 8 munten | bijvullen |

De winkel is alleen overdag open. Je krijgt munten van zombies, uit huizen en elke ochtend als bonus.

### Gebieden en de bus

Repareren kost 8 schroot + 6 hout + 3 steen, en dat hoeft maar **één keer**: daarna blijft de bus gemaakt
en staat hij in elk nieuw gebied klaar. Wegrijden kan alleen overdag. Elk nieuw gebied geeft **+500 punten** en de dagen gaan gewoon door.

| Gebied | Hoe ziet het eruit? |
|---|---|
| 1. Het Dorp | zomer, je huis + 6 huisjes + winkel, vijver, akker |
| 2. Het Landgoed | groot landhuis met 3 verdiepingen als jouw huis |
| 3. Het Donkere Bos | heel veel bomen, donkerder |
| 4. Het Herfstdorp | oranje en rode bomen, akker |
| 5. Het Winterdorp | sneeuw, besneeuwde daken, bevroren vijver |
| 6. De Oude Boerderij | herfst, grote akker, weinig bomen |
| 7. De Rotsvallei | veel rotsen (steen!) |
| daarna | de seizoenen komen terug, maar elk dorp ziet er weer anders uit en de zombies worden steeds sterker |

### Zombies

Alle zombies zijn dorpelingen in dezelfde chibi-stijl als de speler: de boer met strohoed, de oma,
het meisje met de roze jurk, de jongen met de pet en de arbeider. Vanaf nacht 2 komen er
**rennende** zombies (rode pet), vanaf nacht 3 de grote **bruut** in tuinbroek, die barricades
heel snel sloopt. Elke nacht komen er meer.

Vanaf nacht 2 komen er ook **zombiehonden** (heel snel), vanaf nacht 3 **spuugzombies** (gooien groen slijm
over je muren; slijm maakt je trager) en **dikke zombies** (ontploffen bij je barricades en blazen ze op;
ook als je ze doodt, dus hou afstand!).

### Weer en minikaart

Vanaf nacht 2 kan het **regenen** (met bliksem) of **mistig** zijn: dan zie je alleen wat dicht bij je is.
Rechtsboven staat een **minikaart**: wit = jij, groen = je team, geel knipperend = iemand die HELP! roept,
paars = de winkel, blauw = de bus, rood = zombies.

**Score** = 10–35 punten per zombie + 250 per overleefde nacht + 500 per nieuw gebied + 150 per geredde overlevende. Je record wordt bewaard.

Een dag duurt 110 seconden (de eerste) en daarna 80 seconden. Met **N** start je de nacht eerder (bonuspunten).

## Uploaden op CrazyGames

**Snelste manier:** de kant-en-klare build staat in [`release/zombie-dorp-web.zip`](release/zombie-dorp-web.zip).
Die kun je meteen uploaden (stap 5 hieronder). Heb je iets aangepast, maak dan zelf een nieuwe build:

1. Open het project in **Godot 4.3** (Project → Import → kies `project.godot`).
2. Installeer de export templates: *Editor → Manage Export Templates → Download and Install*.
3. *Project → Export…* → kies **Web (CrazyGames)** → **Export Project** → map `build/web/`.
   (Of in een terminal: `GODOT=/pad/naar/godot tools/export_web.sh`, dat maakt meteen `build/zombie-dorp-web.zip`.)
4. Zip de **inhoud** van `build/web/` (dus `index.html` moet bovenaan in de zip staan).
5. Ga naar het [CrazyGames Developer Portal](https://developer.crazygames.com) → *Upload game* →
   kies **HTML5** en upload de zip. Test hem eerst in de **QA-tool / preview** van CrazyGames.

Er staat ook een GitHub Actions workflow (`.github/workflows/export-web.yml`) die bij elke push naar
`main` automatisch de web-build maakt; die kun je downloaden bij *Actions → Artifacts*.

### Wat er al geregeld is voor CrazyGames

- **CrazyGames SDK v3** wordt in de HTML geladen (`html/head_include` in `export_presets.cfg`,
  leesbare versie in `web/crazygames_head.html`).
- `loadingStart/loadingStop`, `gameplayStart/gameplayStop` (bij spelen, pauze, game over, menu)
  en `happytime()` bij een nieuw record.
- **Midgame-advertentie** na elke overleefde nacht en bij *Opnieuw*; het spel pauzeert en het geluid
  gaat uit zolang de advertentie loopt.
- Web-export **zonder threads** (geen speciale server-headers nodig), pijltjes/spatie scrollen de pagina niet.
- Werkt met muis + toetsenbord en met touch (mobiel), in elk 16:9-venster en fullscreen.
- Nederlands en Engels (automatisch volgens de taal van de browser, of via de knop NL/EN).

Buiten de browser (in de Godot-editor) doen alle SDK-aanroepen gewoon niets, dus je kunt normaal testen met F5.

## Projectstructuur

```
project.godot               Godot-project (viewport 480x270, pixel-perfect)
export_presets.cfg          Web-export voor CrazyGames
scenes/main.tscn            hoofdscène
scripts/autoload/           Save (record), Lang (NL/EN), Audio, CrazySDK
scripts/game/               world (kaart + A*-pathfinding), player, zombie, structure,
                            prop (bomen/rotsen/huizen), pickup, bullet, main (dag/nacht, golven)
scripts/ui/                 HUD, menu's, touch-besturing, thema
assets/sprites/             alle pixel-art (gegenereerd door tools/gen_sprites.py)
assets/audio/               muziek + geluidseffecten (CC0, zie CREDITS.md)
assets/fonts/               Kenney pixel fonts (CC0)
tools/                      sprite/geluid-generators en export-script
tests/screenshot_runner.*   speelt het spel automatisch en maakt screenshots
```

### Graphics aanpassen

Alle sprites worden pixel voor pixel getekend door `tools/gen_sprites.py` (Python + Pillow).
Wil je een zombie met een andere kleur trui of haar? Pas de lijst `ZOMBIES` aan en draai:

```
pip install pillow
python3 tools/gen_sprites.py
```

## Credits

Muziek: *megupets*, *Zane Little Music*, *HydroGene*, *TAD* — geluiden: *artisticdude*, *Kenney* —
lettertype: *Kenney*. Allemaal CC0. Details in [CREDITS.md](CREDITS.md).
