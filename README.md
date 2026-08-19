# Tarifa Fácil

Aplicativo Flutter para calcular o valor de uma corrida usando GPS.

## Funções
- Iniciar corrida pelo GPS.
- Registrar ponto de partida e ponto final.
- Medir distância percorrida em km.
- Calcular tarifa automaticamente.
- Configurar valor por km.
- Configurar valor mínimo.
- Salvar configurações no celular.

## Como gerar o APK
1. Instale Flutter.
2. No terminal, entre na pasta do projeto.
3. Execute `flutter pub get`.
4. Execute `flutter build apk --release`.
5. O APK será gerado em `build/app/outputs/flutter-apk/app-release.apk`.

O projeto foi preparado para Android e usa o pacote `geolocator` para GPS.
