import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function normalizePhone(phone: string | null): string | null {
  if (!phone) return null;
  return phone.replace(/\D/g, "");
}

async function resolveAppUserId(
  serviceClient: ReturnType<typeof createClient>,
  authUser: { id: string; email?: string | null; phone?: string | null },
): Promise<string | null> {
  const byAuth = await serviceClient
    .from("users")
    .select("id")
    .eq("auth_id", authUser.id)
    .maybeSingle();

  if (!byAuth.error && byAuth.data?.id) {
    return byAuth.data.id as string;
  }

  const email = authUser.email?.trim().toLowerCase();
  if (email) {
    const byEmail = await serviceClient
      .from("users")
      .select("id")
      .ilike("email", email)
      .maybeSingle();

    if (!byEmail.error && byEmail.data?.id) {
      return byEmail.data.id as string;
    }
  }

  const normalizedPhone = normalizePhone(authUser.phone ?? null);
  if (normalizedPhone) {
    const byPhone = await serviceClient
      .from("users")
      .select("id")
      .or(`phone.eq.${normalizedPhone},phone.eq.+${normalizedPhone}`)
      .maybeSingle();

    if (!byPhone.error && byPhone.data?.id) {
      return byPhone.data.id as string;
    }
  }

  return null;
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
      data: { user: authUser },
      error: authError,
    } = await authClient.auth.getUser();

    if (authError || !authUser) {
      return new Response(JSON.stringify({ error: "Invalid or expired session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const fcmToken = body?.fcm_token?.toString().trim();
    const deviceType = body?.device_type?.toString().trim();
    const deviceName = body?.device_name?.toString().trim();

    if (!fcmToken) {
      return new Response(JSON.stringify({ error: "FCM token is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!deviceType) {
      return new Response(JSON.stringify({ error: "Device type is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const appUserId = await resolveAppUserId(serviceClient, {
      id: authUser.id,
      email: authUser.email,
      phone: authUser.phone,
    });

    if (!appUserId) {
      return new Response(JSON.stringify({ error: "Failed to resolve user profile" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const now = new Date().toISOString();

    const { data: existingDevice, error: existingError } = await serviceClient
      .from("user_devices")
      .select("id")
      .eq("user_id", appUserId)
      .eq("fcm_token", fcmToken)
      .maybeSingle();

    if (existingError) {
      return new Response(JSON.stringify({ error: "Failed to check existing device", details: existingError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (existingDevice?.id) {
      const { error: updateError } = await serviceClient
        .from("user_devices")
        .update({
          device_type: deviceType,
          device_name: deviceName ?? null,
          is_active: true,
          updated_at: now,
          last_seen_at: now,
        })
        .eq("id", existingDevice.id);

      if (updateError) {
        return new Response(JSON.stringify({ error: "Failed to update device", details: updateError.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } else {
      const { error: insertError } = await serviceClient.from("user_devices").insert({
        user_id: appUserId,
        fcm_token: fcmToken,
        device_type: deviceType,
        device_name: deviceName ?? null,
        is_active: true,
        created_at: now,
        updated_at: now,
        last_seen_at: now,
      });

      if (insertError) {
        return new Response(JSON.stringify({ error: "Failed to register device", details: insertError.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Device registered successfully",
      user_id: appUserId,
      token_prefix: fcmToken.slice(0, 12),
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: (error as Error).message,
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
