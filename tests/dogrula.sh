#!/usr/bin/env bash
# Tam dogrulama. ONEMLI: dar filtre kullanmaz -- gecmiste "grep TAMAM" ile
# bakarken fizik akisi hatasi aylarca gizli kalmisti. Burada HERHANGI bir
# ERROR satiri basarisizlik sayilir.
set -u
cd "$(dirname "$0")/.."
HATA=0
gurultu='resources still in use|ObjectDB instances were leaked|NavMeshGeometryParser|Pages in use exist at exit|PagedAllocator'

calistir() {
  local ad="$1"; shift
  local cikti; cikti=$("$@" 2>&1)
  local hatalar; hatalar=$(echo "$cikti" | grep -aE "^ERROR|^SCRIPT ERROR|Assertion failed|Parse Error" | grep -avE "$gurultu")
  if [ -n "$hatalar" ]; then
    echo "  [HATA] $ad"; echo "$hatalar" | head -5; HATA=1
  else
    echo "  [ok]   $ad  $(echo "$cikti" | grep -aoE 'TAMAM.*' | head -1)"
  fi
}

echo "Kor dogrulama"
calistir "import"        timeout 240 godot --headless --import
calistir "isi testi"     timeout 60  godot --headless --script res://tests/test_isi.gd
calistir "dongu testi"   timeout 120 godot --headless --script res://tests/test_dongu.gd
calistir "botlu kosu"    timeout 150 godot --headless --fixed-fps 60 --script res://tests/denge.gd -- --kosu 1 --sure 90
calistir "menu"          timeout 90  godot --script res://tests/ekran_al.gd -- --menu

if [ "$HATA" -eq 0 ]; then echo "SONUC: TEMIZ"; else echo "SONUC: HATA VAR"; fi
exit $HATA
