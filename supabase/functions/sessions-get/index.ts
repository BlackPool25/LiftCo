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
    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
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

    const requester = await resolveProfileByAuthOrContact(serviceClient, user, "id, auth_id, gender");
    if (!requester) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(req.url);
    const pathParts = url.pathname.split("/").filter(Boolean);
    const lastSegment = pathParts[pathParts.length - 1] ?? "";
    const sessionIdFromPath = lastSegment !== "sessions-get" ? lastSegment : null;
    const sessionId = sessionIdFromPath ?? url.searchParams.get("id");

    if (!sessionId || !UUID_RE.test(sessionId)) {
      return new Response(JSON.stringify({ error: "Invalid session ID" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: session, error: sessionError } = await serviceClient
      .from("workout_sessions")
      .select(
        `
        *,
        host:host_user_id(id, name, age, profile_photo_url),
        gym:gym_id(name, address, latitude, longitude)
      `,
      )
      .eq("id", sessionId)
      .maybeSingle();

    if (sessionError || !session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const requesterGender = (requester.gender ?? "").toLowerCase();
    if (session.women_only === true && requesterGender !== "female") {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: myMembership } = await serviceClient
      .from("session_members")
      .select("id")
      .eq("session_id", sessionId)
      .eq("user_id", requester.id)
      .eq("status", "joined")
      .maybeSingle();

    const isUserJoined = !!myMembership || session.host_user_id === requester.id;

    // Public view policy:
    // - Non-members can only view sessions that are upcoming and have not started.
    // - Members/host can also view sessions while they are in progress.
    // - Finished/cancelled sessions are not returned from this endpoint.
    const now = new Date();
    const sessionStart = new Date(session.start_time);
    const durationMinutes = Number(session.duration_minutes ?? 0);
    const sessionEnd = new Date(sessionStart.getTime() + durationMinutes * 60_000);

    const isFutureUpcoming = session.status === "upcoming" && sessionStart.getTime() > now.getTime();
    const isCurrentlyRunning =
      sessionStart.getTime() <= now.getTime() && sessionEnd.getTime() > now.getTime();
    const isAllowedForMember =
      isUserJoined &&
      (session.status === "upcoming" || session.status === "in_progress") &&
      isCurrentlyRunning;

    if (!isFutureUpcoming && !isAllowedForMember) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let members: unknown[] = [];
    if (isUserJoined) {
      const { data: joinedMembers } = await serviceClient
        .from("session_members")
        .select(
          `
          id,
          session_id,
          user_id,
          status,
          joined_at,
          user:user_id(id, name, age, profile_photo_url)
        `,
        )
        .eq("session_id", sessionId)
        .eq("status", "joined")
        .order("joined_at", { ascending: true });
      members = joinedMembers ?? [];
    }

    const payload = { ...session, members, is_user_joined: isUserJoined };

    return new Response(JSON.stringify({ session: payload }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error", details: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
