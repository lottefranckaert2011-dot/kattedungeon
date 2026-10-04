extends Node
## Tiny translation table (Dutch + English). Picks Dutch for nl/be locales.

var lang := "en"

const TEXT := {
	"title": ["ZOMBIE DORP", "ZOMBIE VILLAGE"],
	"subtitle": ["Verzamel. Bouw. Overleef.", "Gather. Build. Survive."],
	"play": ["SPELEN", "PLAY"],
	"how": ["HOE SPEEL JE?", "HOW TO PLAY"],
	"sound_on": ["GELUID: AAN", "SOUND: ON"],
	"sound_off": ["GELUID: UIT", "SOUND: OFF"],
	"best": ["Record", "Best"],
	"day": ["DAG", "DAY"],
	"night": ["NACHT", "NIGHT"],
	"night_comes": ["De nacht valt... ze komen eraan!", "Night falls... they are coming!"],
	"day_comes": ["Je hebt de nacht overleefd!", "You survived the night!"],
	"gather_hint": ["Verzamel spullen en bouw barricades!", "Gather supplies and build barricades!"],
	"zombies_left": ["Zombies", "Zombies"],
	"paused": ["PAUZE", "PAUSED"],
	"resume": ["VERDER", "RESUME"],
	"menu": ["MENU", "MENU"],
	"game_over": ["JE BENT OPGEGETEN!", "YOU GOT EATEN!"],
	"survived": ["Nachten overleefd", "Nights survived"],
	"kills": ["Zombies verslagen", "Zombies defeated"],
	"score": ["Score", "Score"],
	"new_best": ["NIEUW RECORD!", "NEW HIGHSCORE!"],
	"again": ["OPNIEUW", "TRY AGAIN"],
	"not_enough": ["Niet genoeg spullen!", "Not enough supplies!"],
	"cant_build": ["Hier kun je niet bouwen", "You can't build here"],
	"no_ammo": ["Geen kogels!", "No ammo!"],
	"searched": ["Al doorzocht", "Already searched"],
	"found": ["Gevonden", "Found"],
	"empty": ["Leeg...", "Empty..."],
	"ate": ["Lekker! +HP", "Yum! +HP"],
	"no_food": ["Geen eten", "No food"],
	"full_hp": ["Je bent al gezond", "Already healthy"],
	"reloaded": ["Toren bijgevuld", "Turret reloaded"],
	"wood": ["Hout", "Wood"],
	"stone": ["Steen", "Stone"],
	"scrap": ["Schroot", "Scrap"],
	"ammo": ["Kogels", "Ammo"],
	"food": ["Eten", "Food"],
	"b_barricade": ["Barricade", "Barricade"],
	"b_wall": ["Stenen muur", "Stone wall"],
	"b_spikes": ["Spijkerval", "Spike trap"],
	"b_turret": ["Geschut", "Turret"],
	"b_campfire": ["Kampvuur", "Campfire"],
	"search": ["E: doorzoeken", "E: search"],
	"refill": ["E: kogels erin", "E: add ammo"],
	"help_title": ["HOE SPEEL JE?", "HOW TO PLAY"],
	"help_text": [
		"OVERDAG: hak bomen (hout), sla rotsen (steen) en doorzoek huizen en kratten (schroot, kogels, eten).\n'S NACHTS: zombies komen over de wegen het dorp in. Bouw barricades en overleef!\n\nWASD / ZQSD / pijltjes: lopen\nLinks klikken / spatie: bijl\nRechts klikken / F: schieten\n1-5: bouwen kiezen, klik om te plaatsen\nE: doorzoeken / toren vullen   R: eten\nN: meteen de nacht starten\nP / Esc: pauze",
		"DAY: chop trees (wood), break rocks (stone) and search houses and crates (scrap, ammo, food).\nNIGHT: zombies walk into the village along the roads. Build barricades and survive!\n\nWASD / arrows: move\nLeft click / space: axe\nRight click / F: shoot\n1-5: pick a building, click to place\nE: search / refill turret   R: eat\nN: start the night now\nP / Esc: pause"
	],
	"back": ["TERUG", "BACK"],
	"build_mode": ["Klik om te bouwen - rechts klikken stopt", "Click to build - right click cancels"],
	"build_mode_touch": ["Tik BOUW om te plaatsen", "Tap BUILD to place"],
	"place": ["BOUW", "BUILD"],
	"credits": ["Muziek & geluid: zie CREDITS", "Music & sound: see CREDITS"],
}

func _ready() -> void:
	var loc := OS.get_locale_language()
	lang = "nl" if loc in ["nl", "af"] else "en"

func t(key: String) -> String:
	if not TEXT.has(key):
		return key
	return TEXT[key][0 if lang == "nl" else 1]
