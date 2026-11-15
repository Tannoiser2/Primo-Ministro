## Dati fissi del gioco, trascritti dal tabellone, dalle plance e dalle carte originali.
class_name Dati
extends RefCounted

## Settori dell'elettorato, in ordine alfabetico inglese (le lettere sono le icone delle carte).
const SETTORI := ["C", "F", "G", "I", "L", "M", "S", "W"]
const NOME_SETTORE := {"C": "Conservatori", "F": "Agricoltori", "G": "Gentry", "I": "Irlanda",
	"L": "Liberali", "M": "Ceto medio", "S": "Scozia", "W": "Operai"}
## Per ogni settore e partito: punti Popolarità cumulati a ogni gradino (dal basso), punti Partigiani
## a ogni gradino, gradino di partenza.
const TRACCE := {
	"C": {"C": {"p": [1, 3, 6, 8, 11, 14, 17, 20], "q": [10, 30, 60, 80, 110, 140, 170, 200], "i": 2},
		"L": {"p": [0, 2, 4, 6, 7, 8, 9], "q": [0, 0, 0, 0, 0, 0, 0], "i": 0}},
	"F": {"C": {"p": [1, 3, 5, 7, 9, 11, 14], "q": [0, 0, 0, 0, 10, 30, 60], "i": 2},
		"L": {"p": [1, 3, 5, 7, 9, 11, 14], "q": [0, 0, 0, 0, 0, 0, 0], "i": 1}},
	"G": {"C": {"p": [1, 3, 5, 7, 9, 11, 13, 16], "q": [0, 0, 0, 0, 0, 30, 60, 90], "i": 2},
		"L": {"p": [1, 3, 5, 7, 9, 11, 13, 16], "q": [0, 0, 0, 0, 0, 0, 0, 0], "i": 1}},
	"I": {"C": {"p": [1, 3, 5, 7, 9, 11, 14], "q": [0, 0, 0, 0, 0, 0, 0], "i": 1},
		"L": {"p": [1, 3, 5, 7, 9, 11, 14], "q": [0, 0, 0, 0, 30, 50, 80], "i": 2}},
	"L": {"C": {"p": [0, 2, 4, 6, 7, 8, 9], "q": [0, 0, 0, 0, 0, 0, 0], "i": 0},
		"L": {"p": [1, 3, 6, 8, 11, 14, 17, 20], "q": [10, 30, 60, 80, 110, 140, 170, 200], "i": 2}},
	"M": {"C": {"p": [1, 3, 5, 7, 9, 11, 14], "q": [0, 0, 0, 0, 0, 0, 0], "i": 1},
		"L": {"p": [1, 3, 5, 7, 9, 11, 14], "q": [0, 0, 0, 0, 0, 0, 0], "i": 1}},
	"S": {"C": {"p": [1, 2, 3, 5, 7, 9], "q": [0, 0, 0, 0, 0, 0], "i": 1},
		"L": {"p": [1, 2, 3, 5, 7, 9], "q": [0, 0, 0, 0, 0, 0], "i": 1}},
	"W": {"C": {"p": [1, 2, 3, 5, 7, 9, 11], "q": [0, 0, 0, 0, 0, 0, 0], "i": 2},
		"L": {"p": [1, 2, 3, 5, 7, 9, 11], "q": [0, 0, 0, 0, 20, 40, 70], "i": 3}},
}

## Proiezioni elettorali: [vantaggio massimo della fascia, seggi di chi è in testa].
const PROIEZIONI := [[0, 329], [4, 333], [8, 340], [12, 347], [16, 355], [18, 364], [20, 369], [22, 375],
	[24, 382], [26, 390], [28, 398], [30, 407], [32, 416], [34, 425], [36, 435], [38, 445], [40, 455],
	[42, 465], [44, 475], [46, 485], [48, 496], [50, 507], [52, 518], [54, 529], [56, 540], [58, 551],
	[60, 562], [62, 574], [64, 586], [66, 598], [68, 610], [70, 622], [72, 634], [74, 646], [9999, 658]]
const SEGGI := 658

const FAVORE_MAX := 8
const RET_MIN := -80
const RET_MAX := 100
const PV_VITTORIA := 100

