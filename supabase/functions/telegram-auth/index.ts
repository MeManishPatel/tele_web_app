import { corsHeaders, json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const encoder = new TextEncoder();

function hex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function hmacSha256(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(data));
}

async function validateInitData(initData: string, botToken: string): Promise<URLSearchParams> {
  const params = new URLSearchParams(initData);
  const hash = params.get("hash");
  if (!hash) throw new Error("missing hash");
  params.delete("hash");

  const dataCheckString = [...params.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");

  const secretKey = await hmacSha256(encoder.encode("WebAppData"), botToken);
  const signature = await hmacSha256(new Uint8Array(secretKey), dataCheckString);
  if (hex(signature) !== hash) throw new Error("invalid telegram hash");

  const authDate = Number(params.get("auth_date") ?? "0");
  const age = Date.now() / 1000 - authDate;
  if (!authDate || age > 86400) throw new Error("stale telegram auth");

  return params;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!botToken || !supabaseUrl || !serviceKey || !anonKey) {
      return json({ error: "server misconfigured" }, 500);
    }

    const { initData } = await req.json();
    if (!initData || typeof initData !== "string") {
      return json({ error: "initData required" }, 400);
    }

    const params = await validateInitData(initData, botToken);
    const userRaw = params.get("user");
    if (!userRaw) return json({ error: "telegram user missing" }, 400);
    const tgUser = JSON.parse(userRaw) as {
      id: number;
      first_name?: string;
      last_name?: string;
      username?: string;
      photo_url?: string;
    };

    const email = `tg_${tgUser.id}@telegram.local`;
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let authUserId: string | null = null;
    const { data: existing } = await admin
      .from("users")
      .select("id")
      .eq("telegram_id", tgUser.id)
      .maybeSingle();

    if (existing?.id) {
      authUserId = existing.id as string;
      await admin.auth.admin.updateUserById(authUserId, {
        email,
        user_metadata: {
          telegram_id: tgUser.id,
          username: tgUser.username,
          first_name: tgUser.first_name,
          last_name: tgUser.last_name,
          photo_url: tgUser.photo_url,
        },
      });
    } else {
      const created = await admin.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: {
          telegram_id: tgUser.id,
          username: tgUser.username,
          first_name: tgUser.first_name,
          last_name: tgUser.last_name,
          photo_url: tgUser.photo_url,
        },
      });
      if (created.error || !created.data.user) {
        const listed = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
        const found = listed.data.users.find((u) =>
          u.email === email || Number(u.user_metadata?.telegram_id) === tgUser.id
        );
        if (!found) {
          return json({ error: created.error?.message ?? "auth create failed" }, 500);
        }
        authUserId = found.id;
        await admin.auth.admin.updateUserById(authUserId, {
          user_metadata: {
            telegram_id: tgUser.id,
            username: tgUser.username,
            first_name: tgUser.first_name,
            last_name: tgUser.last_name,
            photo_url: tgUser.photo_url,
          },
        });
      } else {
        authUserId = created.data.user.id;
      }
    }

    const profile = {
      id: authUserId,
      telegram_id: tgUser.id,
      username: tgUser.username ?? null,
      first_name: tgUser.first_name || "Player",
      last_name: tgUser.last_name ?? null,
      photo_url: tgUser.photo_url ?? null,
      is_active: true,
      last_active_at: new Date().toISOString(),
    };

    const { error: upsertError } = await admin.from("users").upsert(profile, {
      onConflict: "id",
    });
    if (upsertError) return json({ error: upsertError.message }, 500);

    const password = `${crypto.randomUUID()}${crypto.randomUUID()}`;
    const pwdUpdate = await admin.auth.admin.updateUserById(authUserId!, {
      password,
    });
    if (pwdUpdate.error) return json({ error: pwdUpdate.error.message }, 500);

    const anon = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const signedIn = await anon.auth.signInWithPassword({ email, password });
    if (signedIn.error || !signedIn.data.session) {
      return json({ error: signedIn.error?.message ?? "session failed" }, 500);
    }

    return json({
      access_token: signedIn.data.session.access_token,
      refresh_token: signedIn.data.session.refresh_token,
      user: profile,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "auth failed";
    return json({ error: message }, 401);
  }
});
