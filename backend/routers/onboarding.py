from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
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
        # Fallback mask if no phone
        masked = f"{first_name} - ****"
    return masked

@router.get("/list/{nfc_uid}")
def get_masked_list(nfc_uid: str):
    # Verify NFC UID belongs to a valid door/session
    res_door = supabase.table("doors").select("id").eq("nfc_uid", nfc_uid).execute()
    if not res_door.data:
        raise HTTPException(status_code=404, detail="Bade NFC Tag / Invalid Session")
        
    # Get all approved and pending employees (for the fast track)
    res_emp = supabase.table("employees").select("id, full_name, phone_number, status").execute()
    
    masked_list = []
    for emp in res_emp.data:
        masked_list.append({
            "id": emp["id"],
            "masked_name": mask_name(emp["full_name"], emp.get("phone_number")),
            "status": emp["status"]
        })
        
    return {"masked_employees": masked_list}

class FastTrackRequest(BaseModel):
    employee_id: str
    pin_code: str
    device_id: str

@router.post("/fast-track")
def fast_track_onboarding(req: FastTrackRequest):
    # Verify employee and PIN
    res = supabase.table("employees").select("*").eq("id", req.employee_id).eq("pin_code", req.pin_code).execute()
    if not res.data:
        raise HTTPException(status_code=401, detail="Invalid PIN or Employee")
        
    emp = res.data[0]
    
    # Check if already bound
    if emp.get("is_device_bound"):
        raise HTTPException(status_code=403, detail="Device already bound to another phone.")
        
    # Auto-Approve and Bind
    update_res = supabase.table("employees").update({
        "is_device_bound": True,
        "device_id": req.device_id,
        "status": "approved"
    }).eq("id", req.employee_id).execute()
    
    return {"message": "Success", "employee": update_res.data[0]}

class WalkInRequest(BaseModel):
    full_name: str
    phone_number: str
    pin_code: str
    department: str = "Guest / Walk-in"
    device_id: str

@router.post("/walk-in")
def walk_in_onboarding(req: WalkInRequest):
    # Create new employee as 'pending'
    emp_id_str = f"WALK_{str(uuid.uuid4())[:6].upper()}"
    res = supabase.table("employees").insert({
        "emp_id": emp_id_str,
        "full_name": req.full_name,
        "department": req.department,
        "phone_number": req.phone_number,
        "pin_code": req.pin_code,
        "is_device_bound": True,
        "device_id": req.device_id,
        "status": "pending"
    }).execute()
    
    return {"message": "Pending Admin Approval", "employee": res.data[0]}

class BulkApproveRequest(BaseModel):
    employee_ids: List[str]

@router.put("/bulk-approve")
def bulk_approve(req: BulkApproveRequest):
    if not req.employee_ids:
        return {"message": "No IDs provided"}
        
    # Supabase Python client doesn't support an elegant 'IN' update directly easily for multiple rows,
    # so we iterate. In production, an RPC call or direct postgres query is better.
    updated = []
    for eid in req.employee_ids:
        res = supabase.table("employees").update({"status": "approved"}).eq("id", eid).execute()
        if res.data:
            updated.append(res.data[0])
            
    return {"message": f"Approved {len(updated)} employees", "updated": updated}
