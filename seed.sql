-- OPTIONAL sample data. Replace with your real machines and sites.
insert into public.machines(code, name, model) values
  ('JCB-001', 'JCB Loader', '3DX'),
  ('EXC-001', 'Excavator', 'PC200')
on conflict (code) do nothing;

insert into public.sites(name, customer_name, address) values
  ('Indore Site', 'Sample Customer', 'Indore, Madhya Pradesh');
