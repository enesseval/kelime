# Supabase

Project "Kelime Widget" (ref `elqtyiuvalanlsxuawar`, eu-west-1) in the KelimeWidget organization.
URL https://elqtyiuvalanlsxuawar.supabase.co; the app uses the publishable key (safe to ship).

Migrations in `migrations/` are applied in order. Advisor warnings that are intended:
- `shared_list` is SECURITY DEFINER and callable by anon: link lists open without an account,
  and only rows with visibility link/public (or the caller's own) are returned.
- `delete_account` is callable by signed-in users: it deletes only the caller.
