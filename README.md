# CK Enterprises — Machinery Running Records

Android app (Flutter) + cloud SQL database (Supabase / PostgreSQL).

**Employees:** log in, submit daily running record (date, machine, site, meter
readings, fuel, operator, work, downtime, remarks). Hours are calculated
automatically (on the server too, so they can't be faked). See own record history and status.

**Admins:** review all records (filter pending/approved/rejected), approve,
reject with reason, edit with mandatory reason, view full audit history,
add/disable machines and sites.

**Security:** Row Level Security in the database. Employees cannot approve
their own records, cannot see others' records, cannot change hours.
All admin changes are logged in `record_edit_history`.

See **DEPLOY.md** for step-by-step delivery.