## Plance: intervallo dello Standing, partenza, soglie dei cubi (lo Standing deve SUPERARE la soglia).
const PLANCE := {
	"pm": {"min": 5, "max": 14, "start": 11, "cubi": [0, 0, 8, 12]},
	"pm_facile": {"min": 5, "max": 14, "start": 11, "cubi": [0, 0, 8, 11]},
	"opp": {"min": 4, "max": 11, "start": 5, "cubi": [0, 0, 8]},
	"opp_facile": {"min": 4, "max": 11, "start": 5, "cubi": [0, 0, 7]},
	"bb": {"min": 0, "max": 8, "start": 0, "cubi": [-1, 2]},
	"cw_pm": {"min": 5, "max": 14, "start": 11, "cubi": [0, 0, 8]},
	"cw_opp": {"min": 4, "max": 11, "start": 5, "cubi": [0, 0, 7]},
}

## I dieci politici: n = numero della carta, p = partito, abilità con livello (0 = assente).
const POLITICI := [
	{"id": "aberdeen", "nome": "Conte di Aberdeen", "corto": "Aberdeen", "n": 8, "p": "C", "camp": 1, "set": ["C", "G", "S"], "dib": 1, "lus": 2, "hob": 1, "inf": 0},
	{"id": "derby", "nome": "Conte di Derby", "corto": "Derby", "n": 7, "p": "C", "camp": 0, "set": [], "dib": 2, "lus": 1, "hob": 1, "inf": 1},
	{"id": "disraeli", "nome": "Benjamin Disraeli", "corto": "Disraeli", "n": 9, "p": "C", "camp": 1, "set": ["C", "M", "W"], "dib": 1, "lus": 1, "hob": 2, "inf": 0},
	{"id": "gladstone", "nome": "W.E. Gladstone", "corto": "Gladstone", "n": 4, "p": "L", "camp": 1, "set": ["I", "L", "W"], "dib": 2, "lus": 0, "hob": 1, "inf": 1},
	{"id": "melbourne", "nome": "Visconte Melbourne", "corto": "Melbourne", "n": 1, "p": "L", "camp": 0, "set": [], "dib": 1, "lus": 1, "hob": 2, "inf": 1},
	{"id": "palmerston", "nome": "Visconte Palmerston", "corto": "Palmerston", "n": 5, "p": "L", "camp": 2, "set": ["F", "I", "W"], "dib": 1, "lus": 0, "hob": 1, "inf": 1},
	{"id": "peel", "nome": "Sir Robert Peel", "corto": "Peel", "n": 10, "p": "C", "camp": 2, "set": ["G", "I", "M"], "dib": 1, "lus": 0, "hob": 1, "inf": 1},
	{"id": "rosebery", "nome": "Conte di Rosebery", "corto": "Rosebery", "n": 3, "p": "L", "camp": 1, "set": ["G", "L", "S"], "dib": 1, "lus": 2, "hob": 1, "inf": 0},
	{"id": "russell", "nome": "Conte Russell", "corto": "Russell", "n": 2, "p": "L", "camp": 1, "set": ["G", "L", "M"], "dib": 1, "lus": 0, "hob": 1, "inf": 2},
	{"id": "salisbury", "nome": "Marchese di Salisbury", "corto": "Salisbury", "n": 6, "p": "C", "camp": 1, "set": ["C", "F", "I"], "dib": 1, "lus": 0, "hob": 1, "inf": 2},
]

