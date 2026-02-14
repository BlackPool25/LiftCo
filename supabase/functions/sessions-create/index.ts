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

    const userProfile = await resolveProfileByAuthOrContact(serviceClient, user, "id, auth_id, gender");

    if (!userProfile) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const {
      gym_id,
      title,
      session_type,
      description,
      start_time,
      duration_minutes,
      max_capacity = 4,
      intensity_level,
      women_only = false,
    } = body;

    if (!gym_id || !title || !session_type || !start_time || !duration_minutes) {
      return new Response(
        JSON.stringify({
          error:
            "Missing required fields: gym_id, title, session_type, start_time, duration_minutes",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userGender = (userProfile.gender ?? "").toLowerCase();
    if (women_only && userGender !== "female") {
      return new Response(JSON.stringify({ error: "Only female users can create women-only sessions" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const sessionStart = new Date(start_time);
    if (sessionStart <= new Date()) {
      return new Response(JSON.stringify({ error: "Session start time must be in the future" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: session, error: createError } = await serviceClient
      .from("workout_sessions")
      .insert({
        gym_id,
        host_user_id: userProfile.id,
        title,
        session_type,
        description: description || null,
        start_time,
        duration_minutes,
        max_capacity,
        current_count: 0,
        status: "upcoming",
        intensity_level: intensity_level || null,
        women_only,
      })
      .select("*")
      .single();

    if (createError || !session) {
      return new Response(JSON.stringify({ error: "Failed to create session", details: createError?.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: joinError } = await serviceClient.from("session_members").insert({
      session_id: session.id,
      user_id: userProfile.id,
      status: "joined",
    });

    if (joinError) {
      return new Response(JSON.stringify({ error: "Failed to add host as member", details: joinError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { count: joinedCount } = await serviceClient
      .from("session_members")
      .select("id", { count: "exact", head: true })
      .eq("session_id", session.id)
      .eq("status", "joined");

    await serviceClient
      .from("workout_sessions")
      .update({ current_count: joinedCount ?? 0, updated_at: new Date().toISOString() })
      .eq("id", session.id);

    const { data: updatedSession } = await serviceClient
      .from("workout_sessions")
      .select(
        `
        *,
        host:host_user_id(id, name, age, profile_photo_url),
        gym:gym_id(name, address)
      `,
      )
      .eq("id", session.id)
      .single();

    return new Response(
      JSON.stringify({ message: "Session created successfully", session: updatedSession ?? session }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error", details: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
