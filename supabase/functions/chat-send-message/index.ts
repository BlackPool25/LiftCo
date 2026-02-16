import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type AuthUser = {
  id: string;
  email?: string | null;
  phone?: string | null;
};

async function resolveProfileByAuthOrContact(
  serviceClient: ReturnType<typeof createClient>,
  user: AuthUser,
) {
  const { data: byAuthId } = await serviceClient
    .from("users")
    .select("id, auth_id, email, phone_number, name")
    .eq("auth_id", user.id)
    .maybeSingle();
  if (byAuthId) return byAuthId;

  let byContact: any = null;
  if (user.email) {
    const { data } = await serviceClient
      .from("users")
      .select("id, auth_id, email, phone_number, name")
      .eq("email", user.email)
      .maybeSingle();
    byContact = data;
  }

  if (!byContact && user.phone) {
    const { data } = await serviceClient
      .from("users")
      .select("id, auth_id, email, phone_number, name")
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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return text.slice(0, Math.max(0, max - 1)).trimEnd() + "…";
}

function isChatOpen(now: Date, startTime: Date, durationMinutes: number): boolean {
  const openAtMs = startTime.getTime() - 24 * 60 * 60 * 1000;
  const closeAtMs = startTime.getTime() + durationMinutes * 60_000 + 2 * 60 * 60 * 1000;
  const nowMs = now.getTime();
  return nowMs >= openAtMs && nowMs <= closeAtMs;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Authorization header required" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").trim();
    const anonKey = (Deno.env.get("SUPABASE_ANON_KEY") ?? "").trim();
    const serviceRoleKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return new Response(JSON.stringify({ error: "Missing server configuration" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const serviceClient = createClient(supabaseUrl, serviceRoleKey);

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

    let userProfile: any = null;
    for (let attempt = 0; attempt < 3; attempt++) {
      userProfile = await resolveProfileByAuthOrContact(serviceClient, user);
      if (userProfile) break;
      if (attempt < 2) await new Promise((resolve) => setTimeout(resolve, 120));
    }

    if (!userProfile) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const sessionId = body?.session_id as string | undefined;
    const contentRaw = body?.content as string | undefined;
    const type = (body?.type as string | undefined) ?? "text";

    if (!sessionId || !UUID_RE.test(sessionId)) {
      return new Response(JSON.stringify({ error: "Valid session_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (type !== "text") {
      return new Response(JSON.stringify({ error: "Only text messages are supported" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const content = (contentRaw ?? "").trim();
    if (content.isEmpty) {
      return new Response(JSON.stringify({ error: "Message content is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (content.length > 500) {
      return new Response(JSON.stringify({ error: "Message is too long (max 500 characters)" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: session } = await serviceClient
      .from("workout_sessions")
      .select("id, title, start_time, duration_minutes, status")
      .eq("id", sessionId)
      .maybeSingle();

    if (!session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.status === "cancelled") {
      return new Response(JSON.stringify({ error: "Chat is unavailable for cancelled sessions" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: membership } = await serviceClient
      .from("session_members")
      .select("id")
      .eq("session_id", sessionId)
      .eq("user_id", userProfile.id)
      .eq("status", "joined")
      .maybeSingle();

    if (!membership) {
      return new Response(JSON.stringify({ error: "You are not a member of this session" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const now = new Date();
    const startTime = new Date(session.start_time);
    const durationMinutes = Number(session.duration_minutes ?? 0);

    if (!isChatOpen(now, startTime, durationMinutes)) {
      return new Response(
        JSON.stringify({
          error: "Chat is closed",
          details: "Chat opens 24h before and closes 2h after the session ends.",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: insertedMessage, error: insertError } = await serviceClient
      .from("chat_messages")
      .insert({
        session_id: sessionId,
        user_id: userProfile.id,
        content,
        type: "text",
      })
      .select("id, session_id, user_id, content, type, created_at")
      .single();

    if (insertError) {
      return new Response(JSON.stringify({ error: "Failed to send message", details: insertError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: members } = await serviceClient
      .from("session_members")
      .select("user_id")
      .eq("session_id", sessionId)
      .eq("status", "joined");

    const recipients = (members ?? [])
      .map((m: any) => m.user_id as string)
      .filter((id: string) => id !== userProfile.id);

    if (recipients.length > 0) {
      try {
        await fetch(`${supabaseUrl}/functions/v1/notifications-send`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${serviceRoleKey}`,
          },
          body: JSON.stringify({
            user_ids: recipients,
            title: `💬 ${session.title}`,
            body: `${userProfile.name}: ${truncate(content, 120)}`,
            data: {
              type: "chat_message",
              session_id: String(sessionId),
              session_title: String(session.title),
              sender_name: String(userProfile.name ?? "Someone"),
              message_id: String(insertedMessage.id),
            },
          }),
        });
      } catch {
        // non-blocking
      }
    }

    return new Response(
      JSON.stringify({
        message: "Message sent",
        chat_message: insertedMessage,
        notifications_sent: recipients.length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error", details: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
