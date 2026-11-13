import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import authRoutes from './routes/authRoutes.js';
import resumeRoutes from './routes/resumeRoutes.js';
import profilePhotoRoutes from './routes/profilePhotoRoutes.js';
import { firebaseApp } from './config/firebase.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Security & Cross-Origin Middleware
app.use(helmet());
app.use(cors({
  origin: true,
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'Job Portal Core API',
    version: '1.0.0',
  });
});

// Configuration readiness for the resume upload flow; never returns secrets.
app.get('/api/resumes/ready', (req, res) => {
  const firebaseAdmin = firebaseApp != null;
  const cloudinary = Boolean(
    process.env.CLOUDINARY_CLOUD_NAME &&
    process.env.CLOUDINARY_API_KEY &&
    process.env.CLOUDINARY_API_SECRET,
  );
  res.status(firebaseAdmin && cloudinary ? 200 : 503).json({ firebaseAdmin, cloudinary });
});

// Root route
app.get('/', (req, res) => {
  res.json({ message: 'Job Portal Backend API is active' });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/resumes', resumeRoutes);
app.use('/api/profile-photo', profilePhotoRoutes);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Unhandled Error]', err);
  res.status(err.status || 500).json({
    error: {
      message: err.message || 'Internal Server Error',
    },
  });
});

if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`Job Portal API running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
  });
}

export default app;
