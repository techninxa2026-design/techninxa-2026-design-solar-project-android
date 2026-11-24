# Tide Flow Prism — native card and typography refresh

Preserves the existing wave background, authentication, navigation, company color source, API client, route catalog and business commands.

Design reference: Android Developers content composition and Material Design card hierarchy. Use expressive shape, semantic state labels, grouped facts, whitespace and restrained brand-tinted surfaces rather than uniform generic ListTiles.

- Dashboard: adaptive metric cards and quick module tiles; real server values only.
- Module directory: width-aware tiles (one column for narrow or large-text layouts).
- Records: module-specific icons, actual status text and curated visible data, with metrics for stock, unit prices and sales. The detail page continues to display the previous authorized scalar fields.
- Details: labeled and selectable values with dividers, long-value stacking, no added hidden data.
- Forms: consistent headings and typography; no request, validation, or submit-handler changes.
- Dark mode: surfaces and text use the active theme; semantic status colors have explicit dark variants.
- Tests: narrow-screen and large-text widget tests in both themes.

No additional package dependencies or new API requests. This is a native Flutter presentation-only update. Actual device visual acceptance and build verification are required before release.