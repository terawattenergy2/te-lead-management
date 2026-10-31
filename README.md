# Terawatt Lead Hub
ReactJS + HTML + CSS + JavaScript, Vite, Yarn, Supabase.

## Run
```
yarn install
cp .env.example .env.local
# Set VITE_SUPABASE_PUBLISHABLE_KEY to the project's public browser key
yarn dev
```
This workspace already has .env.local configured for project mreqawosvhgbiiuvddde. Never use service_role or secret keys in VITE_*.

Customer: http://localhost:5173/#customer
Admin / EPC login: http://localhost:5173/#admin
Ads example: http://localhost:5173/?utm_source=facebook&utm_campaign=solar-home#customer

`yarn build` creates dist/. Deploy with the two VITE_* environment variables configured at build time.

## Supabase installed
Migration `tw_lead_hub_initial` creates only tw_epcs, tw_members, tw_leads, tw_assignments, tw_events, tw_email_outbox and tw_* RPCs. All preexisting tables, records, Auth accounts and policies are unchanged. terawattenergy2@gmail.com is registered as admin in tw_members only. Sign in with its existing Supabase Auth password.

Public customers submit four validated answers and consent through tw_submit_lead; anonymous users cannot read customer records. Authenticated users require an explicit tw_members entry. tw_list_leads returns contact information to Admin and accepted EPC assignments only. Admin can assign to multiple EPC companies. Acceptance locks an assignment and checks its five-day deadline on the server. Only accepted assignments may update Pending/Close/Lost. Three-day follow-ups are listed and logged. tw_reclaim_expired supports manually reclaiming expired assignments for reassignment.

No real EPC company records have been invented or added. EPC membership must be provisioned against authorized existing Auth accounts, or a separate agreed onboarding process.

## Still required before ads launch
- EPC names / recipient emails and authorized EPC users.
- Email provider, verified sender, and public APP_URL. tw_email_outbox queues notifications but does not send email by itself.
- Scheduled reclamation and email delivery worker. No global extensions, project Auth settings or existing scheduler jobs were changed.
- Public HTTPS hosting, privacy policy, spam/rate-limit protection and end-to-end testing with authorized accounts.
- Form is on this website. Meta Instant Forms require a separate webhook integration.

## Verification
`yarn build` passes. supabase/tests/permissions.sql passed with rollback: public read denial, hidden PII before acceptance, EPC isolation, acceptance and status transitions, multiple EPC assignments, expired acceptance denial, reclamation and email queue entries. No test records remain. The test uses existing Auth IDs as foreign keys inside a rollback-only transaction and does not edit those accounts.

The SDK manages session refresh. Without the two VITE_* values the old localStorage demo remains available; with them only the Supabase-backed portal and submission path are used. Existing localStorage demo leads are not uploaded.

## EPC management
Admin sidebar → จัดการ EPC → เพิ่ม EPC. Required fields: company name, employee count, central email, phone. Purchased TE products are optional, one item per line. Admin can edit records and select saved companies when assigning Leads. Creating a company does not create an Auth account or grant EPC login rights. `tw_epc_management` extends only tw_epcs and tw_* RPCs; unrelated Supabase objects are untouched. Save, edit, duplicate-email rejection, employee validation and unauthorized writes were tested in a rolled-back transaction.

## Gmail sender (deployed tw-gmail)
Only sender: terawattenergy2@gmail.com. Admin sidebar → อีเมลผู้ส่ง.
1. In Supabase Edge Function Secrets, set TW_GOOGLE_CLIENT_ID and TW_GOOGLE_CLIENT_SECRET. Never use VITE_* for these.
2. Add this exact Authorized redirect URI to the Google Web OAuth client:
   https://mreqawosvhgbiiuvddde.supabase.co/functions/v1/tw-gmail/callback
3. Add the sender to Google Auth Platform → Audience → Test users while the OAuth app is in Testing.
4. From the Admin page, choose เชื่อม Gmail ผู้ส่ง and authorize the exact sender. Only gmail.send + openid/email scopes are requested.
5. Press the test button to send a real email through this web backend to titawan.udh@gmail.com.
6. To send actual assignment links, set TW_PUBLIC_APP_URL to the public HTTPS app URL, and TW_APP_ORIGINS to that app's origin (comma separated when needed). Default allowed origins are localhost:5173 and 127.0.0.1:5173 for development. Production email delivery deliberately waits for a public app link instead of sending unusable localhost links to EPCs.

