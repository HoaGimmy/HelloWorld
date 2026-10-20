# MPWindows CRM Web – Google login and safe sync

Status: implementation branch, **not deployed**. Existing iPhone database and backup behavior remain unchanged.

## Architecture
- Flutter Web and iOS share the current CRM screens where supported; web needs a database adapter because `sqflite`, `dart:io`, and iOS native channels are not browser-compatible.
- Supabase Auth with Google OAuth, one allowlisted owner user ID. Never ship a service-role key or Google client secret in Flutter.
- Supabase Postgres with owner-scoped RLS. See `supabase/migrations/20261020_001_crm_sync.sql`.
- Preserve iPhone SQLite as offline source until migration is verified. Keep existing Google Drive JSON backup independent.

## Safe initial migration
1. Export a fresh local JSON backup and verify it can be read before enabling sync.
2. Owner signs in to Supabase Google Auth on both devices; verify same `auth.uid()`.
3. Import local records with deterministic `device_id + table_name + local_id` identity, in batches, **without deleting local rows**.
4. Keep foreign-key relationships (customer IDs, project IDs) through a mapping table; do not use the integer local IDs as global IDs.
5. Validate per-table row counts and sample records before enabling two-way sync.
6. Incremental changes use `updated_at`, tombstones for deletions, and explicit conflict resolution. Never overwrite silently. Attachment files need a separate private storage migration.
7. Only after testing two devices, turn on two-way sync. Retain rollback/export and manual backup options.

## Deployment prerequisites
- Create a Supabase project and configure Google provider in Supabase Auth.
- Configure the authorized Google OAuth redirect URIs, and Web/iOS callback URLs.
- Configure `owner_user_id` for the sole allowed account server-side (see SQL comments).
- Provide Flutter with **public** Supabase URL and anon/publishable key via build-time configuration.
- Deploy Web to Cloudflare Pages after testing and approve the public URL.
- Never commit credentials, backups, or customer data to GitHub.

## Acceptance tests
- Unauthorized Google account cannot read or write records.
- Sign-in, sign-out, refresh work on Web and iOS.
- Imported records preserve Vietnamese characters, dates, money, notes and relations.
- A record created/edited on Web appears on iPhone and vice versa after reconnection.
- Offline edits do not silently overwrite remote edits.
- Backups and restores remain functional, and rollback does not destroy local records.
- Notifications remain native to iOS and are not falsely claimed on Web.
