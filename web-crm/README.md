# MPWindows CRM Web — Google sign-in prototype

This directory contains a standalone static login page. It is NOT the full CRM and must not be advertised as deployed or synced.

## First-time setup
1. In Supabase Authentication > Providers > Google, save the Web OAuth client ID and secret. Never commit the secret.
2. In Supabase Authentication > URL Configuration, add the exact deployed HTTPS web origin to Redirect URLs. Configure Site URL appropriately.
3. In Google Cloud Audience, keep hoa171996@gmail.com in the OAuth test users list while app is in Testing.
4. Deploy `web-crm/` as static assets (for example Cloudflare Pages), then sign in as hoa171996@gmail.com.
5. In Supabase SQL Editor, look up the authenticated user's UUID (do not guess it):
   `select id,email from auth.users where lower(email)='hoa171996@gmail.com';`
6. After verifying that Google identity and UUID, assign single owner with:
   `insert into public.crm_owner(singleton,user_id) values(true,'ACTUAL_UUID_FROM_STEP_5');`
   Do not replace an existing owner without explicit approval.

## Safety
- The browser-side email comparison is only UX; authorization comes from Supabase RLS + crm_owner.
- Never add service_role or OAuth client secret to frontend.
- Current login prototype does not write any CRM records, import backups, or sync iPhone data.
- Supabase records schema is staging only; proper reconciliation, stable IDs, version conflict handling, deletion tombstones and attachments remain to implement.
- Flutter iOS app remains unchanged.
