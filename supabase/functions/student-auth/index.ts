import { createClient } from "npm:@supabase/supabase-js@2";
import { cors, json } from "../_shared/common.ts";

// Children have no email: each gets a synthetic auth user; login = class code + avatar + PIN.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const b = await req.json();
  try {
    if (b.action === "roster") {
      const { data } = await admin.from("classes").select("class_students(profiles(id,display_name,avatar))").eq("code", String(b.class_code).toUpperCase()).maybeSingle();
      return json({ students: ((data as any)?.class_students ?? []).map((r: any) => r.profiles) });
    }
    if (b.action === "login") {   // TODO: add attempt counter / lockout before production (4-digit PIN)
      const { data: ok } = await admin.rpc("check_pin", { p_class: String(b.class_code), p_student: b.student_id, p_pin: String(b.pin) });
      if (!ok) return json({ error: "bad_pin" }, 401);
      const { data: au } = await admin.auth.admin.getUserById(b.student_id);
      const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email: au.user!.email! });
      if (error) return json({ error: "link" }, 500);
      return json({ token_hash: data.properties.hashed_token });
    }
    if (b.action === "create") {  // teacher adds a student to a class they own (RLS decides)
      const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
      const { data: cls } = await caller.from("classes").select("id,center_id,teacher_id").eq("id", b.class_id).maybeSingle();
      if (!cls || cls.teacher_id !== (await caller.auth.getUser()).data.user?.id) return json({ error: "forbidden" }, 403);
      const { data: nu, error } = await admin.auth.admin.createUser({ email: `${crypto.randomUUID()}@students.lingvotab.app`, email_confirm: true });
      if (error) return json({ error: "create" }, 500);
      const id = nu.user.id;
      await admin.from("profiles").insert({ id, center_id: cls.center_id, role: "student", display_name: String(b.display_name).slice(0, 30), avatar: b.avatar });
      await admin.rpc("add_student", { p_class: cls.id, p_student: id, p_pin: String(b.pin) });
      return json({ id });
    }
    return json({ error: "bad_action" }, 400);
  } catch (e) { console.error(e); return json({ error: "server_error" }, 500); }
});
