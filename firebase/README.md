# Firebase și antrenorul AI Pi Fit

Aplicația funcționează local fără Firebase. În acest mod nu creează conturi simulate,
nu pretinde că a sincronizat date și afișează recomandările fără server ca
„Sugestie locală”. Autentificarea, backupul cloud și conversațiile AI reale necesită
configurarea unui proiect propriu. Codul de aici pregătește integrarea; nu publică
automat servicii și nu conține chei secrete.

Proiectul selectat în `.firebaserc` este `pi-fit-663f2`. Configurațiile publice
Android și iOS furnizate sunt incluse în repository, împreună cu opțiunile implicite
pentru Flutter din `lib/firebase_options.dart`. Pornirea obișnuită nu mai cere
fișiere locale sau `--dart-define`.

ID-ul aplicației Web furnizat este `1:942783822335:web:52e8ccf86e545c2ed28fca`.
Opțiunile Web folosesc acest ID, metadatele proiectului și cheia publică de client
Android a aceluiași proiect. Acesta este un set minim de opțiuni pentru SDK, nu un
obiect `firebaseConfig` exportat din consolă. Dacă cheia Web are alte restricții,
înlocuiește-o cu cheia publică Web din consolă folosind helperul de mai jos.
SDK-ul Web se descarcă de la `www.gstatic.com`; fără acces, aplicația revine la
modul local după expirarea inițializării.

Validare reală, 15 octombrie 2026: înregistrarea unui cont temporar, loginul cu
email/parolă, citirea propriului cont și ștergerea lui au răspuns HTTP 200. Contul
temporar a fost eliminat; nu au fost trimise emailuri. Scrierea unui backup mic
numai în spațiul acelui cont a fost refuzată de Firestore cu HTTP 403
`PERMISSION_DENIED`. Backupul cloud nu este încă validat. Verifică în consola
Firebase regulile publicate pentru `users/{uid}/backups/current` și publică regulile
din acest repository înainte de a folosi backupul. Nu înlocui regulile cu acces
public. Cauza exactă a refuzului nu a putut fi confirmată fără acces administrativ;
mesajul serverului este „Missing or insufficient permissions.” Nu s-au schimbat
setările administrative ale proiectului.

Bindingul ADC din mediul de dezvoltare este prezent, dar nu conține câmpurile
necesare unui credential Google utilizabil. Pentru operațiuni administrative,
configurează autentificarea CLI sau ADC în afara codului.

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
4. Pentru proiectul Pi Fit existent, configurația clientului este deja inclusă.
   Dacă folosești altă configurație, `firebase/client-config.local.json` rămâne o
   suprascriere opțională, ignorată de Git. Nu adăuga cheia OpenAI aici.
5. Rulează din rădăcina proiectului:

   ```sh
   flutter pub get --enforce-lockfile
   flutter run -d chrome
   ```

Pentru un singur target poți folosi `FIREBASE_APP_ID` în locul variantelor
`FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID` și `FIREBASE_WEB_APP_ID`.
`FIREBASE_AUTH_DOMAIN` și `FIREBASE_STORAGE_BUCKET` sunt opționale. Pe iOS,
`FIREBASE_IOS_BUNDLE_ID` trebuie să corespundă proiectului Xcode. Inițializarea
folosește explicit `FirebaseOptions`; un fișier cu secrete de server nu este necesar.

Cheile publice de client pot fi diferite și restricționate per platformă. Folosește
`FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_API_KEY`, `FIREBASE_WEB_API_KEY`, sau cheia
comună `FIREBASE_API_KEY` ca fallback. Pentru fișierele descărcate din consolă,
poți regenera configurația inclusă și suprascrierea locală fără să copiezi manual câmpurile:

```sh
# Regenerare din fișierele publice deja incluse:
python scripts/configure_firebase.py
# Înlocuire din fișiere descărcate recent:
python scripts/configure_firebase.py --android "firebase/google-services.json" --ios "firebase/GoogleService-Info.plist"
# Înlocuiește opțiunile Web minime cu obiectul public exportat din consolă:
python scripts/configure_firebase.py --web "firebase/firebase-web.json"
```

