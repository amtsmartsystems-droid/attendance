import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---- المفتاح السري لتوقيع HMAC — يجب أن يطابق ما في التطبيق ----
const HMAC_SECRET = Deno.env.get("HMAC_SECRET") ?? "AMT_SECURE_HMAC_KEY_v2_2024_XK9!";

// ---- التحقق من توقيع HMAC-SHA256 ----
async function verifyHmac(
  data: Record<string, string>,
  signature: string
): Promise<boolean> {
  const sortedKeys = Object.keys(data).sort();
  const payload = sortedKeys.map((k) => `${k}=${data[k]}`).join("&");

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(HMAC_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload)
  );

  const hex = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return hex === signature;
}

serve(async (req) => {
  // CORS headers
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, x-nonce, x-signature",
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
    const { emp_id, door_nfc_uid } = body;

    const nonce     = req.headers.get("X-Nonce") ?? "";
    const signature = req.headers.get("X-Signature") ?? "";

    if (!emp_id || !door_nfc_uid || !nonce) {
      return new Response(
        JSON.stringify({ success: false, message: "بيانات ناقصة" }),
        { status: 400, headers }
      );
    }

    const isValidSignature = await verifyHmac(
      { employee_id: emp_id, nonce, tag_code: door_nfc_uid },
      signature
    );

    if (!isValidSignature) {
      return new Response(
        JSON.stringify({ success: false, message: "توقيع الطلب غير صالح" }),
        { status: 401, headers }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: existingNonce } = await supabase
      .from("attendance_logs")
      .select("id")
      .eq("nonce", nonce)
      .single();

    if (existingNonce) {
      return new Response(
        JSON.stringify({ success: false, message: "طلب مكرر — تم رفضه" }),
        { status: 409, headers }
      );
    }

    const { data: door, error: doorError } = await supabase
      .from("doors")
      .select("id, door_name")
      .eq("nfc_uid", door_nfc_uid)
      .eq("is_active", true)
      .single();

    if (doorError || !door) {
      return new Response(
        JSON.stringify({ success: false, message: "الباب غير معرّف في النظام" }),
        { status: 404, headers }
      );
    }

    const { data: employee, error: empError } = await supabase
      .from("employees")
      .select("id, full_name")
      .eq("emp_id", emp_id)
      .eq("is_active", true)
      .single();

    if (empError || !employee) {
      return new Response(
        JSON.stringify({ success: false, message: "الموظف غير مسجّل في النظام" }),
        { status: 404, headers }
      );
    }

    const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();

    const { data: recentLog } = await supabase
      .from("attendance_logs")
      .select("id, recorded_at")
      .eq("employee_id", employee.id)
      .gte("recorded_at", oneMinuteAgo)
      .single();

    if (recentLog) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "تم تسجيل حركة مؤخراً — يرجى الانتظار دقيقة",
        }),
        { status: 429, headers }
      );
    }

    const { data: lastLog } = await supabase
      .from("attendance_logs")
      .select("movement_type")
      .eq("employee_id", employee.id)
      .order("recorded_at", { ascending: false })
      .limit(1)
      .single();

    const movementType =
      !lastLog || lastLog.movement_type === "خروج" ? "دخول" : "خروج";

    const { data: log, error: logError } = await supabase
      .from("attendance_logs")
      .insert({
        employee_id:    employee.id,
        door_id:        door.id,
        movement_type:  movementType,
        nonce:          nonce,
        hmac_signature: signature,
      })
      .select()
      .single();

    if (logError) {
      throw logError;
    }

    return new Response(
      JSON.stringify({
        success:         true,
        message:         `تم تسجيل ${movementType} بنجاح`,
        attendance_id:   log.id,
        attendance_type: movementType,
        employee_name:   employee.full_name,
        door_name:       door.door_name,
        server_time:     log.recorded_at,
      }),
      { status: 200, headers }
    );
  } catch (err) {
    console.error("Error:", err);
    return new Response(
      JSON.stringify({ success: false, message: "خطأ داخلي في السيرفر" }),
      { status: 500, headers }
    );
  }
});