Assigning a Lead queues email transactionally and the frontend invokes processing immediately. Each invocation claims at most three queued messages; remaining queued mail can be sent with ส่งอีเมลในคิว. There is no recurring background scheduler installed. A success means Gmail API accepted the message, not a delivery guarantee. Google Testing mode may require periodic reauthorization; production consent verification/publishing is a separate setup step.

Security: tw-gmail gateway JWT verification is disabled ONLY because the Google redirect has no Supabase JWT. Every other action verifies the bearer token with Supabase getUser and the user's tw_members admin role. Callback state is single-use, expires in ten minutes, and uses PKCE. The callback only permits the exact sender verified by Google's userinfo endpoint. Refresh tokens are AES-GCM encrypted using a key derived from the server-only service role secret. Rotating that secret requires Gmail reconnection. The two new tw_gmail_* tables cannot be read/written by anon/authenticated roles. No preexisting Auth accounts, Auth configuration or non-tw_* records are changed.

Gmail does not offer send idempotency. Unknown network outcomes are marked uncertain and are not automatically retried. Stuck sending/uncertain entries require checking the sender's Sent folder before manual recovery. Queued assignment emails contain no customer contact details. Tests: node tests/gmail.test.mjs. Google OAuth/real sending require completing the manual grant and cannot be marked verified until the user does it.

## Send a real Lead email before public hosting
Admin → อีเมลผู้ส่ง → in the queue click ส่ง Lead นี้ให้ titawan for the chosen queued item. This calls the authenticated /simulate action, restricted to titawan.udh@gmail.com and an allowed localhost origin. It uses the actual connected sender and records Gmail's message ID in the same outbox row. It never retries an already sent/sending/uncertain row or processes the rest of the queue. The email clearly warns that its localhost link works only on the machine running the app. This verifies delivery submission, not remote EPC login/onboarding. Normal /process delivery still requires a configured public HTTPS app URL.

## EPC Portal (email + registered phone + email OTP)
EPC links now use `?assignment=<id>#epc`. Old assignment links with #admin are also routed to the EPC Portal, never the Admin page. The portal is independent of the Admin Supabase login session.

EPC enters the central email and phone recorded by Admin in tw_epcs. A six-digit, ten-minute, single-use verification code is emailed to that exact matching company address. The registered phone is an identity check, not a password. No new auth.users accounts are created, so unrelated Supabase applications and Auth profiles are unaffected.

The custom session is stored in sessionStorage, expires after eight hours, and can be logged out. Only its SHA-256 hash is saved in tw_epc_sessions. Codes are HMAC protected with a server-only key, have at most five attempts, and requests are limited per email and network address. The API derives the company ID from its verified server session and ignores client-supplied company IDs. Database portal functions are executable only by service_role and do not accept browser Admin tokens. Only active company assignments are returned; contact details are withheld until acceptance. Accept/status actions check ownership atomically and reject expired/revoked assignments.

Verification: `node tests/epc.test.mjs`; `supabase/tests/epc-portal.sql` passed in a rolled-back transaction for wrong phone, phone normalization, OTP replay/lockout, company isolation, contact masking, acceptance/status rules, and expired Lead denial. No test records persist. Manual real-mail OTP verification still requires the user to enter the received code themselves.

## Solar glass design + motion
The customer page (#customer) now follows a luminous white / ice-blue / navy visual direction with a generated solar residence background, glass energy panel, animated energy paths and gentle image movement. The pause button and prefers-reduced-motion stop animations. The energy panel is explicitly illustrative; no fabricated live energy numbers are displayed. Existing question answers, consent, UTM capture and Supabase submission are preserved. Admin and EPC pages use the same blue glass theme.

Artwork: public/assets/solar-residence-v1.png, generated using built-in ImageGen. This is a concept image, not a claimed completed customer installation. The full prompt and asset notes are in outputs/solar-design-notes.md. Motion is native CSS/SVG, not video.

Validation: production build passed; 390px viewport geometry showed no horizontal overflow; pause control paused image and widget animations; CTA scroll and questionnaire step transition were checked in-browser without submitting customer data.
# te-lead-management
