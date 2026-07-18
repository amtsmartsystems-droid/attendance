from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from supabase import Client
import os
from dotenv import load_dotenv

load_dotenv()
from supabase import create_client
url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(url, key)

router = APIRouter(prefix="/api/leaves", tags=["Leaves"])

class LeaveCreate(BaseModel):
    employee_id: str
    leave_type: str
    start_date: str
    end_date: str
    reason: Optional[str] = None

class LeaveStatusUpdate(BaseModel):
    status: str # 'approved' or 'rejected'

@router.get("/")
def get_all_leaves():
    res = supabase.table("leaves").select("*, employees(full_name, emp_id)").order("created_at", desc=True).execute()
    return res.data

@router.post("/")
def create_leave(leave: LeaveCreate):
    data = leave.model_dump()
    res = supabase.table("leaves").insert(data).execute()
    return res.data[0]

@router.put("/{leave_id}/status")
def update_leave_status(leave_id: str, payload: LeaveStatusUpdate):
    if payload.status not in ["approved", "rejected", "pending"]:
        raise HTTPException(status_code=400, detail="Invalid status")
    
    res = supabase.table("leaves").update({"status": payload.status}).eq("id", leave_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Leave not found")
    return res.data[0]
