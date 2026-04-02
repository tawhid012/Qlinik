/**
 * Data Service for Qlinik
 * Handles all Supabase DB operations.
 */

import { getSupabase } from '../supabase-client.js';

export const dataService = {
  /**
   * Fetch doctors with optional filters
   */
  async getDoctors(filters = {}) {
    const supabase = getSupabase();
    let query = supabase
      .from('doctors')
      .select(`
        *,
        profiles:user_id (full_name, avatar_url),
        doctor_clinics (
          clinics (*)
        )
      `)
      .eq('is_active', true);

    if (filters.specialization) {
      query = query.ilike('specialization', `%${filters.specialization}%`);
    }
    
    // Simplistic location filter (assumes clinics listed for doctor)
    if (filters.location) {
        // This would ideally be a more complex spatial query or join
        // For now, we'll filter on the client or using inner joins if possible
    }

    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  /**
   * Fetch featured doctors for homepage
   */
  async getFeaturedDoctors(limit = 3) {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('doctors')
      .select(`
        *,
        profiles:user_id (full_name, avatar_url)
      `)
      .limit(limit)
      .order('rating', { ascending: false });

    if (error) throw error;
    return data;
  },

  /**
   * Fetch clinics for homepage
   */
  async getFeaturedClinics(limit = 4) {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('clinics')
      .select('*')
      .limit(limit);

    if (error) throw error;
    return data;
  },

  /**
   * Get full doctor profile with linked clinics and schedules
   */
  async getDoctorById(id) {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('doctors')
      .select(`
        *,
        profiles:user_id (*),
        doctor_clinics (
            *,
            clinics (*)
        )
      `)
      .eq('id', id)
      .single();

    if (error) throw error;
    return data;
  },

  /**
   * Create an appointment and generate a token
   */
  async createAppointment(formData) {
    const supabase = getSupabase();
    
    // 1. Get current count for this queue today to generate token
    const today = new Date().toISOString().split('T')[0];
    const { count, error: countError } = await supabase
      .from('appointments')
      .select('*', { count: 'exact', head: true })
      .eq('queue_date', today)
      .eq('doctor_id', formData.doctor_id)
      .eq('clinic_id', formData.clinic_id);

    if (countError) throw countError;

    const tokenNumber = (count || 0) + 1;
    
    // 2. Insert the appointment
    const { data, error } = await supabase
      .from('appointments')
      .insert({
        ...formData,
        token_number: tokenNumber,
        queue_date: today,
        status: 'waiting'
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  /**
   * Subscribe to real-time updates for a specific queue
   */
  subscribeToQueue(queueId, onUpdate) {
    const supabase = getSupabase();
    return supabase
      .channel(`queue-${queueId}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'appointments', filter: `id=eq.${queueId}` },
        (payload) => onUpdate(payload.new)
      )
      .subscribe();
  }
};
