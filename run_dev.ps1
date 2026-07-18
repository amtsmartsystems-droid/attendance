# =====================================================
# ملف: run_dev.ps1
# الوصف: تشغيل تطبيق Flutter في وضع التطوير
#         مع حقن المفاتيح عبر --dart-define
#
# الاستخدام: .\run_dev.ps1
# =====================================================

$SUPABASE_URL     = "https://oiyoeftvpwpiwovqqhum.supabase.co"
$SUPABASE_ANON_KEY = "sb_publishable_gg37Prs1Z7HW9jKRIVnelQ_8M9Oiz8T"
$HMAC_SECRET      = "AMT_SECURE_HMAC_KEY_v2_2024_XK9!"
$BACKEND_URL      = "http://10.0.2.2:8000"

flutter run `
  --dart-define=SUPABASE_URL=$SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY `
  --dart-define=HMAC_SECRET=$HMAC_SECRET `
  --dart-define=BACKEND_URL=$BACKEND_URL
