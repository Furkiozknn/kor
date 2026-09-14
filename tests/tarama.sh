#!/usr/bin/env bash
# Denge taramasi. Varyantlar ayni tohumla yaristirilir.
#   bash tests/tarama.sh [kosu] [sure]
K=${1:-4}; S=${2:-400}
calistir() { local et="$1"; shift
  timeout 400 godot --headless --fixed-fps 60 --script res://tests/denge.gd --     --kosu "$K" --sure "$S" --etiket "$et" "$@" 2>&1 | grep -a "^SONUC"; }
echo "tarama: $K kosu x $S sn"
calistir "temel"
calistir "guc150"            --guc 150
calistir "tavan0.15"         --tavan 0.15
calistir "hasar1.6"          --hasar 1.6
calistir "guc150+tavan0.15"  --guc 150 --tavan 0.15
calistir "guc150+tavan0.15+hasar1.6" --guc 150 --tavan 0.15 --hasar 1.6
calistir "guc180+tavan0.12+hasar1.4+soguma22" --guc 180 --tavan 0.12 --hasar 1.4 --soguma 22
