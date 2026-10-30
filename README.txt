WATER CARE — COMMUNITY SERVICE PROJECT
======================================

PROJECT STRUCTURE
-----------------
index.html
  The current single-page frontend. HTML, CSS and JavaScript are inline.
  Leaflet, map tiles and photos load from internet services.

supabase/migrations/202610290001_initial_schema.sql
  Initial PostgreSQL schema, role helpers, report submission/tracking
  functions, row-level security policies and indexes.

.env.example
  Placeholder configuration for a future Supabase-enabled frontend.
  The current static site does not read this file.

.gitignore
  Ignores local environment files, dependencies and generated build output.

RUN THE CURRENT DEMO
--------------------
1. Open index.html in Chrome or Microsoft Edge, or serve the project with VS Code
   Live Server. The CSP presentation page is the default entry screen.
2. Select Enter Project to open the existing Water Care sign-in screen. Use the
   browser Back button to return to the presentation page.
3. Internet access is needed for maps, external images and map search.
4. Choose Create an account to register a demo username and password in this
   browser, or Sign in with an account already created in this browser.
   Passwords are locally hashed for demonstration, but this is not secure
   server authentication and accounts do not sync across browsers/devices.
5. After sign-in, choose Community user or the Administrator demo workspace.
   The Administrator choice is not protected and must never be used for real
   administration.
6. Records currently shown in the website are illustrative. Reports created
   in this demo and admin changes last only until the page is reloaded.
7. The map uses OpenStreetMap tiles and a CARTO backup tile layer.

SUPABASE DATABASE SETUP (MANUAL; NOT CONNECTED TO THE FRONTEND)
---------------------------------------------------------------
1. Create a Supabase project and keep its database credentials private.
2. In the Supabase SQL Editor, run the migration file at
   supabase/migrations/202610290001_initial_schema.sql.
3. Confirm the migration completes and review Authentication > Policies to
   verify that row-level security is enabled on every public table.
4. Configure the authentication providers and allowed redirect URLs for your
   eventual deployed site.
5. Create or invite the first administrator through Supabase Auth. After that
   account has signed up, promote its auth user ID in the SQL Editor:

   update public.profiles
   set role = 'admin'
   where id = 'AUTH_USER_UUID';

   Only a trusted project owner should run this role-promotion command.
6. To appoint surveyors, a trusted administrator/project owner can set the
   corresponding profile role to 'surveyor'. New users are residents by default.
7. Test with separate resident, surveyor, and administrator accounts before
   entering real community information.

The migration deliberately provides no demo rows. It creates these tables:
profiles, water_points, facilities, reports, report_updates, survey_records,
and water_quality_tests. Public users can read active water points/facilities,
verified survey/test rows, submit a report through a database function, and
track a report using its randomly generated tracking ID. Direct report reads
and report-status changes are restricted; administrators must use the
admin_update_report_status database function, which appends status history.
Do not treat a report, observation, or appearance as a laboratory water test.

IMPORTANT CURRENT LIMITATIONS
-----------------------------
- The static frontend does not contain a Supabase client or call the database.
  Adding a project URL/key to .env.example alone will not connect it.
- The current sign-up/sign-in demo stores password hashes in this browser's
  local storage. This can be cleared or modified by the browser user and does
  not establish a secure identity. The Administrator choice is demo-only.
  Real user accounts and admin routes require Supabase Auth and database-
  enforced roles.
- The existing example water points, facilities, report entries and status
  counts in index.html are not real survey records.
- No genuine survey submission/review UI, QR codes, notifications, or deployed
  backend is configured.
- The report tracking ID is a bearer secret. Users who know it can see the
  public, non-contact report summary and status history. Do not share it
  publicly.
- The schema stores optional contact information with reports, but it does not
  expose that field through the public tracking function.
- Keep any Supabase service-role key and database password out of frontend
  code. A public anon/publishable key may be used in a browser only after
  authentication and RLS policies are correctly configured.

NEXT DEVELOPMENT STEPS
----------------------
1. Add a package/build setup or a secure server-side application layer.
2. Add the Supabase client using deployment environment variables; never
   hard-code credentials in index.html.
3. Replace demo login with Supabase Auth and remove demo-only admin access.
4. Connect report creation/tracking to submit_report and track_report.
5. Connect admin actions to admin_update_report_status and add audit-history
   and permission tests.
6. Replace illustrative water point and facility data with verified records.
7. Build survey and water-quality workflows with clear observed/reported/
   verified labels.
8. Test the SQL migration and RLS policies using separate roles before
   deploying over HTTPS.
