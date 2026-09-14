#!/usr/bin/env bash
# Rampa esnetme taramasi: hedef ortanca ~600 sn
K=${1:-3}; S=${2:-900}
calistir() { local et="$1"; shift
  timeout 500 godot --headless --fixed-fps 60 --script res://tests/denge.gd -- \
    --kosu "$K" --sure "$S" --etiket "$et" "$@" 2>&1 | grep -a "^SONUC"; }
calistir "rampa-x2"  --guc 200 --tavan 0.14 --spawn 1.3 --can 6
calistir "rampa-x3"  --guc 300 --tavan 0.10 --spawn 1.6 --can 6
calistir "rampa-x4"  --guc 400 --tavan 0.08 --spawn 2.0 --can 6
calistir "rampa-x3+gorus60" --guc 300 --tavan 0.10 --spawn 1.6 --can 6 --gorus 60
