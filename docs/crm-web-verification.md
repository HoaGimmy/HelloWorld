# CRM Web verification — 2026-10-20

Base: `7acd644ccdedb16743f4eb9ec626e8e4c3dc9c5d`, branch `feature/crm-web-google-sync`.

## Confirmed

- Repository cloned from GitHub; iPhone `lib/`, native code and existing workflows unchanged.
- Real Supabase project is active; owner UUID matches the previously approved account.
- Cloud CRM record count is zero. No customer data imported, deleted or overwritten.
- RLS enabled with owner predicates on reads/inserts/updates and deny-delete policy.
- Audit found default TRUNCATE privilege for client roles; RLS does not protect TRUNCATE. Revoke SQL prepared.
- Twelve Node tests pass (including DOM tests with a mock backend): Vietnamese/phone preservation, invalid backups, namespace isolation, relation remapping, missing relation rejection, company commission formula, iPhone timestamp-column compatibility.
- JavaScript syntax validation passes.

## Not confirmed / blocked

- Supabase writes recovered after renewed user authorization. Hardening and RPC SQL applied successfully. Read-only verification confirms TRUNCATE/DELETE revoked, crm_owner table unreadable to client, crm_access exists, record count remains zero.
- `supabase/web-verify.sql` passed against real Supabase: owner insert/read/save; revision increment; stale edit rejection; identical import deduplication; changed import rollback; non-owner read/write/RPC denial; anonymous read denial. Entire transaction rolled back.
- Local full-browser E2E not run: browser binary download unavailable in current environment.
- No authenticated Google sign-in or physical iPhone test performed.
- Web deployment authorized by user; publication status is verified separately in the final response.
- Automatic two-way iPhone sync, private attachments, notifications on Web are not implemented.

## Security advisor

`crm_owner` has RLS with no client policies intentionally: registration is admin-only. Password leak protection is disabled per Auth advisor; Google OAuth uses Google credentials. No service-role key or OAuth secret was added to the client.