Rulează din rădăcina repository-ului. Helperul actualizează `lib/firebase_options.dart`,
fișierele native, `firebase/web-config.json` și fișierul opțional local de defines.
Acceptă numai proiectul `pi-fit-663f2`, verifică identificatorii și refuză
credențiale de server înainte de a modifica fișiere. Nu ai nevoie să rulezi
helperul pentru pornirea obișnuită; configurația este deja inclusă.
Pe Windows fără runtime Python, `py install default` instalează runtime-ul;
managerul Python singur nu poate executa scripturi.

Backupul este un snapshot JSON la `users/{uid}/backups/current`, cu timestamp de
server și versiune de schemă. Este potrivit pentru uz personal; Firestore limitează
un document la 1 MiB. Restaurarea citește explicit de pe server și eșuează dacă
rețeaua lipsește, fără a prezenta un cache vechi ca versiune sincronizată. Datele
locale ale dispozitivului și backupul nu sunt un sistem colaborativ de sincronizare
în timp real. Verifică datele înainte de a restaura un snapshot.

Ecranul Cont include creare cont, login, resetarea parolei, retrimiterea verificării
emailului și ștergerea contului cu parola curentă. Ștergerea reautentifică întâi
utilizatorul, apoi șterge backupul/profilul cloud și contul Auth. Dacă Firestore
refuză curățarea, contul rămâne activ pentru a putea reîncerca. Datele locale ale
dispozitivului se păstrează și pot fi gestionate separat.

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
| `AI_MODEL` | `gpt-4.1` | Model OpenAI compatibil cu Responses API; poate fi configurat pe server |
| `ALLOWED_ORIGINS` | gol | Originile web permise, separate prin virgulă, fără slash final |
| `REQUIRE_APP_CHECK` | `false` | Solicită și verifică un token App Check |

Aplicațiile mobile nu trimit `Origin`. Previewul web necesită originile exacte în
`ALLOWED_ORIGINS`, de exemplu `https://preview.example.com`. Nu folosi `*`.
Pune URL-ul HTTPS al funcției `coach` în `AI_COACH_URL` din configurația clientului
și reconstruiește aplicația. Funcția se află în `europe-west1`.

Cu acordul explicit din profil și un cont autentificat, clientul trimite mesajul,
preferințele sportive, statistici pe 28 de zile, până la 8 antrenamente recente,
programările viitoare și conversația recentă, împreună cu un ID token Firebase.
Contextul JSON este limitat la 24.000 de caractere, iar conversația la 12 mesaje
de utilizator/asistent, 3.000 de caractere fiecare și 18.000 în total. Serverul
respinge roluri precum `system`, câmpuri suplimentare și depășirea limitelor.
Serverul verifică tokenul, respinge conturile anonime, limitează fiecare utilizator
la 10 cereri/minut și 100/24 ore prin tranzacții Firestore și validează dimensiunile
inputului. Nu expune cheia furnizorului și nu acceptă modelul ales de client.
Mesajele și tokenurile nu sunt logate; cererea OpenAI setează `store: false`.
Contextul este totuși transmis furnizorului pentru generarea răspunsului; configurează
politica de confidențialitate și informează utilizatorii înaintea lansării publice.
Fără acord sau fără backend configurat, recomandările locale folosesc profilul și
seturile disponibile pe dispozitiv și sunt etichetate clar. Nu simulează un model
AI și nu programează antrenamente în urma unui mesaj. Recomandările de progres
compară seturile finalizate din ședințe reale; nu inventează recorduri sau greutăți.

AI-ul online nu este încă activat în proiect: mediul nu are o cheie de furnizor
utilizabilă și configurația clientului nu are `AI_COACH_URL`. Backendul include
testarea unui dialog cu întrebări ulterioare prin furnizor simulat; aceasta nu
înlocuiește verificarea serviciului publicat cu un cont real.

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
