# Pi Fit ⚡

Aplicație Flutter pentru jurnalul de sală: suprafețe translucide cu blur, design inspirat de iOS, Inter, accent verde electric `#C7FF3D`, light/dark/system. Cod comun Android, iOS și web pentru dezvoltare. Versiunea curentă: **0.2.0**.

**[Descarcă Pi Fit pentru Android (ARM64)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-arm64.apk)** · [Alte variante și checksumuri](downloads/README.md)

## Funcționalități implementate

- **878 de exerciții**: toate cele 876 de înregistrări din baza externă deschisă [free-exercise-db](https://github.com/yuhonas/free-exercise-db) plus 2 mișcări Pi Fit. Catalogul complet rămâne disponibil offline. Căutare în română/engleză fără diacritice, filtre pentru grupă musculară, echipament, nivel și categorie, sortare și favorite persistente.
- Același selector cu căutare și filtre este disponibil în timpul antrenamentului și la construirea rutinelor. Selecția multiplă este păstrată când schimbi căutarea sau filtrele.
- 430 de imagini incluse offline pentru 216 exerciții; fotografiile celorlalte 659 de mișcări se încarcă la cerere și sunt păstrate în cache pe Android/iOS. Trei înregistrări din sursă nu au fotografii și sunt marcate corect. Galerii cu două poziții, pași și sfaturi; 218 exerciții au instrucțiuni în română, celelalte 660 păstrează instrucțiunile originale în engleză, indicate în interfață. [Sursă, licență și actualizare](docs/exercise-sources.md).
- 8 rutine (Push/Pull/Legs, Full Body, Upper/Lower, Glutes, Home), plus constructor de rutine cu seturi, repetări și greutăți.
- Antrenament liber sau din rutină: editare kg/repetări, bifare și adăugare/ștergere de seturi, cronometru de pauză, notițe la final. Indicatorii live folosesc seturile bifate și compară progresul aceluiași exercițiu cu istoricul propriu.
- Salvare locală și reluarea sesiunii după repornire. Volumele și recordurile folosesc seturile finalizate, fără date demonstrative inventate.
- Calendar lunar, programare individuală sau bulk pe 1–12 săptămâni, zile și oră configurabile, evitarea duplicatelor, ștergerea sesiunilor.
- Remindere locale pe Android/iOS, permisiuni cerute la programare și mesaje pentru refuzuri. Notificările web nu sunt implementate. Android poate amâna reminderele în economisirea bateriei; iOS are o limită de notificări în așteptare.
- Tab dedicat pentru progres: grafice pe 7/28/90 de zile pentru volum, seturi, sesiuni și durata înregistrată, evoluția fiecărui exercițiu, distribuția seturilor pe grupe și recorduri. Estimările 1RM Epley sunt etichetate ca estimări.
- Streak săptămânal raportat la ținta de zile active din profil, cu seria curentă și recordul personal; zilele de pauză sunt compatibile cu obiectivul.
- [Apple Health și Health Connect](docs/health.md): conectare explicită și citirea activității recente pe dispozitiv, cu permisiuni limitate. Aceste date rămân separate de scorul jurnalului de antrenament.
- Scor de consecvență cu formula și datele afișate: 70% atingerea țintei de zile active în 28 de zile + 30% săptămâni în care ținta a fost atinsă. Mai multe sesiuni în aceeași zi nu aduc puncte suplimentare. Nu este un scor medical; lipsa datelor este afișată explicit.
- Tab de profil și acces direct la login/signup. Profil sportiv: obiectiv, experiență, zile/săptămână, durată, echipament, zile preferate, vârstă, înălțime, greutate și limitări opționale. Temă, export JSON, import explicit al jurnalului local în cont, verificare email și ștergere cont cu reautentificare.
- Integrare Firebase Authentication email/parolă, înregistrare, verificare email, resetare parolă și backup/restaurare manuală în Firestore. Configurațiile publice Android/iOS/Web pentru proiectul ales sunt incluse; Firestore necesită reguli publicate corect.
- Pi Coach: profil și istoric detaliat, conversație cu ultimele 12 mesaje, endpoint AI autentificat, limitare de cereri și cheie păstrată pe server. Trimiterea datelor cere consimțământ explicit. Fără endpoint, recomandările locale sunt adaptate obiectivului, programului, echipamentului, limitărilor și seturilor reale, etichetate clar. Contextul local cu limitări nu este trimis automat serverului.

Aplicația nu are încă paritate integrală cu Hevy. Feedul social, urmăritorii, aplicația de ceas, abonamentele și un catalog video exhaustiv nu sunt implementate. Catalogul extern este distribuit conform licenței sursei și nu este extras din Hevy; baza internă utilizată de Hevy nu este confirmată.

## Pornire

Flutter **3.47.7 / Dart 3.13.5**.

### Windows — PowerShell

Instalează [SDK-ul Flutter pentru Windows](https://docs.flutter.dev/install/manual)
și adaugă folderul `flutter\bin` în PATH. După modificarea PATH, redeschide
PowerShell și intră în folderul proiectului. Rulează comenzile direct:

```powershell
flutter --version
flutter doctor
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d chrome
```

`scripts/flutterw` este un script Bash pentru mediul cloud Linux. În PowerShell,
executarea lui afișează dialogul „Select an app to open flutterw”; închide dialogul
și folosește comenzile `flutter` de mai sus. Dacă `flutter` nu este recunoscut,
verifică instalarea SDK-ului și PATH înainte să continui. Pentru verificarea în
Chrome este suficient toolchainul web; Android Studio este necesar pentru dezvoltarea
Android, iar iOS se compilează pe macOS.

Configurația publică Firebase pentru Pi Fit este inclusă. Comanda `flutter run -d chrome`
nu mai necesită copierea unui fișier local. Pentru alt proiect sau un endpoint AI,
poți suprascrie configurația prin `--dart-define-from-file`; vezi
[Firebase](firebase/README.md). SDK-ul web Firebase necesită acces la `www.gstatic.com`.

### Mediul cloud Linux

SDK-ul este `/workspace/flutter-sdk`; `scripts/flutterw` gestionează directoarele
cache fără să schimbe `HOME`.

```bash
cd /workspace/Pi-Fit
./scripts/flutterw pub get --enforce-lockfile
./scripts/flutterw analyze
./scripts/flutterw test
./scripts/flutterw run -d chrome
```

### Rulare și builduri mobile

Pe calculatorul personal folosește comenzile `flutter` direct. Pentru Android:
Java 17+, Android SDK API 36, acceptarea licențelor și emulator/dispozitiv.
Pentru iOS: macOS, Xcode, CocoaPods și semnare Apple. Scaffoldingul folosește
Android minSdk 26 (Android 8.0) și iOS 15.0. Health Connect necesită un dispozitiv compatibil și serviciul instalat/activat.

```bash
flutter run -d <device-id>
flutter build apk --debug
# APK-uri de test optimizate, separate pe arhitecturi:
flutter build apk --release --split-per-abi
# pe macOS, după configurarea semnării:
flutter build ios
```

APK-urile optimizate conțin acum și biblioteca foto offline; dimensiunile exacte sunt în `downloads/README.md`.
Buildurile release folosesc momentan cheia de semnare debug și sunt destinate
testării; configurează semnarea proprie înainte de distribuția în magazin.

## Firebase — pi-fit-663f2

Configurațiile publice de client sunt incluse în `lib/firebase_options.dart`,
`android/app/google-services.json` și `ios/Runner/GoogleService-Info.plist`.
Proiect: `pi-fit-663f2`; identificator Android/iOS: `com.pifit.app`.
Nu mai trebuie să creezi `firebase/client-config.local.json` pentru pornirea obișnuită.

```powershell
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Nu pune chei de service account sau cheia AI în configurația clientului.
Publicarea regulilor Firestore și a funcției AI se face separat, dintr-un cont
autorizat; vezi [firebase/README.md](firebase/README.md).

Backupul este explicit/manual și înlocuiește documentul curent al contului. Fiecare utilizator are un jurnal local separat, iar profilul fără cont rămâne păstrat separat. La login nu sunt amestecate automat datele; poți folosi „Importă jurnalul local” pentru a adăuga explicit antrenamentele, rutinele, calendarul și favoritele în cont. Importul păstrează copia locală și evită duplicatele. Nu există încă sincronizare automată sau combinare de conflicte între dispozitive. Exportă datele înainte de restaurarea unui backup. Fișierele locale de recuperare a datelor invalide nu sunt afișate ca sesiuni valide.

Autentificarea email/parolă a fost verificată pe proiectul real cu utilizatori temporari șterși după verificare. Firestore a refuzat citirea/scrierea backupului cu `PERMISSION_DENIED`; regula sau configurația administrativă trebuie corectată înainte de a considera backupul funcțional. Serviciul AI online mai trebuie publicat și configurat; vezi `firebase/README.md`.

## Verificări

```bash
flutter analyze
flutter test
flutter build web
cd firebase/functions
npm ci
npm test
```

Testele verifică integritatea bibliotecii, serializarea, calculul volumelor, persistența sesiunilor, programarea repetată fără duplicate și fluxuri de interfață. Backendul verifică autentificarea, validarea cererilor și limitarea utilizării. Testele locale nu certifică livrarea notificărilor sau permisiunile Health pe telefon. Autentificarea reală este verificată separat; backupul Firestore este încă refuzat de Firestore cu `PERMISSION_DENIED`.

Fontul Inter este distribuit sub SIL Open Font License, inclusă în `assets/fonts/OFL.txt`.

## Configurația mediului cloud

`bash scripts/setup_cloud.sh` reproduce instalarea Flutter fixată la commitul 3.47.7,
Node 22.23.3 și toolchainul Android/JDK, cu verificarea checksumurilor oficiale.
Folosește checkoutul existent; fiecare task cloud este deja izolat și nu necesită
un Git worktree separat. Nu include configurații private în scripturile de setup.

Capturi din aplicația rulată în Chromium (progresul și antrenamentul folosesc un profil demonstrativ izolat): [Dark](docs/screenshots/home-dark.png),
[Light](docs/screenshots/home-light.png), [Progres](docs/screenshots/progress-demo-dark.png), [Grafice](docs/screenshots/charts-demo-dark.png), [Antrenament](docs/screenshots/workout-demo-dark.png).

Validarea versiunii este documentată în [docs/validation.md](docs/validation.md).
iOS și permisiunile Health/reminderele necesită verificare pe dispozitiv; iOS nu
poate fi compilat pe acest host Linux. AI online necesită publicarea funcției și
configurarea secretului pe server.
