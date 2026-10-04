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
- icon badge with a semantic family, not one teal for every icon
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

## Pilot screens

Početna, Proizvodni nalozi, Procesi, Operativne evidencije, Praćenje proizvodnje → Proizvodnja, and Kvalitet each have a Premium composition that is separate from the Classic layout.
