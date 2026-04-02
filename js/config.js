/**
 * Qlinik App Configuration (Production)
 * Dynamic data integration with Supabase.
 */

const CONFIG = {
    SUPABASE_URL: 'https://qygqrshufzumfejziluv.supabase.co',
    SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5Z3Fyc2h1Znp1bWZlanppbHV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNDA3ODcsImV4cCI6MjA5MDcxNjc4N30.PiXbrBWo7HVx5ikynVMZg_6RnUDII5ZIZkvgzXjuMbk',
    APP_NAME: 'Qlinik',
    ROLES: {
        PATIENT: 'patient',
        DOCTOR: 'doctor',
        CLINIC_ADMIN: 'clinic_admin',
        WEBSITE_ADMIN: 'website_admin'
    },
    // Hardcoded Admin
    ADMIN_USERNAME: 'Admin@Qlinik',
    ADMIN_PASSWORD: 'Qlinik@2026'
};

// Simple global reference for UMD/CDN usage if modules are not used everywhere
window.QLINIK_CONFIG = CONFIG;

export default CONFIG;
