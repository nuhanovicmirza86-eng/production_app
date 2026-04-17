# Pokretanje aplikacije izravno na ekran stanice (Windows / desktop)

## Ideja

Na jednom PC-ju na podu želite: nakon **prijave** odmah **ekran stanice** (npr. Stanica 1 — pripremna), bez prolaska kroz dashboard.

To možete riješiti na **dva načina** (prioritet gore → dolje):

1. **Lokalna postavka na uređaju** — na ekranu **Prijava** izaberite „Način rada“ (sprema se u SharedPreferences na tom računalu). Ne treba poseban build.
2. **IT / build** — `OPERONIX_STATION` u **buildu** (vidi dolje). **Nadjačava** lokalnu postavku kad je postavljen.

---

## 1. Postavka na prijavi (preporučeno za pod)

Na **Prijava** → **Nakon prijave (ovaj uređaj)** → **Način rada**:

- Cijela aplikacija  
- Stanica 1 — pripremna  
- Stanica 2 — prva kontrola  
- Stanica 3 — završna kontrola  

Izbor se **sprema samo na tom računalu** (isti korisnik na drugom uređaju može imati drugačiji mod).

---

## 2. Build s `OPERONIX_STATION` (IT / zaključani PC)

**Jednokratnim buildom** (ili `flutter run`) s ugrađenim modom:

```text
OPERONIX_STATION=preparation
```

Vrijednost se učitava pri **kompilaciji** (`String.fromEnvironment`) — nije datoteka pored `.exe` niti runtime argument procesa.

### Podržane vrijednosti (`OPERONIX_STATION`)

| `OPERONIX_STATION` | Stanica |
|--------------------|--------|
| `preparation` ili `prep` | Pripremna (+ traka sesije) |
| `first_control` ili `first` | Prva kontrola |
| `final_control` ili `final` | Završna kontrola |

Prazno = klasičan ulaz u **Production dashboard**.

## Razvoj (`flutter run`)

```powershell
cd production_app
flutter run -d windows --dart-define=OPERONIX_STATION=preparation
```

## Release build (prečac na računalu)

1. Build s istim defineom:

```powershell
flutter build windows --dart-define=OPERONIX_STATION=preparation
```

2. Instaliraj / kopiraj `build\windows\x64\runner\Release\` na taj PC.
3. Prečac na `operonix_production.exe` — **ne treba** dodatni argument; mod je već u exe-u.

Za drugačiju stanicu na drugom PC-ju treba **drugi build** (ili drugi pipeline) s drugim `OPERONIX_STATION`.

## Zatvaranje stanice

Gumb **Zatvori stanicu** (X) otvara **cijelu aplikaciju** (dashboard) do sljedećeg pokretanja aplikacije. Pri sljedećem pokretanju opet vrijedi lokalna postavka / build.

## Prijava

Korisnik se i dalje **mora prijaviti** (Firebase) — Firestore pravila i audit zahtijevaju identitet. Brza QR prijava na stanicu dolazi kao sljedeća faza.

---

## Terminal **bez** osobnog emaila (kiosk)

Ako želite samo izbor **stanice 1/2/3** bez logina, to **nije** samo promjena Fluttera — vidi **`STATION_KIOSK_AUTH.md`** (Callable, pravila, identitet uređaja).