## Carte Clockwork. Per ogni cubo le opzioni in ordine di priorità.
##   F+n  Favore proprio; Fp-n  Favore dell'avversario; D-n / D+n  Dibattito; DHB+n  Dibattito sul disegno
##   più alto; C:X  Campagna di un gradino; CC:X  di due; INFn  Influenza; S  Sostenitore (S2 = Livello 2).
## att = Raggio d'Attacco; dif = Raggio di Difesa (difmp per i disegni M o P); pb = soglia di deputati
## Partigiani per pescare i disegni di partito; sel = Raggio di Selezione (selmp per M o P).
const CLOCKWORK := {
	"aberdeen": {"stelle": [1, 1],
		"opp": [["F+2", "D-10", "C:C", "S"], ["D-10", "C:C", "C:G", "S"], ["D-10", "Fp-2", "C:S", "S"]], "att": [300, 350],
		"pm": [["DHB+10", "C:C", "C:S", "S"], ["DHB+10", "C:G", "S"], ["DHB+10", "F+2", "S"]], "dif": [270, 340], "pb": 280, "sel": 300},
	"derby": {"stelle": [2, 2],
		"opp": [["D-20", "F+1", "S"], ["D-20", "S"], ["D-20", "S"]], "att": [290, 370],
		"pm": [["DHB+20", "INF10", "D+20", "S"], ["DHB+20", "INF10", "F+1", "S"], ["DHB+20", "INF10", "D+20", "S"]], "dif": [260, 340], "pb": 260, "sel": 290},
	"disraeli": {"stelle": [2, 2],
		"opp": [["S2"], ["D-10", "C:C", "S2"], ["C:M", "C:W", "S2"]], "att": [300, 350],
		"pm": [["DHB+10", "S2"], ["DHB+10", "C:C", "S2"], ["DHB+10", "C:M", "C:W", "S2"]], "dif": [280, 340], "pb": 280, "sel": 310},
	"gladstone": {"stelle": [2, 2],
		"opp": [["D-20", "C:L", "S"], ["D-20", "C:I", "S"], ["D-20", "C:W", "S"]], "att": [300, 370],
		"pm": [["DHB+20", "INF10", "C:W", "S"], ["DHB+20", "INF10", "C:L", "S"], ["D+20", "C:I", "S"]], "dif": [260, 340], "pb": 260, "sel": 290},
	"melbourne": {"stelle": [2, 2],
		"opp": [["S2"], ["D-10", "S2"], ["D-10", "F+1", "S2"]], "att": [300, 350],
		"pm": [["DHB+10", "S2"], ["DHB+10", "INF10", "S2"], ["DHB+10", "INF10", "F+1", "S2"]], "dif": [270, 340], "pb": 270, "sel": 300},
	"palmerston": {"stelle": [3, 3],
		"opp": [["CC:I", "CC:W", "S"], ["CC:F", "S"], ["D-10", "S"]], "att": [310, 340],
		"pm": [["DHB+10", "CC:F", "CC:W", "S"], ["DHB+10", "CC:I", "INF10", "S"], ["DHB+10", "INF10", "CC:W", "S"]], "dif": [290, 340], "pb": 270, "sel": 320},
	"peel": {"stelle": [3, 3],
		"opp": [["CC:G", "CC:I", "S"], ["CC:M", "S"], ["D-10", "S"]], "att": [310, 340],
		"pm": [["DHB+10", "CC:I", "CC:M", "S"], ["DHB+10", "CC:G", "INF10", "S"], ["DHB+10", "INF10", "CC:M", "S"]], "dif": [290, 340], "pb": 270, "sel": 320},
	"rosebery": {"stelle": [1, 1],
		"opp": [["F+2", "D-10", "C:L", "S"], ["D-10", "C:L", "C:G", "S"], ["D-10", "Fp-2", "C:S", "S"]], "att": [300, 350],
		"pm": [["DHB+10", "C:L", "C:S", "S"], ["DHB+10", "C:G", "S"], ["DHB+10", "F+2", "S"]], "dif": [270, 340], "pb": 280, "sel": 300},
	"russell": {"stelle": [2, 3],
		"opp": [["INF10", "C:L", "S"], ["INF10", "C:M", "S"], ["INF10", "C:G", "D-10", "S"]], "att": [300, 350],
		"pm": [["INF20", "DHB+10", "C:M", "S"], ["INF20", "DHB+10", "C:G", "S"], ["INF20", "D+10", "C:L", "S"]],
		"dif": [280, 340], "difmp": [250, 340], "pb": 250, "sel": 310, "selmp": 280},
	"salisbury": {"stelle": [2, 3],
		"opp": [["INF10", "C:C", "S"], ["INF10", "C:F", "S"], ["INF10", "C:I", "D-10", "S"]], "att": [300, 350],
		"pm": [["INF20", "DHB+10", "C:I", "S"], ["INF20", "DHB+10", "C:F", "S"], ["INF20", "D+10", "C:C", "S"]],
		"dif": [280, 340], "difmp": [250, 340], "pb": 250, "sel": 310, "selmp": 280},
}

static func politico(id: String) -> Dictionary:
	for p in POLITICI:
		if p["id"] == id:
			return p
	return {}

static func ddl(id: String) -> Dictionary:
	for d in DatiGen.DDL:
		if d["id"] == id:
			return d
	return {}

## Seggi previsti per chi ha un vantaggio di `v` punti Popolarità (v >= 0).
static func seggi_in_testa(v: int) -> int:
	for r in PROIEZIONI:
		if v <= r[0]:
			return r[1]
	return SEGGI

static func arrotonda10(x: int) -> int:
	return int(floor((x + 5) / 10.0)) * 10
