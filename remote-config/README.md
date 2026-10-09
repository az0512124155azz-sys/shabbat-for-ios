# iOS Remote Content

This folder contains the iPhone/iPad-specific remote configuration that can be
published to the `shabbat-app` Supabase project.

Normal commits, pushes, pull requests, merges, and iOS builds do **not** publish
this file to users.

To publish:

1. Edit `remote-config/ios.json`.
2. Commit/review normally.
3. Open **Actions -> Publish iOS Remote Content**.
4. Click **Run workflow**.
5. Type `PUBLISH`.

The workflow requires the repository Actions secret:

`SHABBAT_SUPABASE_SECRET_KEY`

The app itself never contains this secret. It uses only the public publishable
key and has read-only RLS access.
