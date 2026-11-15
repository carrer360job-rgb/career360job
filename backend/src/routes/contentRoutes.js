import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';

const router = express.Router();
const publicKinds = new Set(['category', 'announcement']);

const defaultCategories = [
  { id: 'it-software', title: 'IT & Software', content: 'Software, Web, Mobile, Data & Tech', sortOrder: 1 },
  { id: 'manufacturing', title: 'Manufacturing', content: 'Production, Assembly & Plant operations', sortOrder: 2 },
  { id: 'sales-marketing', title: 'Sales & Marketing', content: 'B2B/B2C Sales, Digital Marketing, Retail', sortOrder: 3 },
  { id: 'finance-accounting', title: 'Finance & Accounting', content: 'Accounting, Banking, Auditing & Taxation', sortOrder: 4 },
  { id: 'healthcare', title: 'Healthcare & Medical', content: 'Nursing, Pharmacy, Clinic & Lab Staff', sortOrder: 5 },
  { id: 'education', title: 'Education & Teaching', content: 'Tutors, Teachers, Academic counselors', sortOrder: 6 },
  { id: 'customer-support', title: 'Customer Support', content: 'Call center, Voice/Non-voice, Helpdesk', sortOrder: 7 },
  { id: 'logistics', title: 'Logistics & Operations', content: 'Warehouse, Supply chain, Delivery & Fleet', sortOrder: 8 },
  { id: 'hospitality', title: 'Hospitality', content: 'Hotels, Restaurants, Catering & Tourism', sortOrder: 9 },
  { id: 'other', title: 'Other Opportunities', content: 'General staffing and verified openings', sortOrder: 10 },
];

const defaultAnnouncements = [
  { id: 'launch', title: 'Welcome to Career360', content: 'Verified job platform for candidates and employers across Tamil Nadu and Pan-India.', sortOrder: 1 },
];

router.get('/', async (req, res) => {
  const kind = typeof req.query.kind === 'string' ? req.query.kind : '';
  if (!publicKinds.has(kind)) {
    return res.status(400).json({ error: { message: 'Choose a valid content type.' } });
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('platform_content')
      .select('id, title, content, sort_order')
      .eq('kind', kind)
      .eq('active', true)
      .order('sort_order', { ascending: true });

    if (!error && data && data.length > 0) {
      const items = data.map((d) => ({
        id: d.id,
        title: d.title || '',
        content: d.content || '',
        sortOrder: d.sort_order || 0,
      }));
      return res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=300').json({ items });
    }
  } catch (_) {}

  const fallback = kind === 'category' ? defaultCategories : defaultAnnouncements;
  res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=300').json({ items: fallback });
});

export default router;
