-- =========================================================================
-- 1. SETUP ENUMS & EXTENSIONS
-- =========================================================================
CREATE TYPE user_role AS ENUM ('admin_rw', 'admin_rt', 'warga');
CREATE TYPE status_hunian_type AS ENUM ('Pemilik', 'Ngontrak', 'Kos');
CREATE TYPE agama_type AS ENUM ('Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Khonghucu', 'Lainnya');
CREATE TYPE iuran_type AS ENUM ('wajib', 'insidental');
CREATE TYPE iuran_status AS ENUM ('lunas', 'belum_lunas');
CREATE TYPE kas_flow_type AS ENUM ('masuk', 'keluar');
CREATE TYPE guest_report_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE panic_status AS ENUM ('active', 'resolved');
CREATE TYPE garbage_type_enum AS ENUM ('organik', 'anorganik', 'daur_ulang', 'semua');
CREATE TYPE pickup_status AS ENUM ('pending', 'scheduled', 'completed', 'cancelled');

-- Enable UUID extension jika belum aktif
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================================
-- 2. TABEL WILAYAH (RW & RT) - MULTI-TENANCY CORE
-- =========================================================================
CREATE TABLE rw (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nomor_rw VARCHAR(10) NOT NULL UNIQUE,
    nama_rw VARCHAR(100) NOT NULL,
    alamat_sekretariat TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE rt (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rw_id UUID NOT NULL REFERENCES rw(id) ON DELETE CASCADE,
    nomor_rt VARCHAR(10) NOT NULL,
    nama_ketua_rt VARCHAR(100),
    kontak_rt VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(rw_id, nomor_rt) -- Mencegah duplikasi nomor RT di dalam satu RW
);

-- =========================================================================
-- 3. TABEL HOUSEHOLD (Keluarga / Rumah Tangga)
-- =========================================================================
CREATE TABLE households (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    nomor_kk VARCHAR(30) UNIQUE,
    alamat TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- 4. TABEL PROFILES (Warga) - Terintegrasi dengan Supabase Auth
-- =========================================================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    household_id UUID REFERENCES households(id) ON DELETE SET NULL,
    rt_id UUID NOT NULL REFERENCES rt(id),
    nama_lengkap VARCHAR(150) NOT NULL,
    nik VARCHAR(20) UNIQUE,
    no_hp VARCHAR(20),
    role user_role NOT NULL DEFAULT 'warga',
    is_head_of_household BOOLEAN NOT NULL DEFAULT false,
    status_hunian status_hunian_type NOT NULL DEFAULT 'Pemilik',
    agama agama_type NOT NULL,
    foto_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- 5. TABEL PENGUMUMAN (Targeted Broadcast)
-- =========================================================================
CREATE TABLE pengumuman (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rw_id UUID NOT NULL REFERENCES rw(id) ON DELETE CASCADE,
    rt_id UUID REFERENCES rt(id) ON DELETE CASCADE, -- NULL berarti dikirim ke semua RT di RW ini
    target_agama agama_type, -- NULL berarti untuk semua agama
    judul VARCHAR(200) NOT NULL,
    isi TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- 6. TABEL KEUANGAN (Iuran & Laporan Kas)
-- =========================================================================
CREATE TABLE iuran (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    nama_iuran VARCHAR(150) NOT NULL,
    nominal NUMERIC(12, 2) NOT NULL CHECK (nominal > 0),
    tipe iuran_type NOT NULL DEFAULT 'wajib',
    status iuran_status NOT NULL DEFAULT 'belum_lunas',
    jatuh_tempo DATE NOT NULL,
    tanggal_bayar TIMESTAMP WITH TIME ZONE,
    bukti_bayar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE kas_rt (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    tipe_aliran kas_flow_type NOT NULL,
    nominal NUMERIC(12, 2) NOT NULL CHECK (nominal > 0),
    keterangan TEXT NOT NULL,
    tanggal_transaksi DATE DEFAULT CURRENT_DATE NOT NULL,
    created_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- 7. TABEL KEAMANAN TERPADU
-- =========================================================================
CREATE TABLE satpam (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    nama VARCHAR(100) NOT NULL,
    no_hp VARCHAR(20) NOT NULL,
    foto_url TEXT,
    shift_mulai TIME NOT NULL,
    shift_selesai TIME NOT NULL,
    is_piket BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE panic_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    status panic_status NOT NULL DEFAULT 'active',
    resolved_by UUID REFERENCES profiles(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE tamu_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    nama_tamu VARCHAR(150) NOT NULL,
    nik_tamu VARCHAR(20),
    foto_ktp_url TEXT NOT NULL,
    keperluan TEXT NOT NULL,
    tanggal_masuk DATE NOT NULL,
    tanggal_keluar DATE NOT NULL,
    status guest_report_status NOT NULL DEFAULT 'pending',
    approved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- 8. TABEL PENGELOLAAN & BANK SAMPAH
-- =========================================================================
CREATE TABLE sampah_schedule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    hari VARCHAR(15) NOT NULL, -- Senin, Selasa, dll
    tipe_sampah garbage_type_enum NOT NULL DEFAULT 'semua',
    jam_pengambilan TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE sampah_pickup_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rt_id UUID NOT NULL REFERENCES rt(id) ON DELETE CASCADE,
    deskripsi TEXT,
    foto_sampah_url TEXT,
    tanggal_jemput DATE NOT NULL,
    status pickup_status NOT NULL DEFAULT 'pending',
    resolved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- 9. ROW LEVEL SECURITY (RLS) & HELPER FUNCTIONS
-- =========================================================================

-- Mendapatkan profile user yang sedang login saat ini secara cepat
CREATE OR REPLACE FUNCTION get_current_profile()
RETURNS TABLE (
    user_id UUID,
    user_role user_role,
    user_rt_id UUID,
    user_household_id UUID,
    user_agama agama_type
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.role, p.rt_id, p.household_id, p.agama
    FROM public.profiles p
    WHERE p.id = auth.uid();
END;
$$ LANGUAGE plpgsql;

-- Aktifkan RLS pada seluruh tabel
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE pengumuman ENABLE ROW LEVEL SECURITY;
ALTER TABLE iuran ENABLE ROW LEVEL SECURITY;
ALTER TABLE kas_rt ENABLE ROW LEVEL SECURITY;
ALTER TABLE satpam ENABLE ROW LEVEL SECURITY;
ALTER TABLE panic_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tamu_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE sampah_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE sampah_pickup_requests ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- POLICY UNTUK PROFILES
-- =========================================================================
CREATE POLICY "RW Admin can view and edit all profiles" 
ON profiles TO authenticated
USING ( (SELECT user_role FROM get_current_profile()) = 'admin_rw' )
WITH CHECK ( (SELECT user_role FROM get_current_profile()) = 'admin_rw' );

CREATE POLICY "RT Admin can view and edit profiles in their RT" 
ON profiles TO authenticated
USING ( 
    (SELECT user_role FROM get_current_profile()) = 'admin_rt' 
    AND rt_id = (SELECT user_rt_id FROM get_current_profile())
)
WITH CHECK (
    (SELECT user_role FROM get_current_profile()) = 'admin_rt' 
    AND rt_id = (SELECT user_rt_id FROM get_current_profile())
);

CREATE POLICY "Warga can view profiles in their own RT" 
ON profiles FOR SELECT TO authenticated
USING ( rt_id = (SELECT user_rt_id FROM get_current_profile()) );

CREATE POLICY "Warga can update their own profile" 
ON profiles FOR UPDATE TO authenticated
USING ( id = auth.uid() )
WITH CHECK ( id = auth.uid() );

-- =========================================================================
-- POLICY UNTUK HOUSEHOLDS
-- =========================================================================
CREATE POLICY "RT & RW admins can manage households in their territory"
ON households TO authenticated
USING (
    (SELECT user_role FROM get_current_profile()) = 'admin_rw'
    OR (
        (SELECT user_role FROM get_current_profile()) = 'admin_rt'
        AND rt_id = (SELECT user_rt_id FROM get_current_profile())
    )
);

CREATE POLICY "Warga can view their own household data"
ON households FOR SELECT TO authenticated
USING ( id = (SELECT user_household_id FROM get_current_profile()) );

-- =========================================================================
-- POLICY UNTUK IURAN (Sangat Ketat: Warga hanya bisa melihat iuran keluarga)
-- =========================================================================
CREATE POLICY "RW & RT admins can manage iuran"
ON iuran TO authenticated
USING (
    (SELECT user_role FROM get_current_profile()) = 'admin_rw'
    OR (
        (SELECT user_role FROM get_current_profile()) = 'admin_rt'
        AND rt_id = (SELECT user_rt_id FROM get_current_profile())
    )
);

CREATE POLICY "Warga can view their household iuran"
ON iuran FOR SELECT TO authenticated
USING ( household_id = (SELECT user_household_id FROM get_current_profile()) );

-- =========================================================================
-- POLICY UNTUK KAS RT
-- =========================================================================
CREATE POLICY "RW & RT admins can manage kas_rt"
ON kas_rt TO authenticated
USING (
    (SELECT user_role FROM get_current_profile()) = 'admin_rw'
    OR (
        (SELECT user_role FROM get_current_profile()) = 'admin_rt'
        AND rt_id = (SELECT user_rt_id FROM get_current_profile())
    )
);

CREATE POLICY "Warga can view their RT cash reports"
ON kas_rt FOR SELECT TO authenticated
USING ( rt_id = (SELECT user_rt_id FROM get_current_profile()) );

-- =========================================================================
-- POLICY UNTUK PENGUMUMAN (Targeted Broadcast RLS)
-- =========================================================================
CREATE POLICY "Admins can manage pengumuman"
ON pengumuman TO authenticated
USING (
    (SELECT user_role FROM get_current_profile()) IN ('admin_rw', 'admin_rt')
);

CREATE POLICY "Warga can view pengumuman according to RT and Religion"
ON pengumuman FOR SELECT TO authenticated
USING (
    -- Pengumuman tingkat RW (rt_id IS NULL) atau spesifik RT warga sendiri
    (rt_id IS NULL OR rt_id = (SELECT user_rt_id FROM get_current_profile()))
    AND
    -- Pengumuman umum (target_agama IS NULL) atau spesifik agama warga
    (target_agama IS NULL OR target_agama = (SELECT user_agama FROM get_current_profile()))
);

-- =========================================================================
-- POLICY UNTUK KEAMANAN (Panic Alerts & Tamu)
-- =========================================================================
CREATE POLICY "Users can create and view panic alerts in their RT"
ON panic_alerts TO authenticated
USING (
    (SELECT user_role FROM get_current_profile()) = 'admin_rw'
    OR rt_id = (SELECT user_rt_id FROM get_current_profile())
);

CREATE POLICY "Warga can manage their guest reports"
ON tamu_reports TO authenticated
USING (
    reporter_id = auth.uid()
    OR (SELECT user_role FROM get_current_profile()) = 'admin_rt' AND rt_id = (SELECT user_rt_id FROM get_current_profile())
    OR (SELECT user_role FROM get_current_profile()) = 'admin_rw'
);

-- =========================================================================
-- POLICY UNTUK SAMPAH (Schedule & Pickup Requests)
-- =========================================================================
CREATE POLICY "RW & RT admins can manage sampah schedule"
ON sampah_schedule TO authenticated
USING (
    (SELECT user_role FROM get_current_profile()) = 'admin_rw'
    OR (
        (SELECT user_role FROM get_current_profile()) = 'admin_rt'
        AND rt_id = (SELECT user_rt_id FROM get_current_profile())
    )
);

CREATE POLICY "Warga can view their RT sampah schedule"
ON sampah_schedule FOR SELECT TO authenticated
USING ( rt_id = (SELECT user_rt_id FROM get_current_profile()) );

CREATE POLICY "Warga can manage their sampah pickup requests"
ON sampah_pickup_requests TO authenticated
USING (
    profile_id = auth.uid()
    OR (SELECT user_role FROM get_current_profile()) = 'admin_rt' AND rt_id = (SELECT user_rt_id FROM get_current_profile())
    OR (SELECT user_role FROM get_current_profile()) = 'admin_rw'
);
