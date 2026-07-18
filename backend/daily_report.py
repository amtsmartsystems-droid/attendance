import os
import smtplib
from email.message import EmailMessage
from datetime import datetime, timezone
from supabase import create_client, Client
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def generate_daily_report():
    print("Starting daily report generation...")
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    
    # Fetch all attendance for today
    # Note: attendance_view returns local time date string as 'YYYY-MM-DD'
    res = supabase.table("attendance_view").select("*").eq("date", today_str).execute()
    logs = res.data

    if not logs:
        print("No attendance recorded today.")
        logs = []

    df = pd.DataFrame(logs)
    
    report_filename = f"daily_report_{today_str}.xlsx"
    if not df.empty:
        df.to_excel(report_filename, index=False)
        print(f"Report generated: {report_filename}")
    else:
        # Create an empty template if no logs
        df = pd.DataFrame(columns=["employee_name", "emp_id", "department", "movement_type", "time", "door_name"])
        df.to_excel(report_filename, index=False)

    # In a real production system, send this via email using SMTP or SendGrid:
    # send_email(report_filename)
    
    # For MVP, we save it locally so Render or the Admin Dashboard can serve it.
    # We will upload it to Supabase Storage!
    print("Uploading report to Supabase Storage...")
    
    # Check if bucket exists, if not, this will just fail gracefully or we can assume it exists.
    # We'll just upload to a 'reports' bucket.
    try:
        with open(report_filename, "rb") as f:
            supabase.storage.from_("reports").upload(
                path=report_filename,
                file=f,
                file_options={"content-type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}
            )
        print("Report successfully uploaded to Supabase Storage (reports bucket)!")
    except Exception as e:
        print(f"Could not upload to Supabase: {e}")
        print("Make sure you have created a public bucket named 'reports' in Supabase Storage.")

if __name__ == "__main__":
    generate_daily_report()
