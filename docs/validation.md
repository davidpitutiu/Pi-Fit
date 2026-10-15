# Verificarea Pi Fit 0.2.0

Verificări efectuate la 15 octombrie 2026 în mediul cloud Linux.

| Verificare | Rezultat |
| --- | --- |
| `bash scripts/setup_cloud.sh` | Reexecutare reușită: Flutter fixat, dependențe din lockfile, Node 22, JDK/Android SDK și CMake 3.22.1 |
| `flutter analyze` | Fără probleme |
| `flutter test` | 130 teste trecute; verificare suplimentară a navigației după corectarea contrastului filtrelor |
| Teste backend Node/TypeScript | 11 teste trecute, compilare TypeScript reușită |
| Teste helper configurație Firebase | 4 teste Python trecute |
| Catalog extern | `python3 scripts/import_exercise_catalog.py --check` verifică toate cele 876 de înregistrări din snapshot |
| Web release | Compilat cu resursele de randare locale |
| Android release, split ABI | Compilat pentru ARM64, ARMv7 și x86_64; variantele de telefon sunt în `downloads/` |
| APK Android | Pachet `com.pifit.app`, versiune 0.2.0, minSdk 26/targetSdk 36; semnătură verificată; iconița notificărilor păstrată după resource shrinking |
| Chromium, 390 × 844 | Prima pagină, light/dark, bibliotecă + căutare, profil și progres cu istoric izolat; revenire la modul local când SDK-ul Web este inaccesibil |

Testele acoperă seturi bifate versus planificate, modificările live, eligibilitatea
estimării Epley, formulele scorului, limite calendaristice, streak, perioadele de
grafic și selecția datelor, căutarea/filtrele în timpul antrenamentului, persistența,
programarea bulk, preferințele sportive și conversația Coach. Sunt verificate și
schimbări de cont în timpul încărcării, autentificării, restaurării și permisiunilor
pentru remindere, precum și izolarea rezultatelor Health întârziate.

## Firebase și AI

Configurațiile publice native au fost comparate cu fișierele furnizate. ID-ul Web
este cel furnizat de utilizator; cheia Web minimă este cheia publică Android a
aceluiași proiect, până la furnizarea exportului Web complet. Nu sunt incluse
credențiale de server. Inițializarea expirată nu poate activa tardiv un cont în
spatele jurnalului local.

Autentificarea reală a fost verificată separat prin API-ul Firebase: înregistrare,
login email/parolă, citire cont propriu și ștergere au răspuns HTTP 200. Conturile
temporare au fost șterse. Nu au fost trimise emailuri de verificare/resetare în
aceste verificări REST.

Firestore a refuzat citirea și scrierea propriului backup cu HTTP 403
`PERMISSION_DENIED` și mesajul „Missing or insufficient permissions.” Nu au fost
modificate reguli sau setări administrative. Cauza administrativă exactă nu a fost
confirmată; backendul de backup rămâne neverificat până la corectarea accesului.

În Chromium, politica de rețea a mediului a blocat descărcarea SDK-ului de la
`www.gstatic.com` (`ERR_TUNNEL_CONNECTION_FAILED`). Aplicația a revenit la modul
local după expirarea inițializării și interfața a rămas funcțională. Loginul prin
SDK în browser **nu** este validat de această rulare. Domeniul necesar este salvat
în draftul configurației mediului; salvarea draftului nu aplică politica live.

AI online necesită publicarea funcției, URL HTTPS și cheia furnizorului în Secret
Manager. Acestea nu sunt disponibile în mediul curent. Testele backendului folosesc
un furnizor simulat pentru dialog și nu demonstrează un răspuns OpenAI live.
Recomandările locale folosesc profilul și jurnalul real și sunt etichetate local.

## Telefon și capturi

Health Connect / HealthKit folosesc API-urile native reale, cu 9 teste automate
pentru permisiuni, citiri și izolare. Permisiunile și valorile provenite de la un
telefon nu au fost verificate aici. iOS nu este compilat sau semnat pe Linux.
Reminderele necesită verificare pe dispozitiv pentru livrare, refuzuri, restart și
schimbarea fusului orar. Vezi [verificările Health](health.md).

Capturile `progress-demo-*`, `charts-demo-*` și `workout-demo-*` folosesc un jurnal
fictiv, creat exclusiv într-un profil Chromium izolat pentru a arăta graficele.
Aplicația distribuită nu creează aceste sesiuni sau statistici. Capturile home și
bibliotecă arată starea fără sesiuni salvate. Mesajul temporar despre conexiune
reflectă blocarea SDK-ului în acest mediu, nu un login reușit.

APK-urile folosesc cheia debug a buildului anterior și permit actualizarea
aceleiași instalări. Sunt builduri de test, fără semnare pentru magazine. Integritatea
fișierelor publicate se verifică folosind `downloads/SHA256SUMS.txt`.
