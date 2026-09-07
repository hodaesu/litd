# LITD : Les Veilleurs — export Android en CI

Le pipeline Veilleurs construit un APK Android **debug** dans GitHub Actions avec **Godot 4.7.2**, version CI épinglée pour la famille projet Godot 4.7.x.

## Ce que le gate prouve

Le job `Android debug APK export` :

1. charge le preset `Android` de `export_presets.cfg` ;
2. exécute `godot --headless --path . --export-debug "Android" build/android/LightInTheDark.apk` ;
3. vérifie que l’APK existe et n’est pas vide ;
4. refuse les erreurs Godot fatales usuelles ;
5. publie l’APK comme artefact `veilleurs-android-debug-apk` ;
6. publie aussi le journal d’export.

Ce gate protège la capacité de construction Android avant le passage sur PC. Il ne remplace pas l’installation et l’essai sur un téléphone Android réel, qui restent couverts par les gates matériels tactile, safe areas, haptique, performance, lisibilité et audio.

## Frontière iOS

La CI Linux ne prétend pas valider un build iOS signé. L’iOS final reste dans le gate matériel `ios_signed_device_build` : export Xcode, signature Apple, installation et test sur iPhone avec un environnement macOS/Xcode approprié.

## Release

L’APK généré ici est un artefact QA **debug**, pas un binaire commercial signé. La signature de release Android et les paramètres de distribution seront configurés séparément lorsque le package final sera prêt.
