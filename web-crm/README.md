# MPWindows CRM Web — Google sign-in prototype

This directory contains a standalone static login page. It is NOT the full CRM and must not be advertised as deployed or synced.

## Cloudflare Pages
- Project: `mpwindows-crm`
- Production branch: `feature/crm-web-google-sync`
- Framework: None
- Build command: empty
- Build output directory: `web-crm`
- Expected URL after a successful deployment: https://mpwindows-crm.pages.dev
- If Cloudflare shows a deployment of `main`, it is the wrong branch. Create a new deployment from the production branch, not a retry of an old `main` commit.

## First-time setup
1. In Supabase Authentication > Providers > Google, save the Web OAuth client ID and secret. Never commit the secret.
2. In Supabase Authentication > URL Configuration, set Site URL to `https://mpwindows-crm.pages.dev` and add `https://mpwindows-crm.pages.dev/**` to Redirect URLs.
3. In Google Cloud Audience, keep hoa171996@gmail.com in the OAuth test users list while app is in Testing.
4. Deploy `web-crm/` as static assets, then sign in as hoa171996@gmail.com.
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
