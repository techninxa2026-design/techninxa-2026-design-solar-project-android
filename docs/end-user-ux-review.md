# End-user UX review — shared Flutter surfaces

Source review, not device observation: cramped narrow text, hero text constrained beside decorative artwork, unsearchable dropdowns and long permission checklists, inconsistent modal sheets, raw hex color input, inert addresses.

- Shared keyboard-aware branded sheet for operations, portal selection, workspace selection, single/multi-select controls and color selection.
- Searchable options/actions, preserved selection and dependent field updates, explicit apply for multiselect and colors.
- HSV palette, live color preview, saturation and brightness controls. MVC receives the same #RRGGBB value.
- Address and authorized GPS location interactions: allowed mapping domains or URL-encoded address search. Copy/paste link in client form with preview. Maps launches only on user action; no location permission or geocoding.
- Width-aware grids, adaptive hero, wrapped filters and heading action layout, single-line navigation labels.
- No new dependencies, permissions, API or submission changes. Device verification still required. Tests cover color encoding, map URL safety, picker behavior and narrow large-text screens.
