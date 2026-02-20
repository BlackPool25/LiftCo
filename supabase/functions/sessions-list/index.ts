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

    const requester = await resolveProfileByAuthOrContact(serviceClient, user, "id, auth_id, gender");

    if (!requester) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(req.url);
    const gymId = url.searchParams.get("gym_id");
    const status = url.searchParams.get("status");
    const sessionType = url.searchParams.get("session_type");
    const dateFrom = url.searchParams.get("date_from");
    const dateTo = url.searchParams.get("date_to");
    const joinedOnly = url.searchParams.get("joined_only") === "true";
    const limit = Number(url.searchParams.get("limit") ?? "50");
    const offset = Number(url.searchParams.get("offset") ?? "0");

    let query = serviceClient
      .from("workout_sessions")
      .select(
        `
        *,
        host:host_user_id(id, name, age, profile_photo_url),
        gym:gym_id(name, address)
      `,
      )
      .order("start_time", { ascending: true })
      .range(offset, offset + limit - 1);

    if (gymId) query = query.eq("gym_id", Number(gymId));
    if (status) query = query.eq("status", status);
    else query = query.in("status", ["upcoming", "in_progress"]);
    if (sessionType) query = query.eq("session_type", sessionType);
    if (dateFrom) query = query.gte("start_time", dateFrom);
    if (dateTo) query = query.lte("start_time", dateTo);

    const { data: rawSessions, error } = await query;
    if (error) {
      return new Response(JSON.stringify({ error: "Failed to fetch sessions", details: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const requesterGender = (requester.gender ?? "").toLowerCase();
    const visibleSessions = (rawSessions ?? []).filter((session) => {
      if (session.women_only === true && requesterGender !== "female") {
        return false;
      }
      return true;
    });

    if (visibleSessions.length === 0) {
      return new Response(
        JSON.stringify({
          sessions: [],
          pagination: { limit, offset, count: 0 },
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const sessionIds = visibleSessions.map((session) => session.id);
    const { data: memberships } = await serviceClient
      .from("session_members")
      .select("session_id")
      .eq("user_id", requester.id)
      .eq("status", "joined")
      .in("session_id", sessionIds);

    const joinedSessionIds = new Set(
      (memberships ?? []).map((membership) => membership.session_id as string),
    );

    const { data: attendanceRows } = await serviceClient
      .from("session_attendance")
      .select("session_id")
      .eq("user_id", requester.id)
      .in("session_id", sessionIds);

    const attendedSessionIds = new Set(
      (attendanceRows ?? []).map((row: any) => row.session_id as string),
    );

    const sessions = visibleSessions
      .map((session) => {
        const isUserJoined = joinedSessionIds.has(session.id) || session.host_user_id === requester.id;
        const attendanceMarked = attendedSessionIds.has(session.id);
        return { ...session, is_user_joined: isUserJoined, attendance_marked: attendanceMarked };
      })
      .filter((session) => (joinedOnly ? session.is_user_joined : true));

    return new Response(
      JSON.stringify({
        sessions,
        pagination: { limit, offset, count: sessions.length },
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
