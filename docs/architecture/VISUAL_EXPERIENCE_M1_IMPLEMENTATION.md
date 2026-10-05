# VISUAL-EXPERIENCE-M1 — Production pilot

**Status:** OWNER ACCEPTED · CANONICAL on `production_app` `main`  
**Owner mobile acceptance:** PASS  
**Production web shell:** PASS against `OPERONIX_UNIFIED_WEB_SHELL_RESPONSIVE_STANDARD.md`  
**Kanonska arhitektura (nije prepisivana):**  
`maintenance_app/docs/architecture/OPERONIX_VISUAL_EXPERIENCE_ARCHITECTURE.md`  
`maintenance_app/docs/architecture/OPERONIX_UNIFIED_WEB_SHELL_RESPONSIVE_STANDARD.md`

## Šta je uvedeno

- `VisualStyle`: `classic` | `premium`
- Premium izgled u M1: **Midnight** (Graphite i Premium Light nisu implementirani)
- Lokalna preferenca: `SharedPreferences` ključ `operonix_production_visual_style_v1`
- Default bez zapisa: **Classic**
- Promjena je odmah, preko `VisualExperienceController`, bez restarta i bez Firestore zapisa
- `Standardno` / `Ikone` ostaje zasebna preferenca (`productionDashboardLayout` na `users`)

## Tokeni i tema

- `OperonixVisualTokens` (`ThemeExtension`)
- `OperonixVisualTheme.classic()` čuva postojeći seed `0xFF164344`, zelenu karticu i outlined polja
- `OperonixVisualTheme.premiumMidnight()` tamni shell, elevated površine, teal akcent, semantičke boje

## Shell

Production web više ne omotava cijelu aplikaciju u `Center` + `maxWidth: 1280` (`OperonixApplicationFrame`).

Geometrija je ista za Classic i Premium i prati Maintenance read-only:

- wide od 900 px (ili native Windows)
- Material 3 navigation rail `minWidth` 80 (Flutter default; Maintenance ga ne override-a)
- divider širine 1
- sadržaj počinje odmah iza raila
- page padding 12 web / 16 mobile

`OperonixContentConstraint` je interni max-width za sadržaj, ne za shell.

## Pilot

Isti ekran, isti podaci i iste akcije. Classic zadržava dosadašnji raspored. Premium koristi `lib/core/visual/premium/`:

- Početna: kompaktna kartica sesije s logom i semantičke kartice modula. Standardno/Ikone nije na tijelu početne. Izgled aplikacije je na Više, u web izborniku i preko tune akcije.
- Proizvodni nalozi: KPI u jednom redu na desktopu i 2×2 na užem ekranu, filter kartica, prazan panel, Novi nalog nije puna širina.
- Procesi: kartica pogona, filter kartica, prazan panel s Dodaj. Nema odvojenog FAB-a u Premiumu.
- Operativne evidencije: kompaktna kartica, naslov pa jedna meta linija, semantička značka po profilu.
- Praćenje proizvodnje: u Premiumu Midnight drži cijelu stranicu. Spremljena tema stanice ne boji tijelo. Tema gumba je u paleti, ne u toku unosa. Classic i dalje koristi punu temu stanice.

Midnight dubina: background `0xFF0A1020`, surface `0xFF121A2B`, elevated `0xFF182338`, interactive `0xFF223049`.

## Zatvoreno stanje

- Classic ostaje trajni izgled. Premium je opcioni.
- Premium tema u M1 je Midnight.
- Premium poslovne ikone su piktogrami.
- Premium Početna je responzivna i gušća od prve mreže.
- Izgled aplikacije je izvan tijela Početne. Standardno/Ikone ostaje zasebna preferenca.
- Production web shell je puna širina viewporta, usklađen s Maintenance rail geometrijom.
- Praćenje zadržava paletu radnog prostora i poseban override boje operativne akcije.
- Owner mobile acceptance: PASS.
- Web structural acceptance: PASS.
- Maintenance Visual Experience rollout ostaje budući paket. Ova isporuka ne mijenja Maintenance.
- One Operonix AI Assistant: NOT STARTED.

## Namjerno odgođeno

- account sync preferencije
- Premium Graphite / Premium Light
- Maintenance rollout
- One Operonix AI Assistant
- prepisivanje lokalnog izgleda Praćenja na dijeljene tokene (rizik regresije odobrenog ekrana)
- širi Production rollout van pilota
