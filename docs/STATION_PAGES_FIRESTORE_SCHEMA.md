# `production_station_pages` — Firestore shema (stranica stanice)

## Svrha

Jedan dokument = **jedna logička stanica** (1 / 2 / 3) unutar **tvrtke** i **pogona**, koju **administrator** kreira u konzoli. Služi za:

- **evidenciju tko je ovlastio** kontekst (`provisionedBy…`),
- vezanje na **fazu** (`phase`) usklađenu s `ProductionOperatorTrackingEntry`,
- kasnije: vezivanje **uređaja / terminala** na ovaj zapis (opcionalno).

**Unosi u `production_operator_tracking`** i dalje nose **`createdByUid` operatera** — ova kolekcija ne zamjenjuje audit unosa, nego **definira stanice** koje postoje u sustavu.

---

## Kolekcija

**`production_station_pages/{pageId}`**

- **`pageId`**: preporuka **deterministički** string, lak za traženje i upis pravila:

  ```text
  {companyId}__{plantKey}__{stationSlot}
  ```

  - `companyId` — kao u ostalim production dokumentima (npr. alfanumerički id).
  - `plantKey` — **escape** ako sadrži znakove koji nisu sigurni u id-u (npr. zamijeni `/` → `_` ili koristi hash); u praksi `plantKey` je često kratak kod.
  - `stationSlot` — `1` | `2` | `3` (broj u stringu).

  Primjer: `acme_corp__PLANT_A__1`

  Ako `plantKey` može biti predugačak, koristi **hash** segmenta: `companyId__sha1(plantKey)__1` — tada drži `plantKey` u polju ispod.

---

## Polja dokumenta

| Polje | Tip | Obavezno | Opis |
|--------|-----|----------|------|
| `companyId` | string | da | Izolacija tenant-a. |
| `plantKey` | string | da | Pogon; mora odgovarati `users.plantKey` operatera koji unosi. |
| `stationSlot` | int | da | `1`, `2` ili `3` — korisnički „Stanica 1/2/3“. |
| `phase` | string | da | Kanonska faza: `preparation` \| `first_control` \| `final_control` (ista konvencija kao `ProductionOperatorTrackingEntry`). |
| `displayName` | string | ne | Npr. „Stanica 1 — pripremna“ (lokalizirani prikaz). |
| `active` | bool | da | `false` = stranica onemogućena (terminal ne smije raditi). |
| `provisionedByUid` | string | da | **Admin** koji je kreirao / zadnje omogućio zapis (`request.auth.uid`). |
| `provisionedByEmail` | string | ne | Denormalizacija za pregled bez lookupa `users`. |
| `provisionedAt` | timestamp | da | Kad je admin prvi put potvrdio stranicu. |
| `updatedAt` | timestamp | da | Zadnja izmjena. |
| `updatedByUid` | string | ne | Tko je zadnji mijenjao (često isti admin). |
| `notes` | string | ne | Interna napomena admina. |

### Opcionalno (faza 2 — vezanje PC-ja)

| Polje | Tip | Opis |
|--------|-----|------|
| `deviceBindingHint` | string | Čitljiv naziv (npr. „PC linija 2“). |
| `deviceSecretHash` | string | Argon2/bcrypt hash tajnog ključa terminala; **nikad** plain secret u Firestoreu. |
| `lastDeviceHandshakeAt` | timestamp | Zadnji uspješan poziv Callable-a za terminal. |

---

## Mapiranje stanice → faza

| `stationSlot` | `phase` (preporuka) | UI oznaka |
|---------------|---------------------|-----------|
| 1 | `preparation` | Pripremna |
| 2 | `first_control` | Prva kontrola |
| 3 | `final_control` | Završna kontrola |

Admin može u konzoli promijeniti `phase`/`displayName` ako je poslovno drugačije — **ali** `stationSlot` + `phase` trebaju ostati usklađeni s aplikacijom.

---

## Indeksi (Firestore)

- Jedinstvenost po `(companyId, plantKey, stationSlot)` — provjeriti u **Cloud Function** pri create/update ili jedinstvenim `pageId` ako je deterministički.
- Query: `where('companyId', '==', …).where('plantKey', '==', …)` — kompozitni indeks ako treba lista stranica po pogonu.

---

## Pravila (smjernice, ne implementacija)

- **Čitanje:** admin / production_manager / super_admin; operateri eventualno samo **aktivne** stranice za svoj `plantKey` (za validaciju terminala).
- **Pisanje:** samo admin (ili production_manager) unutar iste `companyId`.
- **Unosi u `production_operator_tracking`:** ne mijenjaju se — i dalje `createdByUid` = operater; ova kolekcija samo **opisuje** koje stanice postoje.

---

## Poveznice

- Dogovor prava: `STATION_KIOSK_AUTH.md`
- Postojeći unosi: `production_operator_tracking` u `PRODUCTION_SCHEMA.md` (Maintenance repo) + `production_operator_tracking_entry.dart`

---

## Povijest

- **2026-04:** Prva verzija sheme (admin + operater po unosu).
