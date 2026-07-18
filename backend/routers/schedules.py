from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import datetime
from supabase import Client
import os
from dotenv import load_dotenv

load_dotenv()

# We will pass the supabase client via dependency or just create it here for simplicity
from supabase import create_client
url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(url, key)

router = APIRouter(prefix="/api/schedules", tags=["Schedules"])

class ScheduleCreate(BaseModel):
    name: str
    schedule_type: str
    start_time: str
    end_time: str
    grace_period_minutes: int = 15
    days_of_week: Optional[List[int]] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None

@router.get("/")
def get_schedules():
    res = supabase.table("schedules").select("*").execute()
    return res.data

@router.post("/")
def create_schedule(sched: ScheduleCreate):
    data = sched.model_dump(exclude_unset=True)
    res = supabase.table("schedules").insert(data).execute()
    return res.data[0]

@router.delete("/{sched_id}")
def delete_schedule(sched_id: str):
    res = supabase.table("schedules").delete().eq("id", sched_id).execute()
    return {"message": "Deleted successfully"}

class EmployeeScheduleAssign(BaseModel):
    employee_id: str
    schedule_id: str

@router.post("/assign")
def assign_schedule(data: EmployeeScheduleAssign):
    # Upsert or Insert
    res = supabase.table("employee_schedules").insert({
        "employee_id": data.employee_id,
        "schedule_id": data.schedule_id
    }).execute()
    return res.data[0]
