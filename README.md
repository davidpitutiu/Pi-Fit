# Pi Fit ⚡

Aplicație Flutter pentru jurnalul de sală: design inspirat de iOS, Inter, accent verde electric `#C7FF3D`, light/dark/system. Cod comun Android, iOS și web pentru dezvoltare.

**[Descarcă Pi Fit pentru Android (ARM64, 21,5 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-arm64.apk)** · [Alte variante și checksumuri](downloads/README.md)

## Funcționalități implementate

- 64 de exerciții originale în română, cu pași, sfaturi, grupe musculare și echipament; căutare fără diacritice și filtre.
- 8 rutine (Push/Pull/Legs, Full Body, Upper/Lower, Glutes, Home), plus constructor de rutine cu seturi, repetări și greutăți.
- Antrenament liber sau din rutină: editare kg/repetări, bifare și adăugare/ștergere de seturi, cronometru de pauză, notițe la final.
- Salvare locală și reluarea sesiunii după repornire. Volumele și recordurile folosesc seturile finalizate, fără date demonstrative inventate.
- Calendar lunar, programare individuală sau bulk pe 1–12 săptămâni, zile și oră configurabile, evitarea duplicatelor, ștergerea sesiunilor.
- Remindere locale pe Android/iOS, permisiuni cerute la programare și mesaje pentru refuzuri. Notificările web nu sunt implementate. Android poate amâna reminderele în economisirea bateriei; iOS are o limită de notificări în așteptare.
- Istoric, detalii sesiune, grafice pe 8 săptămâni și recorduri per exercițiu.
- Profil, obiectiv, temă, export JSON în clipboard.
- Integrare Firebase Authentication email/parolă, înregistrare, verificare email, resetare parolă și backup/restaurare manuală în Firestore, după configurarea clientului.
- Pi Coach: endpoint AI autentificat, rezumat al antrenamentelor, limitare de cereri și cheie păstrată pe server. Fără endpoint, aplicația afișează explicit recomandări locale predefinite.

Aceasta este o primă versiune funcțională, nu paritate integrală cu Hevy. Feedul social, urmăritori, Apple Health/Health Connect, aplicația de ceas, abonamentele și un catalog video exhaustiv nu sunt implementate. Exercițiile sunt conținut original; nu sunt copiate din Hevy.

## Pornire

Flutter **3.47.7 / Dart 3.13.5**. În mediul cloud, SDK-ul este `/workspace/flutter-sdk`; `scripts/flutterw` gestionează directoarele cache fără să schimbe `HOME`.

```bash
cd /workspace/Pi-Fit
./scripts/flutterw pub get --enforce-lockfile
./scripts/flutterw analyze
./scripts/flutterw test
./scripts/flutterw run -d chrome
```

Pe calculatorul personal cu Flutter în PATH poți folosi comenzile `flutter` direct. Pentru Android: Java 17+, Android SDK API 36, acceptarea licențelor și emulator/dispozitiv. Pentru iOS: macOS, Xcode, CocoaPods și semnare Apple. Scaffoldingul folosește Android minSdk 24 și iOS 15.0.

```bash
flutter run -d <device-id>
flutter build apk --debug
# APK-uri de test optimizate, separate pe arhitecturi:
flutter build apk --release --split-per-abi --dart-define-from-file=firebase/client-config.local.json
# pe macOS, după configurarea semnării:
flutter build ios
```

Varianta ARM64 are aproximativ 21,5 MB, față de 171 MB pentru APK-ul debug universal.
Buildurile release folosesc momentan cheia de semnare debug și sunt destinate
testării; configurează semnarea proprie înainte de distribuția în magazin.

## Firebase — pi-fit-663f2

Proiectul țintă este configurat în `firebase/.firebaserc`. Înregistrează în Firebase aplicațiile Android și iOS cu ID-ul `com.pifit.app` și o aplicație web pentru verificările de dezvoltare. ID-ul proiectului singur nu permite autentificare sau acces la date.

1. Activează Authentication → Email/Password și creează baza Cloud Firestore.
2. Copiază `firebase/client-config.example.json` în `firebase/client-config.local.json` (ignorat de Git), înlocuiește valorile exemplu cu configurația **publică de client** a aplicațiilor tale.
3. Rulează aplicația cu acea configurație:

```bash
flutter run --dart-define-from-file=firebase/client-config.local.json
```

Nu pune chei de service account sau cheia AI în fișierul client. Publicarea regulilor Firestore și a funcției AI se face separat, dintr-un cont autorizat; vezi [firebase/README.md](firebase/README.md).

Backupul este explicit/manual și înlocuiește documentul curent al contului. Datele locale aparțin profilului dispozitivului și rămân după deconectare. Nu există încă sincronizare automată sau combinare de conflicte între dispozitive. Exportă datele înainte de restaurarea unui backup. Fișierele locale de recuperare a datelor invalide nu sunt afișate ca sesiuni valide.

## Verificări

```bash
./scripts/flutterw analyze
./scripts/flutterw test
./scripts/flutterw build web
cd firebase/functions
npm ci
npm test
```

Testele verifică integritatea bibliotecii, serializarea, calculul volumelor, persistența sesiunilor, programarea repetată fără duplicate și fluxuri de interfață. Backendul verifică autentificarea, validarea cererilor și limitarea utilizării. Testele locale nu certifică livrarea notificărilor pe telefon sau funcționarea proiectului Firebase încă neconfigurat.

Fontul Inter este distribuit sub SIL Open Font License, inclusă în `assets/fonts/OFL.txt`.

## Configurația mediului cloud

`bash scripts/setup_cloud.sh` reproduce instalarea Flutter fixată la commitul 3.47.7,
Node 22.23.3 și toolchainul Android/JDK, cu verificarea checksumurilor oficiale.
Folosește checkoutul existent; fiecare task cloud este deja izolat și nu necesită
un Git worktree separat. Nu include configurații private în scripturile de setup.

Capturi din aplicația rulată în Chromium: [Dark](docs/screenshots/home-dark.png),
[Light](docs/screenshots/home-light.png), [Antrenament](docs/screenshots/workout-dark.png).

Validare locală: analiza Flutter fără probleme, 35 de teste Flutter și 7 teste
backend trecute, build web și APK Android debug compilate. Configurațiile Android
și iOS pentru `pi-fit-663f2` au fost validate și sunt în fișierul local ignorat.
Autentificarea/Firestore live și livrarea notificărilor necesită încă verificare pe
dispozitiv. iOS nu a fost compilat pe acest host Linux. Pentru AI online este
necesară publicarea funcției și configurarea secretului pe server.
