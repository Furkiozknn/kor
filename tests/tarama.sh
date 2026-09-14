#!/usr/bin/env bash
K=${1:-3}; S=${2:-600}
calistir() { local et="$1"; shift
  timeout 420 godot --headless --fixed-fps 60 --script res://tests/denge.gd -- \
    --kosu "$K" --sure "$S" --etiket "$et" "$@" 2>&1 | grep -a "^SONUC"; }
echo "tarama: $K kosu x $S sn"
calistir "temel"
calistir "can6"          --can 6
calistir "can8"          --can 8
calistir "gorus60"       --gorus 60
calistir "can8+gorus60"  --can 8 --gorus 60
calistir "can8+gorus60+guc150" --can 8 --gorus 60 --guc 150
