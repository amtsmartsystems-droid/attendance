-- =========================================================================
-- Onboarding Schema Updates: Zero-Touch Onboarding and Walk-ins
-- =========================================================================

DO $$
BEGIN
    -- 1. Add 'status' column if it doesn't exist, defaulting to 'approved' for existing employees
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='status') THEN
        ALTER TABLE employees ADD COLUMN status TEXT DEFAULT 'approved' CHECK (status IN ('approved', 'pending', 'rejected'));
    END IF;
    
    -- 2. Add 'phone_number' column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='phone_number') THEN
        ALTER TABLE employees ADD COLUMN phone_number TEXT;
    END IF;
END $$;
