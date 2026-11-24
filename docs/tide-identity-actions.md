# IDCOLDA — Identity-first mobile refresh

Research references: Dribbble CRM Mobile App (Artur Lopato, shot 27004849), Ronas IT CRM Mobile App Design (26011763), Mobile Worker Profile – Bottom sheet Actions (27092647), Material bottom sheet / contextual action guidance. Original native implementation, no copied artwork.

Company directory and record header show the real uploaded logo via the existing protected image endpoint. The workspace picker uses public company branding images; missing or invalid logos fall back to initials. Logo requests use IDCOLDA API transport with fixed path validation, no global cache or external host. Disabled companies still use the protected administrator endpoint.

Replace action button stacks with a compact primary action dock and a contextual icon-led action sheet. Destructive controls remain separated and all existing confirmation and authorization paths remain in place. Record actions stay reachable at the bottom; module creation and nested record actions use the same component. No API, route, dependency, backend or database changes.

Device review and CI required before release.