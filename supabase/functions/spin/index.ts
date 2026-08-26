import { corsHeaders, json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "missing authorization" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const body = await req.json();
    const { data, error } = await supabase.rpc("perform_spin", {
      p_stake: body.stake,
      p_request_id: body.request_id,
    });
    if (error) return json({ error: error.message }, 400);
    return json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "spin failed";
    return json({ error: message }, 400);
  }
});
