# Primo Ministro

Versione digitale, per uso personale, di **Prime Minister** di Paul Hellyer (GMT Games, 2023): potere e prestigio
nella Gran Bretagna vittoriana, fra disegni di legge, elezioni, Favore della Regina e sfide per la guida del Governo.

Si gioca da qui: https://tannoiser2.github.io/Primo-Ministro/

## Cosa c'è

- **Tutorial**: una partita guidata contro il Clockwork più facile, con la visita del tabellone in otto tappe, una
  lezione per ogni tipo di decisione, la mossa obbligata nei primi due round e poi un consiglio motivato a ogni mossa.
- **Solitario contro il Clockwork** del regolamento ufficiale: Sistema I (sei sempre Primo Ministro, con la riserva)
  e Sistema II (il Clockwork può governare), con tutti e dieci i politici automatici e le loro carte.
- **Partite da 2 a 4 giocatori** con le regole complete del gioco a più giocatori: Patto, Backbencher, carte Dibattito,
  incarichi (carte Carriera), dimissioni, accordo sui disegni di legge, Decano della Camera. I posti senza giocatore
  li guida un'IA costruita sulle carte Clockwork (capi) e su regole semplici per i Backbencher.
- **Online con gli amici** (stanze con codice di 4 lettere su Firebase, radice `primoministro`) e **salvataggi**: sul
  dispositivo a ogni decisione, online a ogni round o dal menu della partita.
- **Carte in italiano sulla grafica originale**: disegni di legge, eventi, sostenitori, carte Clockwork, politici.
  Il tabellone è quello originale con le scritte tradotte e i segnalini sopra (si ingrandisce con la rotella o con due
  dita e si sposta trascinando); con «Cambia tabellone» si passa a uno schema più leggibile sugli schermi piccoli.

## Come è fatto

- Godot 4.7 (GL Compatibility), esportazione web.
- `scripts/motore.gd`: tutte le regole, senza interfaccia. Lo stato è un dizionario serializzabile; il motore avanza da
  solo finché serve una decisione umana (`s.att`), `opzioni()` elenca le risposte lecite, `rispondi()` le applica.
  I politici automatici decidono dentro il motore con il generatore di numeri dello stato: la stessa sequenza di
  decisioni dà sempre la stessa partita, ed è così che funziona l'online (ogni dispositivo rigioca le stesse decisioni).
- `scripts/dati.gd`: tabellone, plance, politici e carte Clockwork. `scripts/dati_gen.gd` è generato da
  `tools/genera_dati.py` a partire dai file di testo in `tools/dati/` (carte trascritte e traduzioni).
- `scripts/main.gd`, `scripts/tabellone.gd`: schermate e tavolo. `scripts/rete.gd`: Firebase via REST.
- `tools/carte.py <materiale estratto dal modulo TTS>`: ricompone le carte in italiano sulla grafica originale
  (cancella le scritte inglesi ricostruendo lo sfondo e le riscrive). Il materiale originale non sta nel repository.
- `tools/controlla_glifi.py`: verifica che ogni carattere dei testi esista nei font (niente quadratini).

## Prove

```
godot --headless --path . -s tests/sim.gd -- 40        # partite automatiche in tutte le modalità
godot --headless --path . -s tests/tutor.gd -- 40      # partite giocate seguendo i consigli del tutorial
GODOT=godot tests/prova_online.sh                      # due istanze sulla stessa partita con un finto Firebase
python3 tools/controlla_glifi.py
```

## Pubblicazione

Il workflow *Pubblica* non parte a ogni modifica: si lancia a mano da Actions oppure con un commit che contiene
`[pubblica]` nel messaggio. Pubblica su GitHub Pages (e sulla ludoteca privata Cloudflare se ci sono i segreti).

## Da fare

- Scenari del regolamento (multigiocatore e Clockwork C1-C5).
- Carta Dibattito del Capo dell'Opposizione nelle partite a tre.

Font: Milonga, Old Standard TT e Rye (SIL Open Font License, in `assets/font/`).
