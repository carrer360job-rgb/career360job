import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://nnilnwhjpkllmocptmks.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uaWxud2hqcGtsbG1vY3B0bWtzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ3MzEzNjIsImV4cCI6MjExMDMwNzM2Mn0.L4WpFSA5Gi3QIjldy_LdbptrtfDLGoYpx7PkLwqYHyI';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

let cachedUid = '';
supabase.auth.getSession().then(({ data: { session } }) => {
  if (session?.user?.id) cachedUid = session.user.id;
});
supabase.auth.onAuthStateChange((_event, session) => {
  cachedUid = session?.user?.id || '';
});

export async function getAccessToken(): Promise<string> {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.access_token || '';
}

export const auth = {
  get currentUser() {
    return {
      get uid(): string {
        return cachedUid;
      },
      async getIdToken(): Promise<string> {
        return getAccessToken();
      }
    };
  },
  async signOut(): Promise<void> {
    await supabase.auth.signOut();
  }
};

export default supabase;
