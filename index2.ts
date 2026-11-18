import { createClient } from "npm:@supabase/supabase-js@2";
import { claude, cors, json } from "../_shared/common.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const user = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: { user: u } } = await user.auth.getUser();
    if (!u) return json({ error: "unauthorized" }, 401);
    const { image_b64, lesson_id } = await req.json();
    if (!image_b64 || image_b64.length > 4_000_000) return json({ error: "bad_image" }, 400);

    const out = await claude(
      `You help a young child learn words. Name the ONE main everyday object in the photo.
Reply with JSON only: {"object_en": string|null, "object_uz": string|null}.
Use null if the photo shows a person or face, anything unsafe or unsuitable for children, or you are unsure. Never describe people.`,
      [{ role: "user", content: [{ type: "image", source: { type: "base64", media_type: "image/jpeg", data: image_b64 } }, { type: "text", text: "What object is this?" }] }], 80);
    let o: { object_en?: string | null; object_uz?: string | null } = {};
    try { o = JSON.parse(out.replace(/```json|```/g, "").trim()); } catch { /* treat as unknown */ }

    const word = o.object_en?.toLowerCase() ?? null;
    const { data: lw } = await user.from("lesson_words").select("word").eq("lesson_id", lesson_id);
    return json({ word, uz: o.object_uz ?? null, in_lesson: !!word && !!lw?.some((x) => x.word.toLowerCase() === word) });
  } catch (e) {
    console.error(e);
    return json({ error: "server_error" }, 500);
  }
});
