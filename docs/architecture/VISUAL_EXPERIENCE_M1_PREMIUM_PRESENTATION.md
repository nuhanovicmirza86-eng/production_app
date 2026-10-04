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

## Palette

Station appearance stays the existing local preference (`StationScreenThemeStore`).

In Premium that choice maps to a dark palette:

- Operonix (brend) → Midnight, teal accent, canvas `#0A1020`
- Industrijska noć → cobalt canvas and blue accent
- Svijetla proizvodnja → dark violet canvas, never a light page
- custom colors → accent is kept, a light background is pulled down to a dark canvas

The palette changes the page canvas, selected navigation, primary action, selected segmented control and relevant icon badges. It does not change component structure or switch Premium back to Classic.

## Pilot screens

Početna, Proizvodni nalozi, Procesi, Operativne evidencije, Praćenje proizvodnje → Proizvodnja, and Kvalitet each have a Premium composition that is separate from the Classic layout.
