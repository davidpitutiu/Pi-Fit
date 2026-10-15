# Firebase și antrenorul AI Pi Fit

Aplicația funcționează local fără Firebase. În acest mod nu creează conturi simulate,
nu pretinde că a sincronizat date și afișează recomandările fără server ca
„Sugestie locală”. Autentificarea, backupul cloud și conversațiile AI reale necesită
configurarea unui proiect propriu. Codul de aici pregătește integrarea; nu publică
automat servicii și nu conține chei secrete.

Proiectul selectat în `.firebaserc` este `pi-fit-663f2`. Bindingul ADC din mediul
de dezvoltare a fost verificat fără expunerea valorilor: este prezent, dar nu
conține câmpurile necesare unui credential Google utilizabil. Nu s-au putut citi
aplicațiile înregistrate în proiect și nu s-au făcut modificări la distanță.
Configurația publică a aplicațiilor poate fi copiată din Firebase Console; pentru
operațiuni administrative configurează autentificarea CLI sau ADC în afara codului.

## 1. Proiect Firebase și conturi

1. Creează un proiect în Firebase Console și înregistrează aplicațiile Android și
   iOS cu identificatorul `com.pifit.app`. Pentru previewul în browser, înregistrează
   și o aplicație web. Schimbă identificatorii nativi înainte de înregistrare dacă
   aplicația va fi publicată cu alt nume de pachet.
2. În **Authentication → Sign-in method**, activează **Email/Password**. În
   **Settings → Authorized domains**, adaugă domeniul previewului web când este
   necesar. Autentificarea din aplicație folosește Firebase Auth; parola nu este
   salvată în preferințe sau în Firestore.
3. Creează baza **Cloud Firestore**, ideal în aceeași regiune europeană ca funcția.
   Publică regulile din `firestore.rules` înainte să folosești conturi reale. Regulile
   permit acces numai utilizatorului autentificat la propriul profil și backup,
   iar contoarele interne ale AI-ului sunt inaccesibile clientului.
4. Copiază `firebase/client-config.example.json` în
   `firebase/client-config.local.json` și înlocuiește toate valorile `replace-with`.
   Fișierul local este ignorat de Git. Configurația Firebase a clientului identifică
   proiectul și nu înlocuiește regulile de securitate. Nu adăuga cheia OpenAI aici.
5. Rulează din rădăcina proiectului:

   ```sh
   flutter pub get
   flutter run --dart-define-from-file=firebase/client-config.local.json
   ```

Pentru un singur target poți folosi `FIREBASE_APP_ID` în locul variantelor
`FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID` și `FIREBASE_WEB_APP_ID`.
`FIREBASE_AUTH_DOMAIN` și `FIREBASE_STORAGE_BUCKET` sunt opționale. Pe iOS,
`FIREBASE_IOS_BUNDLE_ID` trebuie să corespundă proiectului Xcode. Inițializarea
folosește explicit `FirebaseOptions`; un fișier cu secrete de server nu este necesar.

Cheile publice de client pot fi diferite și restricționate per platformă. Folosește
`FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_API_KEY`, `FIREBASE_WEB_API_KEY`, sau cheia
comună `FIREBASE_API_KEY` ca fallback. Pentru fișierele descărcate din consolă,
poți genera configurația locală fără să copiezi manual câmpurile:

```sh
python3 scripts/configure_firebase.py --android /cale/google-services.json --ios /cale/GoogleService-Info.plist
# opțional, configurația web salvată ca obiect JSON:
python3 scripts/configure_firebase.py --web /cale/firebase-web.json
```

Rulează comenzile de conversie din rădăcina repository-ului. Helperul acceptă numai
proiectul `pi-fit-663f2`, verifică identificatorii și refuză fișierele service account.

Backupul este un snapshot JSON la `users/{uid}/backups/current`, cu timestamp de
server și versiune de schemă. Este potrivit pentru uz personal; Firestore limitează
un document la 1 MiB. Restaurarea citește explicit de pe server și eșuează dacă
rețeaua lipsește, fără a prezenta un cache vechi ca versiune sincronizată. Datele
locale ale dispozitivului și backupul nu sunt un sistem colaborativ de sincronizare
în timp real. Verifică datele înainte de a restaura un snapshot.

## 2. Server AI autentificat

Backendul TypeScript rulează pe Firebase Functions generația a doua, Node.js 22.
Necesită un proiect Firebase cu planul de facturare adecvat și o cheie OpenAI
validă. Costurile serverului și ale modelului sunt suportate de proprietarul
proiectului. Configurează bugete și alerte de cost în consolele furnizorilor.

Pentru pregătire și verificări locale:

```sh
# În mediul cloud Linux, din rădăcina proiectului:
bash scripts/setup_node.sh
export PATH="/workspace/node22/bin:$PATH"
cd firebase/functions
npm ci --cache /workspace/.npm-cache --no-audit --no-fund
npm test
```

