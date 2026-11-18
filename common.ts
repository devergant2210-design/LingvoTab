export const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
export const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "content-type": "application/json" } });

// The ONLY place the Anthropic key is used. Never ship it in the app.
export async function claude(system: string, messages: { role: string; content: unknown }[], max_tokens = 120) {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-5-5", max_tokens, system, messages }),
  });
  if (!r.ok) throw new Error(`claude ${r.status}`);
  const j = await r.json();
  return (j.content as { type: string; text?: string }[]).filter((b) => b.type === "text").map((b) => b.text).join("").trim();
}
