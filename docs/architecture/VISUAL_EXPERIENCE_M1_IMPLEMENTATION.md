# VISUAL-EXPERIENCE-M1 — Production pilot checkpoint

**Status:** implementirano na grani `ui/visual-experience-m1-production-pilot`  
**Owner smoke:** pending  
**Kanonska arhitektura (ne dirana iz ove grane):**  
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

- Početna: izgled aplikacije + postojeće kartice/akcije preko tokena
- Proizvodni nalozi: KPI, filteri, prazno stanje, puna širina stranice
- Procesi: postojeći CRUD, tokenizirana labela pogona, prazno stanje
- Operativne evidencije: `ProductionEvidenceListCard` bez jakog zelenog obruba u Premiumu
- Praćenje proizvodnje: lokalni station theme store nije prepisivan

## Namjerno odgođeno

- account sync preferencije
- Premium Graphite / Premium Light
- Maintenance rollout
- One Operonix AI Assistant
- prepisivanje lokalnog izgleda Praćenja na dijeljene tokene (rizik regresije odobrenog ekrana)
- širi Production rollout van pilota

## Owner smoke

Mobilni i web checklist ostaju ručni. Automatski testovi ne zamjenjuju vizuelni PASS.
