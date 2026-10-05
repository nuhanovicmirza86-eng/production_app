# VISUAL-EXPERIENCE-M2 — Production full rollout

**Status:** IMPLEMENTED on `ui/visual-experience-m2-full-production-rollout`  
**Classic:** PERMANENT  
**Premium:** SUPPORTED (Midnight)  
**One Operonix AI Assistant:** NOT STARTED

M1 compositions stay: Početna, Proizvodni nalozi, Procesi, Operativne evidencije, Praćenje proizvodnje, Kvalitet. Pictorial iconography, Premium Home density, appearance placement and the tracking palette stay locked.

## Coverage

Every reachable `*_screen.dart` is listed in `VISUAL_EXPERIENCE_M2_SCREEN_MATRIX.md`.

There is one business screen per flow. Premium is not a second screen tree.

Remaining screens receive Premium through:

- `OperonixVisualTheme.premiumMidnight()` on `MaterialApp` (surfaces, type, filled fields, buttons, rail, app bar)
- dialog and sheet radius 20
- data table heading band
- calendar date picker theme
- `StandardFilterPanel` elevated surface without an outline when Premium is active

Classic theme values for cards, outlined fields, dialogs, tables and the filter panel stay as they were.

## Unchanged

- business logic, callbacks, RBAC, navigation destinations
- Firestore schema and backend
- appearance persistence (`operonix_production_visual_style_v1`, `productionDashboardLayout`)
- shell geometry
