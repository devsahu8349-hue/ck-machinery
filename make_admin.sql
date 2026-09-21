-- Run AFTER creating the user in Supabase > Authentication > Users.
-- Replace the email with the boss/admin's login email.
update public.profiles
set role = 'admin', full_name = 'Admin Name'
where id = (select id from auth.users where email = 'admin@example.com');
