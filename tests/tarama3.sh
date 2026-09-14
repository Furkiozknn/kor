#!/usr/bin/env bash
K=${1:-3}; S=${2:-900}
calistir() { local et="$1"; shift
  timeout 240 godot --headless --fixed-fps 60 --script res://tests/denge.gd -- \
    --kosu "$K" --sure "$S" --etiket "$et" "$@" 2>&1 | grep -a "^SONUC"; }
calistir "temel"
calistir "yogun-zayif"      --spawn 0.45 --tavan 0.30 --guc 400
calistir "yogun-zayif-2"    --spawn 0.30 --tavan 0.45 --guc 500
calistir "yogun+yayilim6"   --spawn 0.30 --tavan 0.45 --guc 500 --yayilim 6
