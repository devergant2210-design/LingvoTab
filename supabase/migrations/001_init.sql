create extension if not exists pgcrypto with schema extensions;
create type user_role as enum ('admin','teacher','student');

create table centers (id uuid primary key default gen_random_uuid(), name text not null);
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  center_id uuid references centers,
  role user_role not null,
  display_name text not null,            -- nickname only: no personal data for children
  avatar text,
  ui_lang text not null default 'uz' check (ui_lang in ('uz','en','ru')));
create table devices (id uuid primary key default gen_random_uuid(), center_id uuid references centers, label text, active boolean not null default true);
create table classes (
  id uuid primary key default gen_random_uuid(),
  center_id uuid not null references centers,
  teacher_id uuid not null references profiles,
  name text not null,
  code text not null unique default upper(substr(md5(random()::text),1,6)),
  target_lang text not null default 'en');
create table class_students (
  class_id uuid references classes on delete cascade,
  student_id uuid references profiles on delete cascade,
  pin_hash text not null,
  primary key (class_id, student_id));
create table lessons (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references classes on delete cascade,
  title text not null, level text not null default 'A1',
  is_active boolean not null default false);
create table lesson_words (
  lesson_id uuid references lessons on delete cascade,
  word text not null, translation_uz text,
  primary key (lesson_id, word));
create table characters (
  id text primary key, name text not null, avatar text not null,
  personality text not null, speaking_style text not null,
  tts_pitch real not null default 1.0, tts_rate real not null default 0.45);
create table messages (
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles,
  lesson_id uuid references lessons,
  character_id text references characters,
  role text not null check (role in ('child','character')),
  content text not null,
  violations int not null default 0, fallback boolean not null default false,
  created_at timestamptz not null default now());
create table word_progress (
  student_id uuid references profiles, lesson_id uuid references lessons, word text,
  seen int not null default 0, used_correctly int not null default 0,
  primary key (student_id, lesson_id, word));

-- helpers (security definer => no RLS recursion)
create function my_role() returns user_role language sql stable security definer set search_path=public as $$ select role from profiles where id=auth.uid() $$;
create function my_center() returns uuid language sql stable security definer set search_path=public as $$ select center_id from profiles where id=auth.uid() $$;
create function teaches(c uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from classes where id=c and teacher_id=auth.uid()) $$;
create function in_class(c uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from class_students where class_id=c and student_id=auth.uid()) $$;
create function lesson_class(l uuid) returns uuid language sql stable security definer set search_path=public as $$ select class_id from lessons where id=l $$;
create function teacher_of(s uuid) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from class_students cs join classes c on c.id=cs.class_id where cs.student_id=s and c.teacher_id=auth.uid()) $$;

alter table centers enable row level security;        alter table profiles enable row level security;
alter table devices enable row level security;        alter table classes enable row level security;
alter table class_students enable row level security; alter table lessons enable row level security;
alter table lesson_words enable row level security;   alter table characters enable row level security;
alter table messages enable row level security;       alter table word_progress enable row level security;

create policy c_sel on centers for select using (id = my_center());
create policy p_sel on profiles for select using (id = auth.uid() or teacher_of(id) or (my_role()='admin' and center_id = my_center()));
create policy p_adm on profiles for all using (my_role()='admin' and center_id = my_center()) with check (my_role()='admin' and center_id = my_center());
create policy d_adm on devices for all using (my_role()='admin' and center_id = my_center()) with check (my_role()='admin' and center_id = my_center());
create policy cl_sel on classes for select using (teacher_id = auth.uid() or in_class(id) or (my_role()='admin' and center_id = my_center()));
create policy cl_tea on classes for all using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
create policy cs_sel on class_students for select using (student_id = auth.uid() or teaches(class_id));
create policy ls_sel on lessons for select using (in_class(class_id) or teaches(class_id));
create policy ls_tea on lessons for all using (teaches(class_id)) with check (teaches(class_id));
create policy lw_sel on lesson_words for select using (in_class(lesson_class(lesson_id)) or teaches(lesson_class(lesson_id)));
create policy lw_tea on lesson_words for all using (teaches(lesson_class(lesson_id))) with check (teaches(lesson_class(lesson_id)));
create policy ch_sel on characters for select to authenticated using (true);
create policy m_sel on messages for select using (student_id = auth.uid() or teacher_of(student_id));   -- inserts: service role only
create policy wp_sel on word_progress for select using (student_id = auth.uid() or teacher_of(student_id));

-- service-role-only functions
create function check_pin(p_class text, p_student uuid, p_pin text) returns boolean language sql security definer set search_path=public,extensions as $$
  select exists(select 1 from class_students cs join classes c on c.id=cs.class_id
    where c.code=upper(p_class) and cs.student_id=p_student and cs.pin_hash=crypt(p_pin, cs.pin_hash)) $$;
create function add_student(p_class uuid, p_student uuid, p_pin text) returns void language sql security definer set search_path=public,extensions as $$
  insert into class_students values (p_class, p_student, crypt(p_pin, gen_salt('bf'))) $$;
create function bump_progress(p_student uuid, p_lesson uuid, p_seen text[], p_used text[]) returns void language sql security definer set search_path=public as $$
  insert into word_progress(student_id,lesson_id,word,seen,used_correctly)
  select p_student,p_lesson,w,(w=any(p_seen))::int,(w=any(p_used))::int from unnest(p_seen||p_used) w group by w
  on conflict (student_id,lesson_id,word) do update
    set seen=word_progress.seen+excluded.seen, used_correctly=word_progress.used_correctly+excluded.used_correctly $$;
revoke all on function check_pin, add_student, bump_progress from public, anon, authenticated;

-- teacher dashboard
create view student_progress with (security_invoker=true) as
  select student_id, lesson_id, count(*) words_seen, sum(used_correctly) correct_uses from word_progress group by 1,2;

insert into characters (id,name,avatar,personality,speaking_style,tts_pitch,tts_rate) values
 ('princess_luna','Princess Luna','👸','kind, graceful, loves stars and gardens','gentle and sing-song',1.25,0.42),
 ('captain_nova','Captain Nova','🦸','brave, cheerful, always helps friends','energetic and heroic',0.9,0.5),
 ('momo_mouse','Momo the Mouse','🐭','funny, curious, loves cheese and jokes','quick, squeaky and playful',1.6,0.55),
 ('robo_bit','Robo Bit','🤖','logical, friendly, loves counting','slow, clear, a little robotic',0.7,0.4),
 ('ember_dragon','Ember the Dragon','🐲','big-hearted, sleepy, loves treasure and snacks','deep, warm and rumbly',0.6,0.42);
