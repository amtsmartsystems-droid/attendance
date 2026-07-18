import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Admin PIN for extra security
const ADMIN_PIN = Deno.env.get("ADMIN_PIN") ?? "1234";

serve(async (req) => {
  // CORS headers
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers,
    });
  }

  try {
    const body = await req.json();
    const { door_name, location, nfc_uid, admin_pin } = body;

    if (!door_name || !nfc_uid || !admin_pin) {
      return new Response(
        JSON.stringify({ success: false, message: "بيانات ناقصة" }),
        { status: 400, headers }
      );
    }

    if (admin_pin !== ADMIN_PIN) {
      return new Response(
        JSON.stringify({ success: false, message: "رمز الإدارة غير صحيح" }),
        { status: 401, headers }
      );
    }

    // Connect to Supabase using Service Role to bypass RLS for inserting
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Generate a unique door_id based on timestamp
    const uniqueDoorId = `DOOR_${Date.now()}`;

    // Insert or update door based on nfc_uid
    const { data, error } = await supabase
      .from("doors")
      .upsert({
        door_id: uniqueDoorId,
        door_name: door_name,
        location: location ?? "غير محدد",
        nfc_uid: nfc_uid,
        is_active: true
      }, { onConflict: "nfc_uid" })
      .select()
      .single();

    if (error) {
      throw error;
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "تمت إضافة الباب بنجاح",
        door: data
      }),
      { status: 200, headers }
    );
  } catch (err) {
    console.error("Error assigning door:", err);
    return new Response(
      JSON.stringify({ success: false, message: "خطأ داخلي في السيرفر" }),
      { status: 500, headers }
    );
  }
});
