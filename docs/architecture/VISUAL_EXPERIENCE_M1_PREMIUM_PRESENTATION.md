# VISUAL-EXPERIENCE-M1 — Premium presentation

Status: OPEN. Owner visual PASS is not claimed.

## Premium is not dark Classic

Classic stays a supported visual experience. Premium is a separate presentation over the same business state, services, RBAC, navigation, callbacks, validation and data.

A screen is not Premium if the only difference is a dark background and recolored cards. The mandatory review is:

If the colors were converted to grayscale, would Premium still look materially different from Classic?

If the answer is no, the screen is not Premium.

## What Premium may change

Component composition, information hierarchy, density, spacing, card structure, navigation presentation, iconography, empty states, action hierarchy and responsive composition.

## What Premium must not change

Business logic, controllers, services, Firestore, Cloud Functions, RBAC, ERP, AI, IoT, BigQuery, or workflow rules. Classic widget trees stay on the Classic branch.

## Presentation grammar

Shared families live under `lib/core/visual/premium/`:

- page canvas and surfaces at three levels (section, working surface, selected/priority)
- context, action and KPI treatments
- icon badge with a semantic family and a domain glyph, not one teal Material icon
- list row with a family rail
- empty state, filter toolbar, segmented control
- primary and secondary actions
- one data surface for tables

Border is used for selection, focus or status. Ordinary grouping uses surface contrast.

Spacing follows 4 / 8 / 12 / 16 / 24 / 32. Radius is not the same on every surface.

## Three layers

Global visual style and the two local tracking preferences stay separate.

| Layer | Store | What it may change |
| --- | --- | --- |
| Global visual style | `operonix_production_visual_style_v1` | Classic or Premium component system for the whole app |
| Tema radnog prostora | `station_screen_appearance_v1` (`StationScreenThemeStore`) | Tracking canvas, AppBar, surfaces, dividers, navigation accent, icon shift |
| Boja operativnih akcija | `prep_station_accent_v1` (`PreparationStationUiPrefs`) | Skeniraj QR, Potvrdi unos, and the same primary station actions. Not the canvas or navigation |

Precedence on Praćenje proizvodnje:

```text
Premium base
→ station workspace palette
→ action accent override
```

Operonix (brend) on Premium is Midnight, canvas `#0A1020`, teal accent.

Industrijska noć is a near-black industrial canvas with a cyan accent.

Svijetla proizvodnja is a real light Premium workspace on the tracking screen only. It does not switch the app back to Classic.

The action colors stay Zelena, Plava, Narančasta and Ljubičasta. They recolor the primary action and its foreground is chosen for contrast. They do not recolor the page.

## Premium iconography

Premium business icons are local duotone pictograms (`OperonixPremiumIcon`), not a Material pack and not image assets. Each mark is a filled object plus one secondary detail. Classic keeps its existing Material icons.

The icon sits on a borderless soft spot. There is no stroked rounded square around the pictogram. Spot size and radius come from `PremiumBadgeVariant`: small (28 / 8), medium (40 / 12), large home illustration (60 / 18). The drawing fills most of that spot. Selected state deepens the tint. Disabled uses `disabledText`. Utility actions (back, close, search, refresh, more) stay Material icons.

Color families stay semantic: production green, quality cyan, material amber, maintenance/operation orange, lab teal, information blue, critical red, analytics violet, administration teal. Recognition comes from the silhouette. On a light tracking canvas the accent is darkened so the pictogram stays readable.

`OperonixPremiumIconography` maps home titles, evidence profile keys, quality titles and the four production-order KPI labels. Home concepts use separate objects: terminal, pallet parts, order sheet, Gantt, live cell, feed bin, caliper, final shield, linked cells, logbook, task tray and process sheet. Station workspace theme does not leave Praćenje proizvodnje.

Premium Ikone on Početna chooses the column count from the content width and a minimum tile width of 150. A phone-width list stays at 2 columns. Tile height follows the 60 px pictogram plus the title: two lines once the title column is wide enough, three lines only on a narrower phone tile. Wider tablet and web tiles stay in that same short band and do not become tall panels. Registracije uses that same card. Classic Ikone keeps its previous column steps and green card border. Standardno stays a separate layout.

## Appearance settings

Početna does not host appearance controls. Classic / Premium, the Premium theme and the home arrangement live together under Izgled aplikacije.

Prikaz is Classic or Premium and stays in the local M1 preference. Raspored is Standardno or Ikone and stays on `users.preferences.productionDashboardLayout`. The two preferences are independent. Changing raspored updates Početna immediately through the existing watcher.

Mobile shows the same Izgled aplikacije controls on Više. Web opens those controls from the tune action and the web menu. There is no second settings screen and no second persistence path.

Maintenance still shows Standardno / Ikone on its Home. The Maintenance Visual Experience rollout must move that control into the same Izgled aplikacije area: Classic / Premium, Premium theme, and home layout Standardno / Ikone. Home screens themselves must not host appearance controls. This M1 branch does not change Maintenance.

## Pilot screens

Početna, Proizvodni nalozi, Procesi, Operativne evidencije, Praćenje proizvodnje → Proizvodnja, and Kvalitet each have a Premium composition that is separate from the Classic layout.
