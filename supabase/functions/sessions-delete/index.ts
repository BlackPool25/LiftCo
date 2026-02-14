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
  "Access-Control-Allow-Methods": "DELETE, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function notifyCancellation(
  sessionId: string,
  title: string,
  memberUserIds: string[],
) {
  if (memberUserIds.length == 0) {
    return { sent: 0, failed: 0, skipped: true };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
    return {
      sent: 0,
      failed: memberUserIds.length,
      skipped: true,
      warning: "Missing service role configuration for notifications",
    };
  }

  const response = await fetch(`${supabaseUrl}/functions/v1/notifications-send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceRoleKey}`,
      apikey: serviceRoleKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_ids: memberUserIds,
      title: "Session Cancelled",
      body: `"${title}" has been cancelled by the host.`,
      data: {
        type: "session_cancelled",
        session_id: sessionId,
        session_title: title,
      },
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    return {
      sent: 0,
      failed: memberUserIds.length,
      warning: `Failed to send cancellation notifications: ${details}`,
    };
  }

  try {
    const payload = await response.json();
    return {
      sent: payload?.sent ?? 0,
      failed: payload?.failed ?? 0,
      warning: payload?.warning,
    };
  } catch {
    return { sent: memberUserIds.length, failed: 0 };
  }
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

    let sessionId: string | null = null;
    try {
      const body = await req.json();
      sessionId = body?.session_id ?? body?.id ?? null;
    } catch {
      // ignore body parsing errors
    }

    const url = new URL(req.url);
    if (!sessionId) {
      sessionId = url.searchParams.get("id");
    }

    if (!sessionId) {
      const pathParts = url.pathname.split("/").filter(Boolean);
      const lastSegment = pathParts[pathParts.length - 1] ?? "";
      if (lastSegment !== "sessions-delete") {
        sessionId = lastSegment;
      }
    }

    if (!sessionId || !UUID_RE.test(sessionId)) {
      return new Response(JSON.stringify({ error: "Invalid session ID" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userProfile = await resolveProfileByAuthOrContact(
      serviceClient,
      user,
      "id, auth_id",
    );

    if (!userProfile) {
      return new Response(JSON.stringify({ error: "User profile not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: session } = await serviceClient
      .from("workout_sessions")
      .select("id, host_user_id, status, title")
      .eq("id", sessionId)
      .maybeSingle();

    if (!session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.host_user_id !== userProfile.id) {
      return new Response(JSON.stringify({ error: "Only host can cancel this session" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (session.status === "finished" || session.status === "cancelled") {
      return new Response(
        JSON.stringify({ error: "Cannot cancel a finished or already cancelled session" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const now = new Date().toISOString();

    const { data: joinedMembers, error: membersFetchError } = await serviceClient
      .from("session_members")
      .select("user_id")
      .eq("session_id", sessionId)
      .eq("status", "joined");

    if (membersFetchError) {
      return new Response(
        JSON.stringify({
          error: "Failed to load session members",
          details: membersFetchError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const recipients = (joinedMembers ?? [])
      .map((member) => member.user_id as string)
      .filter((id) => id !== userProfile.id);

    const { error: cancelError } = await serviceClient
      .from("workout_sessions")
      .update({ status: "cancelled", current_count: 0, updated_at: now })
      .eq("id", sessionId);

    if (cancelError) {
      return new Response(JSON.stringify({ error: "Failed to cancel session", details: cancelError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const notificationResult = await notifyCancellation(
      sessionId,
      session.title ?? "Workout Session",
      recipients,
    );

    const { error: removeMembersError } = await serviceClient
      .from("session_members")
      .delete()
      .eq("session_id", sessionId);

    if (removeMembersError) {
      return new Response(
        JSON.stringify({
          error: "Session cancelled but failed to remove members",
          details: removeMembersError.message,
          session_id: sessionId,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(JSON.stringify({
      message: "Session cancelled successfully",
      session_id: sessionId,
      notifications: notificationResult,
      members_removed: (joinedMembers ?? []).length,
    }), {
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
