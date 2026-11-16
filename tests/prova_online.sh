#!/bin/bash
# Prova online completa: finto Firebase + due istanze di Godot (host e ospite) che giocano la stessa partita.
# Le due impronte finali devono essere uguali. Uso: GODOT=/percorso/godot tests/prova_online.sh
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
python3 tests/firebase_mock.py 8765 > /tmp/pm_mock.log 2>&1 &
MOCK=$!
sleep 1
export FR_DB_URL=http://127.0.0.1:8765/db FR_AUTH_URL=http://127.0.0.1:8765/signup FR_REFRESH_URL=http://127.0.0.1:8765/refresh
rm -f /tmp/pm_codice /tmp/pm_host.cfg /tmp/pm_guest.cfg
PM_RUOLO=host PM_CODICE=/tmp/pm_codice FR_SESSION=/tmp/pm_host.cfg timeout 240 $G --headless --path . -s res://tests/online_auto.gd > /tmp/pm_host.log 2>&1 &
H=$!
PM_RUOLO=guest PM_CODICE=/tmp/pm_codice FR_SESSION=/tmp/pm_guest.cfg timeout 240 $G --headless --path . -s res://tests/online_auto.gd > /tmp/pm_guest.log 2>&1 &
O=$!
wait $H $O
kill $MOCK
grep "PM \|ERROR" /tmp/pm_host.log /tmp/pm_guest.log
