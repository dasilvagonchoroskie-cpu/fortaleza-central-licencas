#!/usr/bin/env bash
# Abre a Central num celular virtual (emulador Android) e confere que ela
# NAO fecha sozinha: (1) por cima da Central 2.3, como no celular do Evandro,
# e (2) instalada do zero. Guarda fotos da tela e o registro do Android
# (logcat) em registro-emulador/. Se o app morrer, a esteira para aqui.
set -u
PKG=br.com.fortalezadigitalsecurity.licencas
APK_NOVO=saida/central-de-licencas.apk
APK_ANTIGO=ci/central-2.3.apk
OUT=registro-emulador
mkdir -p "$OUT"
FALHOU=0

adb wait-for-device
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true
adb shell getprop ro.build.version.release | sed 's/^/Android /' > "$OUT/emulador-resumo.txt"

abrir() {
  adb shell am force-stop "$PKG" || true
  adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a "$OUT/emulador-resumo.txt" || true
}

conferir() {
  # $1 = nome do teste
  local nome="$1"
  sleep 25
  adb exec-out screencap -p > "$OUT/emulador-$nome.png" || true
  if adb shell pidof "$PKG" > /dev/null 2>&1; then
    echo "$nome: ABERTA (processo vivo)" | tee -a "$OUT/emulador-resumo.txt"
  else
    echo "$nome: FECHOU (processo morto)" | tee -a "$OUT/emulador-resumo.txt"
    FALHOU=1
  fi
  adb logcat -d -b crash -v time > "$OUT/emulador-crash-$nome.txt" 2>/dev/null || true
  adb logcat -d -v time > "$OUT/logcat-completo-$nome.txt" 2>/dev/null || true
  grep -E " AndroidRuntime|DEBUG   |F/libc|F/DEBUG|$PKG|flutter|WM-|WorkManager|ActivityManager.*(Start proc|died|crash)|ActivityTaskManager.*$PKG" \
    "$OUT/logcat-completo-$nome.txt" | tail -400 > "$OUT/emulador-logcat-$nome.txt" || true
  rm -f "$OUT/logcat-completo-$nome.txt"
}

# 1) Central 2.3 (como esta no celular) e depois a 3.0 por cima.
echo "=== 1) 2.3 e depois 3.0 por cima ===" | tee -a "$OUT/emulador-resumo.txt"
adb install -r "$APK_ANTIGO" 2>&1 | tail -1 | tee -a "$OUT/emulador-resumo.txt"
abrir
sleep 15
adb exec-out screencap -p > "$OUT/emulador-0-central-2.3.png" || true
adb logcat -c || true
adb install -r "$APK_NOVO" 2>&1 | tail -1 | tee -a "$OUT/emulador-resumo.txt"
abrir
conferir "1-por-cima-da-2.3"

# 2) Instalacao do zero.
echo "=== 2) instalacao do zero ===" | tee -a "$OUT/emulador-resumo.txt"
adb uninstall "$PKG" > /dev/null 2>&1 || true
adb logcat -c || true
adb install "$APK_NOVO" 2>&1 | tail -1 | tee -a "$OUT/emulador-resumo.txt"
abrir
conferir "2-do-zero"

# 3) Abrir de novo (segunda abertura).
adb logcat -c || true
abrir
conferir "3-segunda-abertura"

echo "resultado: $([ $FALHOU = 0 ] && echo OK || echo FALHOU)" | tee -a "$OUT/emulador-resumo.txt"
exit $FALHOU
