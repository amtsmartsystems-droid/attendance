-- =========================================================================
-- Phase 3 Schema Updates: RBAC, Schedules, Leaves, and Notifications
-- =========================================================================

-- 1. Update Employees Table with Role and Email
-- Using DO block to safely add columns if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='role') THEN
        ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee' CHECK (role IN ('admin', 'staff', 'employee'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='email') THEN
        ALTER TABLE employees ADD COLUMN email TEXT;
    END IF;
END $$;

-- 2. Create Schedules Table
CREATE TABLE IF NOT EXISTS schedules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    schedule_type TEXT CHECK (schedule_type IN ('recurring', 'temporary')) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    grace_period_minutes INT DEFAULT 15,
    days_of_week JSONB, -- e.g., [0,1,2,3,4] where 0 is Sunday
    start_date DATE,    -- For temporary sessions
    end_date DATE,      -- For temporary sessions
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create Employee-Schedules Mapping Table
CREATE TABLE IF NOT EXISTS employee_schedules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, schedule_id)
);

-- 4. Create Leaves Table
CREATE TABLE IF NOT EXISTS leaves (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    leave_type TEXT NOT NULL, -- e.g., 'Sick', 'Annual', 'Unpaid'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create Notifications Table (In-App Dashboard)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- e.g., 'late', 'absent', 'leave_request'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. RLS Policies Updates
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Note: Because we are using the Backend (FastAPI) with Service Role Key for all logic, 
-- we keep default deny policies (empty) for these tables just like the rest of the system.
-- This ensures the DB is 100% secure from direct client queries.
