# Pi Fit — APK Android de test

- [Descarcă pentru Android ARM64 (majoritatea telefoanelor, aproximativ 21,5 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-arm64.apk)
- [Descarcă pentru Android ARMv7 (telefoane pe 32 de biți, aproximativ 19 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-armv7.apk)

Versiune: **0.1.0**, identificator `com.pifit.app`, Android 7.0/API 24 sau mai nou.
Aceste builduri optimizate sunt semnate cu cheia debug și sunt pentru testare.
Configurația Firebase Android pentru `pi-fit-663f2` este inclusă; funcționarea
serviciilor depinde de activarea Authentication/Firestore și publicarea regulilor.
Cheile private și fișierele locale de configurare nu sunt incluse în repository.

Verificarea integrității după descărcare:

```bash
sha256sum -c SHA256SUMS.txt
```

Pentru reconstruire, vezi [instrucțiunile proiectului](../README.md).
