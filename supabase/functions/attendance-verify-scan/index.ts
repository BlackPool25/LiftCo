import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-scanner-key",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function sha256Hex(input: string): Promise<string> {
  const enc = new TextEncoder();
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(input));
  const bytes = new Uint8Array(digest);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function u32FromFirst4(bytes: Uint8Array): number {
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

async function computeTokenU32(
  secret: string,
  userId: string,
  gymId: number,
  windowIndex: number,
): Promise<number> {
  const message = `${userId}|${String(gymId)}|${String(windowIndex)}`;
  const digest = await hmacSha256(secret, message);
  return u32FromFirst4(digest);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const scannerKey = req.headers.get("x-scanner-key")?.trim();
    if (!scannerKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const secret = Deno.env.get("ATTENDANCE_HMAC_SECRET")?.trim();
    if (!secret) {
      return new Response(JSON.stringify({ error: "Server misconfigured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const userId = body?.user_id as string | undefined;
    const gymIdRaw = body?.gym_id as number | string | undefined;
    const tokenRaw = body?.token_u32 as number | string | undefined;
    const scannerId = body?.scanner_id as string | undefined;

    if (!userId || typeof userId !== "string" || !UUID_RE.test(userId)) {
      return new Response(JSON.stringify({ error: "Valid user_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const gymId = Number(gymIdRaw);
    if (!Number.isFinite(gymId) || gymId <= 0) {
      return new Response(JSON.stringify({ error: "Valid gym_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!scannerId || typeof scannerId !== "string" || scannerId.trim().length == 0) {
      return new Response(JSON.stringify({ error: "Valid scanner_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const tokenU32 = Number(tokenRaw);
    if (!Number.isFinite(tokenU32) || tokenU32 < 0 || tokenU32 > 0xffffffff) {
      return new Response(JSON.stringify({ error: "Valid token_u32 is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Validate scanner credentials against DB (per gym + scanner_id).
    const scannerKeyHash = await sha256Hex(scannerKey);
    const { data: scannerRow } = await serviceClient
      .from("attendance_scanners")
      .select("id")
      .eq("gym_id", gymId)
      .eq("scanner_id", scannerId)
      .eq("is_active", true)
      .eq("key_hash_sha256_hex", scannerKeyHash)
      .maybeSingle();

    if (!scannerRow) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Server-time window index (+/- 1) to tolerate minor clock skew.
    const now = new Date();
    const nowSeconds = Math.floor(now.getTime() / 1000);
    const t = Math.floor(nowSeconds / 30);

    const candidates = [t - 1, t, t + 1];
    let matchedWindow: number | null = null;

    for (const wi of candidates) {
      const expected = await computeTokenU32(secret, userId, gymId, wi);
      if (expected === tokenU32) {
        matchedWindow = wi;
        break;
      }
    }

    if (matchedWindow == null) {
      return new Response(JSON.stringify({ error: "Token mismatch" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Find an eligible session for this user at this gym inside the attendance window.
    // Window is defined as [-10m, +15m] around session start.
    const { data: sessions, error: sessionErr } = await serviceClient
      .from("workout_sessions")
      .select("id, gym_id, host_user_id, start_time")
      .eq("gym_id", gymId)
      .in("status", ["upcoming", "in_progress"])
      .gte("start_time", new Date(now.getTime() - 12 * 60 * 60_000).toISOString())
      .lte("start_time", new Date(now.getTime() + 12 * 60 * 60_000).toISOString())
      .order("start_time", { ascending: true });

    if (sessionErr) {
      return new Response(
        JSON.stringify({ error: "Failed to locate session", details: sessionErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const nowMs = now.getTime();

    const candidateSessions = (sessions ?? []).filter((s: any) => {
      const start = new Date(s.start_time).getTime();
      const opens = start - 10 * 60_000;
      const closes = start + 15 * 60_000;
      if (nowMs < opens || nowMs > closes) return false;
      return true;
    });

    if (candidateSessions.length === 0) {
      return new Response(JSON.stringify({ error: "No active attendance window" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Keep only sessions where the user is host or joined member.
    const candidateIds = candidateSessions.map((s: any) => s.id as string);

    const { data: memberships } = await serviceClient
      .from("session_members")
      .select("session_id")
      .eq("user_id", userId)
      .eq("status", "joined")
      .in("session_id", candidateIds);

    const joined = new Set((memberships ?? []).map((m: any) => m.session_id as string));

    const eligible = candidateSessions.filter((s: any) =>
      s.host_user_id === userId || joined.has(s.id as string)
    );

    if (eligible.length === 0) {
      return new Response(JSON.stringify({ error: "User has no eligible session" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // If multiple, pick the one whose start time is closest to now.
    eligible.sort((a: any, b: any) => {
      const da = Math.abs(new Date(a.start_time).getTime() - nowMs);
      const db = Math.abs(new Date(b.start_time).getTime() - nowMs);
      return da - db;
    });

    const chosen = eligible[0];

    const { data: attendanceRow, error: upsertErr } = await serviceClient
      .from("session_attendance")
      .upsert(
        {
          session_id: chosen.id,
          user_id: userId,
          gym_id: chosen.gym_id,
          window_index: matchedWindow,
          token_u32: tokenU32,
          scanner_id: scannerId,
          source: "ble_ibeacon",
          marked_at: now.toISOString(),
        },
        { onConflict: "session_id,user_id" },
      )
      .select("session_id, user_id, gym_id, marked_at")
      .maybeSingle();

    if (upsertErr) {
      return new Response(
        JSON.stringify({ error: "Failed to mark attendance", details: upsertErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ ok: true, attendance: attendanceRow, session_id: chosen.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error", details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
