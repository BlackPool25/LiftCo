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

    const userProfile = await resolveProfileByAuthOrContact(
      serviceClient,
      user,
      "id, auth_id, name",
    );

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
      .select("id, title, host_user_id, status")
      .eq("id", sessionId)
      .maybeSingle();

    if (!session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.host_user_id === userProfile.id) {
      return new Response(JSON.stringify({ error: "Host cannot leave session. Cancel it instead." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.status !== "upcoming") {
      return new Response(JSON.stringify({ error: "Only upcoming sessions can be left" }), {
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
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: leaveError } = await serviceClient
      .from("session_members")
      .update({ status: "cancelled" })
      .eq("session_id", sessionId)
      .eq("user_id", userProfile.id)
      .eq("status", "joined");

    if (leaveError) {
      return new Response(JSON.stringify({ error: "Failed to leave session", details: leaveError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: remainingMembers } = await serviceClient
      .from("session_members")
      .select("user_id")
      .eq("session_id", sessionId)
      .eq("status", "joined");

    const recipients = (remainingMembers ?? [])
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
              title: "Member Left 👋",
              body: `${userProfile.name} left your ${session.title} session`,
              data: {
                session_id: String(sessionId),
                type: "member_left",
                member_name: userProfile.name,
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
        message: "Successfully left session",
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
