# MVC → Android field and workflow parity review

MVC source: main 08e53d4fc91a87abe4a12bd07a6d71bc8eb8f319. Source-level comparison of Razor views, shared scope/client/package partials, relevant JavaScript and MVC controllers/read-models with Android catalog and widgets. Not an authenticated device walkthrough.

| Area | Source of truth | Implemented corrections / limitations |
|---|---|---|
| Tasks | Tasks/Index, Details, _ClientPackageSelection, task-package-selection.js, TasksController | Required existing client with read-only contact summary; optional package; fixed package membership, quantity 1–1,000,000, default one; saved quantities on edit; totals; effective OTP completed status and filtering. UPC not exposed by current task-item API. |
| Clients | Clients/_ClientFields, ClientForms, clients.js | Name, optional phone/address/notes/GPS only; validation and foreground location capture. |
| Company | Companies/Form, CompanyForms | Company type on create, fixed type and immutable slug on edit; name, description, email, phone, address, website, two colors, logo; removed legacy attach-member from user-facing actions. |
| Organization | Manage/Index, _OpsScope, solar.js | Role name/description only; hidden internal IDs; scope cascade and effective scope wire values; removed legacy direct assign-role form. |
| Departments | Departments/Index, Members, Applications | Track is fixed General; territory scope retained; initial account exactly email/password/WhatsApp. |
| Applications | AccountRequests/Request, DepartmentForms | Email, designation, WhatsApp, password and 1–10 individual reference names; invitation hidden. |
| Hierarchy | Hierarchy/Index, hierarchy.js | Hide record revision and bound record IDs; native selection forms retained rather than identical drag/drop interaction. |
| Packages | Packages/Index | Fixed parameter type chosen from operation, required initial quantity, warehouse conditional, package quantity fixed one. |
| Stores | Stores/Index | Zone/district required; optional narrower scope, correct branch payload; product/stock forms retained. |
| Profile | Profile/Index, ProfileForms | NID removal shown only if corresponding image exists; file size constraints. |
| Dispatches | TaskDispatch/Details | Decision/progress values bound by action; IDs hidden; scheduling/notes/OTP controls preserved. |
| Auth/notifications/sales | Account and CompanyPortal forms; Notifications/Index; SalesRecords | Existing dedicated auth and record actions retained; not every behavioral state individually exercised. |

The route catalog retains all 151 API routes; it is not a count of verified screens. No server/SQL changes in this Android patch. Verify CI and physical device, including permission grant/denial, task edit/reselect, and role-specific end-to-end tests. API does not expose UPC in TaskSelections.PackageItem at this revision.