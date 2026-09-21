# Delivery guide (about 30–45 minutes)

## Part 1 — Cloud database (Supabase)
1. Go to https://supabase.com → New project. Choose a region near India
   (e.g. Mumbai / Singapore). Save the database password.
2. **SQL Editor → New query** → paste all of `supabase/schema.sql` → **Run**.
3. (Optional) run `supabase/seed.sql` for sample machines/sites — or add your own later in the app.
4. **Authentication → Users → Add user** → create the admin (email + password, tick "Auto confirm").
5. Edit the email in `supabase/make_admin.sql` and run it in the SQL Editor. That user is now admin.
6. **Authentication → Providers → Email**: turn OFF "Allow new users to sign up"
   (so only people you create can log in).
7. Create each employee the same way (Authentication → Users → Add user, Auto confirm).
   They become "employee" automatically. To set their display name, run:
   `update public.profiles set full_name='Ramesh' where id=(select id from auth.users where email='ramesh@x.com');`
8. **Project Settings → API**: copy **Project URL** and the **anon public** key.
   (Never use the `service_role` key in the app.)

## Part 2 — Build the APK (easiest: GitHub, no Flutter install needed)
1. Create a private GitHub repo and upload this whole folder.
2. Repo → Settings → Secrets and variables → Actions → add secrets:
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
3. Actions tab → **Build Android APK** → Run workflow.
4. When finished, download `ck-machinery-apk` → unzip → `app-release.apk`.

### Or build on your own PC
```
bash tools/prepare_android.sh
flutter build apk --release --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxxx
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

## Part 3 — Deliver
- Send the APK by WhatsApp / Drive. On the phone: allow "install unknown apps", install.
- Test with an employee login: submit a record. Test with the admin login: approve it.

## Before wider / Play Store release
- Create your own signing keystore (the default build is signed with the debug key — fine for internal use, not for Play Store).
- Turn on Supabase daily backups (Pro plan) — the free tier has none. Export data regularly otherwise.
- Free tier pauses projects after 1 week of inactivity; use Pro for a production business tool.
