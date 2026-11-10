let app = null;

export default async function handler(req, res) {
  try {
    if (!app) {
      const mod = await import('../src/index.js');
      app = mod.default;
    }
    return app(req, res);
  } catch (err) {
    console.error('[Vercel Serverless Error]', err);
    return res.status(500).json({
      error: 'Cold start failure',
      message: err.message,
      stack: err.stack,
    });
  }
}
