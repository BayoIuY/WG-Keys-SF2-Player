# WG Keys SF2 Player 2.1

Projeto Flutter/Android para carregar e tocar SoundFont `.sf2` com FluidSynth.

## O que foi corrigido
- Integração com `fluidsynth-kmp:1.1.1` usando somente a API documentada.
- Removidas chamadas não existentes do wrapper (`cc`, `pitchBend`, `allNotesOff`).
- MIDI Android corrigido para `MidiOutputPort` + `MidiReceiver`.
- Correção do estado do arquivo SF2 no Flutter.
- Somente `.sf2` é aceito no seletor nesta versão.
- Configuração Android/Flutter atualizada para o plugin Gradle do Flutter.
- Java/Kotlin configurados para JVM 17.

## Compilação
1. Instale Flutter estável e Android SDK.
2. Na raiz do projeto, execute:

   `flutter pub get`

3. Gere o APK:

   `flutter build apk --release`

O APK ficará em `build/app/outputs/flutter-apk/app-release.apk`.

### Se a pasta Android tiver sido criada sem o wrapper Gradle
Execute uma vez na raiz:

`flutter create --platforms=android .`

Depois confira se os arquivos deste ZIP continuam presentes em:
- `lib/main.dart`
- `android/app/src/main/kotlin/com/wgkeys/sf2player/MainActivity.kt`
- `android/app/build.gradle`
- `android/settings.gradle`
- `android/build.gradle`

## Observação
O `fluidsynth-kmp` fornece FluidSynth nativo para Android, portanto o usuário final não precisa instalar o FluidSynth separadamente.
