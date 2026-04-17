# Terminal stanice — prava, admin i operater (arhiva dogovora)

## Dogovoreni model (važi kao cilj)

1. **Administrator** je **nositelj prava** nad konfiguracijom stanice / stranice: pri **kreiranju** (ili uređivanju) te stranice u admin dijelu sustava evidentira se **njegov identitet** — logika je da se **pokretanje** / vezanje terminala na tvrtku–pogon–stanicu **prati na admina** (tko je omogućio, tko je zapisao uređaj). To je **ovlaštenje konteksta** (ovaj PC smije raditi kao Stanica 1/2/3 za ovaj pogon).

2. **Za svaki unos podataka** na ekranu stanice mora biti **prijavljen korisnik** koji stvarno radi unos (operater). U zapisu u bazi ostaje **identitet tog korisnika** (npr. `createdByUid` / e-mail za audit) — **nema „anonimnog“ unosa** na razini zapisa ako želimo ispravan trag.

3. **Razdvajanje uloga**: admin **daje prava i veže terminal**; operater **odgovara za sadržaj unosa** u trenutku spremanja.

Ovaj model zadovoljava IATF/audit očekivanja: **tko je ovlastio** vs **tko je unio**.

---

## Raniji smjer (samo kiosk bez osobe) — napomena

Ideja „na PC-ju nema osobnog logina uopće“ zahtijeva **poseban terminalni identitet** u Firebaseu + izmjene pravila. **Dogovoreni model iznad** time **nije** „svi anonimni“, nego **admin za kontekst + operater po unosu** — što je usklađeno s vašim zadnjim uputama.

---

## Zašto danas mora postojati prijava

U Firestore pravilima (`maintenance_app/firestore.rules`) zapis u `production_operator_tracking` dozvoljen je samo ako je korisnik:

- prijavljen (`signedIn()`),
- **aktivan** (`isActiveUser()` — dokument `users/{uid}`),
- ima modul **production**,
- uloga je jedna od: admin, production_manager, supervisor, **production_operator**,
- `plantKey` na zapisu odgovara korisnikovom pogonu.

Zato aplikacija danas nakon prijave učitava `companyData` iz `users` + `companies`. **Bez toga** klijent ne smije zapisivati u Firestore.

---

## Ciljno tehničko ostvarenje (nadovezuje se na dogovor)

### 1. Admin — evidencija pri kreiranju stranice / terminala

- U admin konzoli (ili Cloud Function): zapis npr. `station_pages/{id}` ili `station_terminals/{id}` s poljima: `companyId`, `plantKey`, `stationNumber`, **`provisionedByUid`** / **`provisionedByEmail`**, vrijeme, opcionalno **deviceSecret** hash.
- **Log pri pokretanju** (ili pri prvom „unlocku“ terminala) može se vezati na **admin akciju** koja je stranicu kreirala (ili na servisni nalog ako ga koristite samo za vezanje uređaja).

### 2. Operater — obavezna prijava za unos

- Prije **Spremi** (ili pri ulasku u unos): **Firebase Auth** mora biti **operater** (ili druga uloga koju pravila dopuštaju za `production_operator_tracking`).
- U payloadu ostaje **`createdByUid` = operater** (kao danas u `ProductionOperatorTrackingService`).
- UX: brza prijava (QR bedž, PIN, zamjena korisnika) — vidi `PRODUCTION_STATION_OPERATIVE_UX.md`.

### 3. (Opcionalno) Pojednostavljeni prvi ekran

- Nakon što je uređaj **adminom vezan**, korisnik na startu može vidjeti samo **izbor stanice 1/2/3** bez ponovnog unosa tvrtke — **dok** za unos nije potreban drugi korak, i dalje vrijedi: **operater prijavljen pri spremanju**.

### 4. Firestore pravila

- I dalje: `signedIn()` + `isActiveUser()` + uloga koja smije pisati u `production_operator_tracking`.
- Ako se uvede **poseban terminalni token**, pravila se proširuju uz uvjet da **zapis i dalje sadrži stvarnog operatera** ili da se operater provjerava u istom requestu — **ne** čisti anonimni create bez operatera, ako slijede gornji dogovor.

---

## Što još nije u repou

- Cloud Function `registerStationTerminal` (ili ekvivalent).
- Kolekcija **registriranih stanica / tajni ključeva** u Firestoreu.
- Izmjena **Firestore pravila** za ulogu terminala.

Bez toga **ne možemo** ispravno ukloniti email/lozinku i i dalje zapisivati u `production_operator_tracking`.

---

## Poveznice

- Lokalni izbor „nakon prijave“ (email korisnika): `docs/STATION_LAUNCH.md` — to je **drugačiji** model (osobni nalog na tom PC-ju).
- Operativni UX: `../../maintenance_app/docs/architecture/PRODUCTION_STATION_OPERATIVE_UX.md` (relativno iz ovog repa prilagoditi put).
- **Shema stranice stanice u Firestoreu:** `docs/STATION_PAGES_FIRESTORE_SCHEMA.md` (`production_station_pages`).

---

## Sažetak za proizvod

| Pristup | Admin (prava / vezanje) | Operater pri unosu | Stanje |
|--------|-------------------------|---------------------|--------|
| Današnji | implicitno (korisnik u sustavu) | Da (`createdByUid`) | Radi |
| Cilj (dogovor) | **Evidencija admina** pri kreiranju stranice/terminala | **Obavezno** za svaki zapis | Djelomično UI + treba admin/terminal model u bazi |

Sljedeći inženjerski korak: model u Firestoreu za **stranicu/terminal** (s `provisionedBy…`) + eventualno Callable za vezanje uređaja; Flutter: prvi ekran stanice + **bez spremanja dok operater nije prijavljen**.
