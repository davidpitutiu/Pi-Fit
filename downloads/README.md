# Pi Fit — APK Android de test

- [Descarcă pentru Android ARM64 (majoritatea telefoanelor, 53,8 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-arm64.apk)
- [Descarcă pentru Android ARMv7 (32 de biți, 51,5 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-armv7.apk)

Versiune: **0.2.0**, identificator `com.pifit.app`, Android 8.0/API 26 sau mai nou.
Builduri release optimizate, semnate cu aceeași cheie debug ca versiunea 0.1.0,
destinate testării. Dimensiunea include aproximativ 28 MiB de fotografii offline.

Include 878 de exerciții, căutare și filtre în antrenament, statistici interactive
pe 7/28/90 de zile, progres live și streak săptămânal. Health Connect citește
activitatea după conectare explicită pe un dispozitiv compatibil; integrarea
necesită verificare cu sursele și permisiunile telefonului.

Configurațiile publice Firebase pentru `pi-fit-663f2` sunt incluse. Loginul
email/parolă a fost verificat pe proiectul real. Backupul Firestore este încă
refuzat de Firestore cu `PERMISSION_DENIED`, iar AI online necesită publicarea backendului și
configurarea cheii pe server. Recomandările locale sunt disponibile între timp.
Nu sunt incluse chei private sau credențiale de server.

Verificarea integrității după descărcare, în folderul care conține APK-urile:

```bash
sha256sum -c SHA256SUMS.txt
```

În Windows PowerShell:

```powershell
Get-FileHash .\Pi-Fit-Android-arm64.apk -Algorithm SHA256
```

Compară rezultatul cu [SHA256SUMS.txt](SHA256SUMS.txt).
Pentru reconstruire și limitările integrărilor, vezi [instrucțiunile proiectului](../README.md)
și [validarea versiunii](../docs/validation.md).
