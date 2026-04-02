/**
 * Supabase Client Initialization
 * Relies on Supabase JS CDN: https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2
 */

import CONFIG from './config.js';

let supabaseInstance = null;

export const getSupabase = () => {
    if (!supabaseInstance) {
        if (typeof supabase === 'undefined') {
            console.error('Supabase library not loaded. Ensure the CDN script is included in your HTML.');
            return null;
        }
        supabaseInstance = supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
    }
    return supabaseInstance;
};

// Global reference for legacy script support
window.getSupabase = getSupabase;
