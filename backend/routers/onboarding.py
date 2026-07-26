"""
ملف: backend/routers/onboarding.py
الوصف: API تسجيل المتدربين مع دعم نظام عزل الدورات
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from supabase import Client
import os
import uuid
from dotenv import load_dotenv

load_dotenv()
from supabase import create_client
url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(url, key)

router = APIRouter(prefix="/api/onboarding", tags=["Onboarding"])

def mask_name(full_name: str, phone: str = None) -> str:
    parts = full_name.split()
    first_name = parts[0] if parts else ""
    if phone and len(phone) >= 3:
        masked = f"{first_name} - ****{phone[-3:]}"
    else:
        masked = f"{first_name} - ****"
    return masked


# ── GET /api/onboarding/list/{nfc_uid} ───────────────────────────────────
# يُعيد قائمة المتدربين المسجلين في الدورة المرتبطة بهذا الـ NFC فقط

@router.get("/list/{nfc_uid}")
def get_masked_list(nfc_uid: str):
    # 1. جلب الباب والتحقق أنه مرتبط بدورة
    res_door = supabase.table("doors").select("id, course_id, door_name").eq("nfc_uid", nfc_uid).execute()
    if not res_door.data:
        raise HTTPException(status_code=404, detail="Bad NFC Tag / Invalid Session")

    door = res_door.data[0]
    course_id = door.get("course_id")

    # 2. جلب بيانات الدورة
    course_info = None
    if course_id:
        course_res = supabase.table("courses").select("*").eq("id", course_id).execute()
        if course_res.data:
            course_info = course_res.data[0]

    # 3. جلب المتدربين المسجلين في هذه الدورة فقط (إذا كانت مرتبطة)
    # إذا لم تكن الدورة مرتبطة نُعيد كل الموظفين (للتوافق مع القديم)
    if course_id:
        enroll_res = supabase.table("course_enrollments") \
            .select("employee_id, employees(id, full_name, phone_number, status)") \
            .eq("course_id", course_id) \
            .execute()
        employees = [e["employees"] for e in (enroll_res.data or []) if e.get("employees")]
    else:
        emp_res = supabase.table("employees").select("id, full_name, phone_number, status").execute()
        employees = emp_res.data or []

    masked_list = []
    for emp in employees:
        if emp and emp.get("status") != "rejected":
            masked_list.append({
                "id": emp["id"],
                "masked_name": mask_name(emp["full_name"], emp.get("phone_number")),
                "status": emp.get("status", "pending"),
            })

    return {
        "masked_employees": masked_list,
        "course": course_info,   # ✅ نُعيد معلومات الدورة للتطبيق
        "door_name": door.get("door_name"),
    }


# ── POST /api/onboarding/fast-track ──────────────────────────────────────
# تسجيل دخول متدرب موجود مسبقاً

class FastTrackRequest(BaseModel):
    employee_id: str
    pin_code: str
    device_id: str
    course_id: Optional[str] = None  # ✅ جديد

@router.post("/fast-track")
def fast_track_onboarding(req: FastTrackRequest):
    res = supabase.table("employees").select("*").eq("id", req.employee_id).eq("pin_code", req.pin_code).execute()
    if not res.data:
        raise HTTPException(status_code=401, detail="Invalid PIN or Employee")

    emp = res.data[0]

    # إذا كان مربوطاً بجهاز مختلف نرفض
    if emp.get("is_device_bound") and emp.get("device_id") and emp.get("device_id") != req.device_id:
        raise HTTPException(status_code=403, detail="Device already bound to another phone.")

    # تفعيل وربط الجهاز
    update_res = supabase.table("employees").update({
        "is_device_bound": True,
        "device_id": req.device_id,
        "status": "approved"
    }).eq("id", req.employee_id).execute()

    # ✅ تسجيله في الدورة إن لم يكن مسجلاً
    if req.course_id:
        try:
            supabase.table("course_enrollments").insert({
                "course_id": req.course_id,
                "employee_id": req.employee_id,
            }).execute()
        except Exception:
            pass  # مسجل مسبقاً — لا مشكلة

    return {"message": "Success", "employee": update_res.data[0] if update_res.data else emp}


# ── POST /api/onboarding/walk-in ─────────────────────────────────────────
# تسجيل متدرب جديد (Walk-in)

class WalkInRequest(BaseModel):
    full_name: str
    phone_number: str
    pin_code: str
    department: str = "Guest / Walk-in"
    device_id: str
    course_id: Optional[str] = None  # ✅ جديد

@router.post("/walk-in")
def walk_in_onboarding(req: WalkInRequest):
    emp_id_str = f"WALK_{str(uuid.uuid4())[:6].upper()}"
    res = supabase.table("employees").insert({
        "emp_id": emp_id_str,
        "full_name": req.full_name,
        "department": req.department,
        "phone_number": req.phone_number,
        "pin_code": req.pin_code,
        "is_device_bound": True,
        "device_id": req.device_id,
        "status": "approved"   # ✅ موافق تلقائياً لتجربة سلسة
    }).execute()

    if not res.data:
        raise HTTPException(status_code=500, detail="فشل في إنشاء الحساب")

    emp = res.data[0]

    # ✅ تسجيله في الدورة تلقائياً
    if req.course_id:
        try:
            supabase.table("course_enrollments").insert({
                "course_id": req.course_id,
                "employee_id": emp["id"],
            }).execute()
        except Exception:
            pass

    return {"message": "تم إنشاء حسابك بنجاح", "employee": emp}


# ── PUT /api/onboarding/bulk-approve ─────────────────────────────────────

class BulkApproveRequest(BaseModel):
    employee_ids: List[str]

@router.put("/bulk-approve")
def bulk_approve(req: BulkApproveRequest):
    if not req.employee_ids:
        return {"message": "No IDs provided"}
    updated = []
    for eid in req.employee_ids:
        res = supabase.table("employees").update({"status": "approved"}).eq("id", eid).execute()
        if res.data:
            updated.append(res.data[0])
    return {"message": f"Approved {len(updated)} employees", "updated": updated}
