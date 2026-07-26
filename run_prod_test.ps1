# =====================================================
# ملف: run_prod_test.ps1
# الوصف: تشغيل تطبيق الموبايل متصلاً بالسيرفر السحابي
# =====================================================

$SUPABASE_URL     = "https://oiyoeftvpwpiwovqqhum.supabase.co"
$SUPABASE_ANON_KEY = "sb_publishable_gg37Prs1Z7HW9jKRIVnelQ_8M9Oiz8T"
$HMAC_SECRET      = "AMT_SECURE_HMAC_KEY_v2_2024_XK9!"
$BACKEND_URL      = "https://attendance-yty9.onrender.com"

flutter run `
  --dart-define=SUPABASE_URL=$SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY `
  --dart-define=HMAC_SECRET=$HMAC_SECRET `
  --dart-define=BACKEND_URL=$BACKEND_URL
