# INTC Bridge — Android

Application **Android** (Flutter) qui transforme un téléphone en **pont d'impression** : elle reçoit les impressions envoyées par **Odoo** depuis le navigateur du téléphone et les transmet à une **imprimante thermique ESC/POS** en Bluetooth ou en Wi-Fi.

Même contrat que le pont PC [`intc_print_bridge`](https://github.com/Gitjaphet/intc_print_bridge) : le module Odoo fonctionne sans aucune différence avec un PC ou un téléphone.

- **Package** : `com.intc.intc_bridge`
- **Flutter** : 3.24.5 (version figée, voir [Développement](#développement))
- **Distribution** : APK signé, publié dans les Releases GitHub
- **Éditeur** : INTC

---

## Sommaire

1. [Fonctionnalités](#fonctionnalités)
2. [Installation sur un téléphone](#installation-sur-un-téléphone)
3. [Configuration dans l'application](#configuration-dans-lapplication)
4. [API HTTP](#api-http)
5. [Fiabilité Android](#fiabilité-android)
6. [Dépannage](#dépannage)
7. [Développement](#développement)
8. [Le correctif de flutter_bluetooth_serial](#le-correctif-de-flutter_bluetooth_serial)
9. [Publier une nouvelle version](#publier-une-nouvelle-version)
10. [Structure du projet](#structure-du-projet)
11. [Projets liés](#projets-liés)

---

## Fonctionnalités

- **Serveur HTTP local** sur `127.0.0.1:8080`, joignable uniquement par le navigateur du téléphone.
- **Bluetooth classique (SPP)** : connexion ouverte à chaque impression puis refermée (pas de connexion « fantôme », imprimante libre entre deux impressions).
- **Wi-Fi / réseau** : impression sur une imprimante IP (port 9100).
- **File d'impression** : les impressions simultanées passent l'une après l'autre.
- **Jeton de sécurité** généré au premier lancement, affiché avec un bouton **Copier**.
- **Ticket de test** qui passe par le vrai chemin (HTTP + jeton), exactement comme Odoo.
- **Service de premier plan** (notification permanente) : le pont continue de fonctionner application fermée ou téléphone verrouillé.
- **Démarrage automatique** au redémarrage du téléphone et après une mise à jour de l'application.

---

## Installation sur un téléphone

1. **Télécharger** `INTC-Bridge-x.y.z.apk` depuis les [Releases](../../releases).
   Le dépôt est privé : le navigateur du téléphone doit être connecté au compte GitHub, ou l'APK peut être transféré depuis un PC (câble USB, messagerie…).
2. **Ouvrir l'APK** et autoriser *« Installer des applications inconnues »* pour le navigateur ou le gestionnaire de fichiers.
3. Si **Play Protect** signale une application inconnue → **Installer quand même**.
4. **Premier lancement** — accepter :
   - les autorisations **Bluetooth** ;
   - les **notifications** ;
   - l'exemption d'**optimisation de batterie**.
5. La notification **INTC Bridge** apparaît : le service est actif.
6. **Appairer l'imprimante** dans les paramètres Bluetooth d'Android (PIN `0000` ou `1234`).

**Mise à jour** : installer le nouvel APK **par-dessus** l'ancien. Il est signé avec la même clé : la configuration et le jeton sont conservés.

---

## Configuration dans l'application

1. **Taille du papier** : 58 mm ou 80 mm.
2. **Type de connexion** :
   - **Bluetooth** : choisir l'imprimante dans la liste des appareils appairés ;
   - **Wi-Fi / Réseau** : adresse IP de l'imprimante et port (9100 par défaut).
3. **Jeton pour Odoo** : bouton **Copier**.
4. **SAUVEGARDER**.
5. **IMPRIMER UN TICKET DE TEST** → le ticket doit sortir.

Puis dans **Chrome** sur le téléphone : ouvrir Odoo, lancer une impression de codes-barres, et coller le jeton quand Odoo le demande (une seule fois).

---

## API HTTP

Identique au pont PC.

### `GET /health`
```json
{"status": "ok", "app": "INTC Bridge"}
```

### `POST /rawprint`
Octets ESC/POS bruts envoyés tels quels à l'imprimante.

- **En-tête obligatoire** : `X-Bridge-Token: <jeton>`
- **Corps** : octets bruts (`application/octet-stream`)

| Code | Réponse |
|---|---|
| 200 | `{"status": "ok", "bytes": 17}` |
| 400 | Corps vide |
| 401 | Jeton invalide |
| 500 | Erreur d'impression (imprimante non configurée, injoignable…) |

### `POST /print`
Route historique : ticket décrit en JSON, mis en forme par l'application (taille du papier, copies). Protégée par le même jeton.

Toutes les routes répondent aux requêtes CORS `OPTIONS` (`X-Bridge-Token` autorisé, `Access-Control-Allow-Private-Network: true`).

---

## Fiabilité Android

| Mécanisme | Pourquoi |
|---|---|
| Service de premier plan de type **`connectedDevice`** | Android tue les applications en arrière-plan ; `connectedDevice` n'a pas la limite de 6 h/jour imposée aux services `dataSync` depuis Android 15 |
| Exemption d'**optimisation de batterie** | Certains fabricants (Samsung, Xiaomi, Tecno, Infinix…) tuent le service malgré tout sans elle |
| Autorisation **notifications** (Android 13+) | La notification permanente est requise pour garder le service |
| **Redémarrage automatique** (`autoRunOnBoot`) | Le pont revient seul après un redémarrage du téléphone |
| Relance du serveur toutes les 5 s s'il est tombé | Auto-réparation |
| Configuration relue à chaque impression | Un changement fait dans l'écran est pris en compte immédiatement, sans redémarrer l'application |

> La permission d'exemption de batterie convient à une distribution en **APK direct**. Une publication sur le Play Store exigerait une justification auprès de Google.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| *Le service d'impression n'est pas démarré* | Service arrêté | Rouvrir l'application |
| *Imprimante injoignable : éteinte, hors de portée ou utilisée par un autre appareil* | Imprimante éteinte, loin, ou connectée à un PC / autre téléphone | L'allumer ; déconnecter l'autre appareil (une seule connexion Bluetooth à la fois) |
| *Aucune imprimante configurée* / *Aucune IP configurée* | Configuration non sauvegardée | Choisir l'imprimante → **SAUVEGARDER** |
| *Jeton invalide* | Mauvais jeton dans Odoo | Recopier le jeton depuis l'application |
| Les impressions s'arrêtent après un moment | Optimisation de batterie active | *Paramètres* → *Applications* → *INTC Bridge* → *Batterie* → **Non restreinte** |
| L'imprimante n'apparaît pas dans la liste | Imprimante non appairée | L'appairer dans les paramètres Bluetooth, puis ↻ |

---

## Développement

### Prérequis

- **Flutter 3.24.5** — ne pas lancer `flutter upgrade` : le projet dépend de versions précises (dont `flutter_bluetooth_serial`).
- **Java 17**, Gradle 8.14, Android Gradle Plugin 8.2.2.
- Le correctif de `flutter_bluetooth_serial` appliqué au cache local (voir ci-dessous).

```bash
flutter pub get
patch -p1 --forward -d ~/.pub-cache/hosted/pub.dev/flutter_bluetooth_serial-0.4.0 < ci/flutter_bluetooth_serial.patch
flutter analyze --no-fatal-infos lib/
flutter build apk --release      # signé en debug en local (sans variables de signature)
```

> Un APK construit en local est signé avec la clé de **debug** : il ne s'installe pas par-dessus une version publiée (signée avec la clé de release). Utiliser l'APK des Releases pour les tests de mise à jour.

---

## Le correctif de flutter_bluetooth_serial

Le paquet `flutter_bluetooth_serial` 0.4.0 (2021) n'est plus maintenu. Le fichier [`ci/flutter_bluetooth_serial.patch`](ci/flutter_bluetooth_serial.patch) contient trois corrections, appliquées automatiquement par le workflow après `flutter pub get` :

| Fichier du paquet | Correction | Pourquoi |
|---|---|---|
| `android/build.gradle` | Ajout de `namespace` | Exigé par Android Gradle Plugin 8 |
| `android/src/main/AndroidManifest.xml` | Retrait de `package="…"` | Refusé par Android Gradle Plugin 8 |
| `FlutterBluetoothSerialPlugin.java` | Adaptateur Bluetooth initialisé dans `onAttachedToEngine` (contexte application) ; `activity.runOnUiThread` remplacé par un `Handler` sur le fil principal | Sans ça, le Bluetooth est indisponible (`bluetooth_unavailable`) et la connexion plante dans le **service de premier plan**, qui n'a pas d'activité |

Pour régénérer le correctif après une modification du paquet dans le cache local :
```bash
rm -rf /tmp/fbs /tmp/p && mkdir -p /tmp/fbs /tmp/p/a /tmp/p/b \
  && curl -sL https://pub.dev/api/archives/flutter_bluetooth_serial-0.4.0.tar.gz | tar xz -C /tmp/fbs \
  && cp -r /tmp/fbs/android /tmp/p/a/ \
  && cp -r ~/.pub-cache/hosted/pub.dev/flutter_bluetooth_serial-0.4.0/android /tmp/p/b/ \
  && (cd /tmp/p && diff -ru a/android b/android > "$OLDPWD/ci/flutter_bluetooth_serial.patch"; true)
```

---

## Publier une nouvelle version

```bash
git add -A && git commit -m "..." && git tag v0.1.4 && git push && git push --tags
```

Le workflow `.github/workflows/build-apk.yml` :
1. installe Java 17 et Flutter 3.24.5 ;
2. reconstitue la clé de signature depuis les secrets ;
3. `flutter pub get` puis applique le correctif de `flutter_bluetooth_serial` ;
4. `flutter build apk --release` avec :
   - `--build-name` = le tag sans le `v` (ex. `0.1.4`) ;
   - `--build-number` = le numéro du build (le `versionCode` augmente toujours, condition pour qu'Android accepte la mise à jour) ;
5. publie `INTC-Bridge-x.y.z.apk` dans les **Releases**.

### Signature

| Secret GitHub | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Fichier `intc-bridge-release.jks` encodé en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Mot de passe du keystore (alias `intc_bridge`) |

> ⚠️ **La clé de signature est irremplaçable.** Sans elle (et son mot de passe), aucune mise à jour ne pourra être installée sur les téléphones existants : il faudrait désinstaller l'application partout. La conserver hors du dépôt, avec une sauvegarde.

La configuration Gradle (`android/app/build.gradle`) lit `KEYSTORE_PATH` et `KEYSTORE_PASSWORD` ; en leur absence (build local), l'APK est signé en debug.

---

## Structure du projet

```
intc_bridge_android/
├── lib/
│   ├── main.dart                              # jeton créé avant le service, autorisations
│   ├── core/
│   │   ├── constants/app_constants.dart       # port 8080, notification
│   │   ├── models/                            # PrinterConfig, PrintJob
│   │   └── services/
│   │       ├── http_server_service.dart       # /health, /print, /rawprint, CORS, jeton
│   │       ├── token_service.dart             # génération / vérification du jeton
│   │       ├── bluetooth_service.dart         # connexion à la demande + file d'impression
│   │       ├── wifi_printer_service.dart      # impression réseau (port 9100)
│   │       ├── escpos_service.dart            # mise en forme des tickets (/print)
│   │       └── config_service.dart            # configuration (SharedPreferences)
│   └── features/
│       ├── config/config_screen.dart          # écran de configuration + test
│       └── print_server/print_server_service.dart  # service de premier plan
├── android/app/src/main/AndroidManifest.xml   # permissions, service connectedDevice, démarrage auto
├── ci/flutter_bluetooth_serial.patch          # correctif du paquet Bluetooth
└── .github/workflows/build-apk.yml
```

---

## Projets liés

- [`Gitjaphet/product_barcode_print_intc`](https://github.com/Gitjaphet/product_barcode_print_intc) — module Odoo qui envoie les impressions au pont.
- [`Gitjaphet/intc_print_bridge`](https://github.com/Gitjaphet/intc_print_bridge) — même pont pour **PC Windows**.
