import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type AuthUser = {
  id: string;
  email?: string | null;
  phone?: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function resolveProfileByAuthOrContact(
  serviceClient: ReturnType<typeof createClient>,
  user: AuthUser,
  selectColumns: string,
) {
  const { data: byAuthId } = await serviceClient
    .from("users")
    .select(selectColumns)
    .eq("auth_id", user.id)
    .maybeSingle();
  if (byAuthId) return byAuthId;

  let byContact: any = null;
  if (user.email) {
    const { data } = await serviceClient
      .from("users")
      .select(selectColumns)
      .eq("email", user.email)
      .maybeSingle();
    byContact = data;
  }

  if (!byContact && user.phone) {
    const { data } = await serviceClient
      .from("users")
      .select(selectColumns)
      .eq("phone_number", user.phone)
      .maybeSingle();
    byContact = data;
  }

  if (!byContact) return null;

  if (byContact.auth_id !== user.id) {
    await serviceClient
      .from("users")
      .update({ auth_id: user.id, updated_at: new Date().toISOString() })
      .eq("id", byContact.id);
    byContact.auth_id = user.id;
  }

  return byContact;
}

function u32FromFirst4(bytes: Uint8Array): number {
  // Big-endian u32 from first 4 bytes.
  return (
    ((bytes[0] ?? 0) << 24) |
    ((bytes[1] ?? 0) << 16) |
    ((bytes[2] ?? 0) << 8) |
    (bytes[3] ?? 0)
  ) >>> 0;
}

async function hmacSha256(secret: string, message: string): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return new Uint8Array(sig);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Authorization header required" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { session_id } = await req.json().catch(() => ({}));
    if (!session_id || typeof session_id !== "string" || !UUID_RE.test(session_id)) {
      return new Response(JSON.stringify({ error: "Valid session_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const secret =
      Deno.env.get("ATTENDANCE_HMAC_SECRET")?.trim() ||
      // Fallback: keep the system working even if ATTENDANCE_HMAC_SECRET was
      // not configured in the project. This key is already a high-entropy secret
      // and never leaves the server.
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();

    if (!secret) {
      return new Response(JSON.stringify({ error: "Server misconfigured", details: "Missing ATTENDANCE_HMAC_SECRET" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const {
      data: { user },
      error: userError,
    } = await authClient.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Invalid or expired session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const requester = await resolveProfileByAuthOrContact(serviceClient, user, "id");
    if (!requester) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: session } = await serviceClient
      .from("workout_sessions")
      .select("id, gym_id, host_user_id, start_time, duration_minutes, status")
      .eq("id", session_id)
      .maybeSingle();

    if (!session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Must be host or a joined member.
    const isHost = session.host_user_id === requester.id;
    let isJoined = false;
    if (!isHost) {
      const { data: membership } = await serviceClient
        .from("session_members")
        .select("id")
        .eq("session_id", session_id)
        .eq("user_id", requester.id)
        .eq("status", "joined")
        .maybeSingle();
      isJoined = !!membership;
    }

    if (!isHost && !isJoined) {
      return new Response(JSON.stringify({ error: "You are not a member of this session" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Server-time attendance window: [-10m, +15m] around session start.
    const now = new Date();
    const start = new Date(session.start_time);
    const opensAt = new Date(start.getTime() - 10 * 60_000);
    const closesAt = new Date(start.getTime() + 15 * 60_000);

    if (now.getTime() < opensAt.getTime() || now.getTime() > closesAt.getTime()) {
      return new Response(
        JSON.stringify({
          error: "Attendance window closed",
          opens_at: opensAt.toISOString(),
          closes_at: closesAt.toISOString(),
          now: now.toISOString(),
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const nowSeconds = Math.floor(now.getTime() / 1000);
    const windowIndex = Math.floor(nowSeconds / 30);


    // Bind token to (user_id, gym_id, windowIndex) to prevent cross-gym replay.
    const message = `${requester.id}|${String(session.gym_id)}|${String(windowIndex)}`;
    const digest = await hmacSha256(secret, message);
    const tokenU32 = u32FromFirst4(digest);

    const major = (tokenU32 >>> 16) & 0xffff;
    const minor = tokenU32 & 0xffff;

    return new Response(
      JSON.stringify({
        session_id,
        user_id: requester.id,
        gym_id: session.gym_id,
        window_index: windowIndex,
        token_u32: tokenU32,
        ibeacon: {
          proximity_uuid: requester.id,
          major,
          minor,
        },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: (error as Error).message,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
