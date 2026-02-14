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
    .select("id, auth_id, email, phone_number, name, gender")
    .eq("auth_id", user.id)
    .maybeSingle();
  if (byAuthId) return byAuthId;

  let byContact: any = null;
  if (user.email) {
    const { data } = await serviceClient
      .from("users")
      .select("id, auth_id, email, phone_number, name, gender")
      .eq("email", user.email)
      .maybeSingle();
    byContact = data;
  }

  if (!byContact && user.phone) {
    const { data } = await serviceClient
      .from("users")
      .select("id, auth_id, email, phone_number, name, gender")
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

    const userProfile = await resolveProfileByAuthOrContact(serviceClient, user);

    if (!userProfile) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const sessionId = body?.session_id as string | undefined;

    if (!sessionId || !UUID_RE.test(sessionId)) {
      return new Response(JSON.stringify({ error: "Valid session_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: session } = await serviceClient
      .from("workout_sessions")
      .select(
        "id, title, start_time, duration_minutes, host_user_id, women_only, current_count, max_capacity, status",
      )
      .eq("id", sessionId)
      .maybeSingle();

    if (!session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.women_only && (userProfile.gender ?? "").toLowerCase() !== "female") {
      return new Response(JSON.stringify({ error: "Women-only session" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.status !== "upcoming") {
      return new Response(JSON.stringify({ error: "Only upcoming sessions can be joined" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: existingMembership } = await serviceClient
      .from("session_members")
      .select("id")
      .eq("session_id", sessionId)
      .eq("user_id", userProfile.id)
      .eq("status", "joined")
      .maybeSingle();

    if (existingMembership) {
      return new Response(JSON.stringify({ error: "You are already a member of this session" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.current_count >= session.max_capacity) {
      return new Response(JSON.stringify({ error: "Session is full" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const startTime = new Date(session.start_time).toISOString();
    const endTime = new Date(
      new Date(session.start_time).getTime() + session.duration_minutes * 60_000,
    ).toISOString();

    const { data: conflictingMemberships } = await serviceClient
      .from("session_members")
      .select("session_id, workout_sessions!inner(id, start_time, duration_minutes, status)")
      .eq("user_id", userProfile.id)
      .eq("status", "joined");

    const hasConflict = (conflictingMemberships ?? []).some((row: any) => {
      const s = row.workout_sessions;
      if (!s || s.status !== "upcoming") return false;
      const sStart = new Date(s.start_time).toISOString();
      const sEnd = new Date(new Date(s.start_time).getTime() + s.duration_minutes * 60_000).toISOString();
      return sStart < endTime && sEnd > startTime;
    });

    if (hasConflict) {
      return new Response(JSON.stringify({ error: "You already have a conflicting session" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: joinError } = await serviceClient.from("session_members").insert({
      session_id: sessionId,
      user_id: userProfile.id,
      status: "joined",
    });

    if (joinError) {
      return new Response(JSON.stringify({ error: "Failed to join session", details: joinError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: existingMembers } = await serviceClient
      .from("session_members")
      .select("user_id")
      .eq("session_id", sessionId)
      .eq("status", "joined");

    const recipients = (existingMembers ?? [])
      .map((m: any) => m.user_id as string)
      .filter((id: string) => id !== userProfile.id);

    if (recipients.length > 0) {
      try {
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (serviceRoleKey) {
          await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/notifications-send`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              user_ids: recipients,
              title: "Squad Update! 💪",
              body: `${userProfile.name} joined your ${session.title} session!`,
              data: {
                session_id: String(sessionId),
                type: "member_joined",
                new_member_name: userProfile.name,
                session_title: session.title,
              },
            }),
          });
        }
      } catch {
        // non-blocking
      }
    }

    return new Response(
      JSON.stringify({
        message: "Successfully joined session",
        session_id: sessionId,
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