Helperul instalează Node `22.23.3` în afara checkoutului din distribuția oficială
Node.js, după verificarea SHA-256 cu lista oficială descărcată prin HTTPS.
Pe calculatorul propriu, folosește Node 22 (`functions/.nvmrc`) și `npm ci`.

Pentru publicare, folosește Firebase CLI autentificat cu contul proprietarului
proiectului. Comenzile următoare modifică proiectul cloud și se execută numai când
ești pregătit să publici:

```sh
cd firebase
firebase functions:secrets:set OPENAI_API_KEY --project YOUR_PROJECT_ID
firebase deploy --only firestore:rules,functions:coach --project YOUR_PROJECT_ID
```

CLI solicită cheia în siguranță și o salvează în Secret Manager. Nu o introduce în
chat, cod, `--dart-define` sau în aplicație. La deploy poți configura:

| Parametru server | Valoare implicită | Scop |
| --- | --- | --- |
| `AI_MODEL` | `gpt-4.1-mini` | Model OpenAI compatibil cu Responses API |
| `ALLOWED_ORIGINS` | gol | Originile web permise, separate prin virgulă, fără slash final |
| `REQUIRE_APP_CHECK` | `false` | Solicită și verifică un token App Check |

Aplicațiile mobile nu trimit `Origin`. Previewul web necesită originile exacte în
`ALLOWED_ORIGINS`, de exemplu `https://preview.example.com`. Nu folosi `*`.
Pune URL-ul HTTPS al funcției `coach` în `AI_COACH_URL` din configurația clientului
și reconstruiește aplicația. Funcția se află în `europe-west1`.

Clientul trimite numai mesajul, contextul antrenamentelor și un ID token Firebase.
Serverul verifică tokenul, respinge conturile anonime, limitează fiecare utilizator
la 10 cereri/minut și 100/24 ore prin tranzacții Firestore și validează dimensiunile
inputului. Nu expune cheia furnizorului și nu acceptă modelul ales de client.
Mesajele și tokenurile nu sunt logate; cererea OpenAI setează `store: false`.
Contextul este totuși transmis furnizorului pentru generarea răspunsului; configurează
politica de confidențialitate și informează utilizatorii înaintea lansării publice.

Verificarea App Check există pe server, dar este dezactivată implicit. Pentru a o
activa, înregistrează întâi aplicațiile în Firebase App Check, integrează SDK-ul
`firebase_app_check` în client și transmite tokenul în `X-Firebase-AppCheck` din
`CoachService`. Clientul actual transmite doar ID tokenul Auth; activarea prematură
a parametrului va respinge toate conversațiile. Verifică și protecția împotriva
abuzului înaintea unei lansări publice: limita pe utilizator nu este o limită
globală de cost și nu împiedică înregistrarea mai multor conturi.

## 3. Remindere pe telefon

`NotificationService` folosește fusul orar real al dispozitivului, cere permisiunea
la primul reminder și programează notificări locale. Reminderele nu sunt push de
server; telefonul nu are nevoie de Firebase pentru ele. Browserul și desktopul
afișează explicit că această funcție necesită Android sau iOS.

Pe Android sunt necesare permisiunea `POST_NOTIFICATIONS`, permisiunea
`RECEIVE_BOOT_COMPLETED` și receiver-ele pluginului pentru reprogramare după restart.
Gradle trebuie să activeze core library desugaring și `desugar_jdk_libs:2.1.4`.
Programarea utilizează `inexactAllowWhileIdle`; economisirea bateriei poate întârzia
livrarea și nu este cerută permisiunea specială pentru alarme exacte.

Pe iOS activează permisiunile din prompt și păstrează delegatul
`UNUserNotificationCenter` în AppDelegate. iOS limitează notificările în așteptare;
serviciul păstrează o limită conservatoare de 60, inclusiv la programarea bulk.
Reminderele trebuie testate pe dispozitive reale: permisiuni acceptate/refuzate,
aplicație în fundal, restart Android, schimbarea fusului orar și anularea unei
sesiuni. Pentru fus orar schimbat după programare, redeschide aplicația și
reprogramează reminderele la ora locală dorită.

## 4. Verificare înainte de lansare

- Cont nou, verificare email, login, logout și resetarea parolei pe Firebase real.
- Backup și restaurare cu două conturi: un cont nu poate accesa backupul celuilalt.
- AI cu un ID token valid; respingerea cererilor fără token și a originilor web
  nepermise; răspuns 429 când limita este depășită.
- Remindere Android/iOS pe telefon real și comportament corect la permisiuni refuzate.

Aceste verificări de integrare au nevoie de un proiect Firebase și dispozitivele
corespunzătoare. Testele locale ale backendului verifică inputul, extragerea
răspunsului și limitele, fără să contacteze OpenAI sau să folosească secrete.
