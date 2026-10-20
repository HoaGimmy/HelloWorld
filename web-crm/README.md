# MPWindows CRM Web

Implementation on `feature/crm-web-google-sync`. iPhone sources and workflows unchanged.

## Run / checks

- `python -m http.server 8080 --directory web-crm` from repository root.
- `npm ci --prefix web-crm`, then `node --test web-crm/tests/*.test.js` (Node 22+).
- Google OAuth needs the actual origin in Supabase redirect allowlist.
- Deploy directory: `web-crm`, no build command, Cloudflare project `mpwindows-crm`.
- `supabase/web-security.sql` was applied and verified against production on 2026-10-20. Apply it before deploying this client in another environment. It adds server authorization RPC, atomic revision-checked save, append-only transactional import and revokes unnecessary client privileges. It does not change owner or existing records.
- Existing production DB already uses `private.is_crm_owner()`; this SQL targets that verified schema, not the older staging migration in this repository.

## Features

Server-verified single owner login, eight business modules, create/edit, search and month filters, six dashboard counts, receivables and company commission formula. Phone copy/call/SMS. Responsive CSS, safe DOM text rendering, CSP/security headers. No physical delete UI. Writes require network; drafts remain in the open form on error, not persisted across a closed tab.

## iPhone interoperability

**Automatic iPhone sync is not implemented in the current Flutter source.** No IPA built or published.

Use an existing iPhone JSON backup (`mpwindows-crm-backup`, version 1). Preview counts and import with a fixed source name. All rows commit together. Identical reimports skip; changed records reject the entire import for explicit reconciliation. Never change the source name for the same iPhone database. Use a separate name for an unrelated database to prevent integer ID collisions.

Web export remaps every customer/project/contract relationship to integer IDs and omits device app_settings. On iPhone use merge, never replacement restore. Existing iPhone merge is append-only and does **not** deduplicate: importing the same Web export repeatedly produces duplicate records. This is a manual migration bridge, not two-way synchronization. iPhone photo/file paths are retained as metadata; no attachment bytes transfer.

## Release gates still open

1. Apply SQL and verify privileges, owner/unauthorized access, revision conflicts and import rollback against the real database.
2. Browser/mobile viewport and authenticated CRUD end-to-end checks.
3. Test a fresh backup on an isolated iPhone database; never use production restore for testing.
4. Publish Web only after backend and functional checks. User approved continuing Web deployment on 2026-10-20. No iPhone release without explicit approval.
