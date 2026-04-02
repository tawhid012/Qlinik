-- Supabase Schema for Qlinik

-- 1. Profiles (RBAC)
CREATE TYPE user_role AS ENUM ('patient', 'doctor', 'clinic_admin', 'website_admin');

CREATE TABLE profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    role user_role DEFAULT 'patient' NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Clinics
CREATE TABLE clinics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT,
    location_point POINT, -- For spatial searches
    description TEXT,
    contact_phone TEXT,
    logo_url TEXT,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Doctors
CREATE TABLE doctors (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    specialization TEXT NOT NULL,
    bio TEXT,
    experience_years INTEGER,
    registration_id TEXT UNIQUE,
    rating DECIMAL(3,2) DEFAULT 4.5,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Doctor-Clinic Links (Schedule & Fees)
CREATE TABLE doctor_clinics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    doctor_id UUID REFERENCES doctors(id) ON DELETE CASCADE NOT NULL,
    clinic_id UUID REFERENCES clinics(id) ON DELETE CASCADE NOT NULL,
    consultation_fee DECIMAL(10,2) NOT NULL,
    schedule JSONB, -- Example: {"monday": ["09:00-12:00", "15:00-18:00"], ...}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(doctor_id, clinic_id)
);

-- 5. Queues (Daily tracking)
CREATE TABLE queues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    doctor_id UUID REFERENCES doctors(id) ON DELETE CASCADE NOT NULL,
    clinic_id UUID REFERENCES clinics(id) ON DELETE CASCADE NOT NULL,
    queue_date DATE DEFAULT CURRENT_DATE NOT NULL,
    status TEXT CHECK (status IN ('open', 'paused', 'closed')) DEFAULT 'open',
    current_token_serving INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,
    delay_minutes INTEGER DEFAULT 0, -- For the delay system
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(doctor_id, clinic_id, queue_date)
);

-- 6. Tokens (Patient appointments)
CREATE TABLE tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    queue_id UUID REFERENCES queues(id) ON DELETE CASCADE NOT NULL,
    patient_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Null for walk-ins
    token_number INTEGER NOT NULL,
    status TEXT CHECK (status IN ('waiting', 'serving', 'completed', 'cancelled', 'no-show')) DEFAULT 'waiting',
    patient_info JSONB, -- For walk-ins or guest bookings: {name, phone, age, gender, reason}
    is_walk_in BOOLEAN DEFAULT false,
    expected_time TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ROW LEVEL SECURITY (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE queues ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;

-- Policies (Basic examples)
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Clinics are viewable by everyone" ON clinics FOR SELECT USING (true);
CREATE POLICY "Clinics are editable by owner" ON clinics FOR ALL USING (auth.uid() = owner_id);

CREATE POLICY "Doctors are viewable by everyone" ON doctors FOR SELECT USING (true);
CREATE POLICY "Doctors can update own profile" ON doctors FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Queues are viewable by everyone" ON queues FOR SELECT USING (true);
CREATE POLICY "Queues can be managed by clinic owners or doctors" ON queues FOR ALL 
USING (
    EXISTS (SELECT 1 FROM clinics WHERE id = clinic_id AND owner_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM doctors WHERE id = doctor_id AND user_id = auth.uid())
);

CREATE POLICY "Patients can view their own tokens" ON tokens FOR SELECT 
USING (auth.uid() = patient_id OR EXISTS (
    SELECT 1 FROM queues q 
    JOIN clinics c ON q.clinic_id = c.id 
    WHERE q.id = queue_id AND (c.owner_id = auth.uid() OR q.doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()))
));
