import { randomUUID } from 'node:crypto';
import express from 'express';
import { v2 as cloudinary } from 'cloudinary';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { firebaseApp } from '../config/firebase.js';
import { verifyFirebaseToken } from '../middlewares/authMiddleware.js';

const router = express.Router();
const maxResumeBytes = 10 * 1024 * 1024;
const dailyUploadLimit = 10;

function validPdfName(fileName) {
  return fileName.length > 4 && fileName.length <= 160
    && !Array.from(fileName).some((character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127 || character === '/' || character === '\\')
    && fileName.toLowerCase().endsWith('.pdf');
}

function configured(res) {
  if (!firebaseApp || !process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
    res.status(503).json({ error: { message: 'Resume uploads are not configured.' } });
    return false;
  }
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });
  return true;
}

function verified(req, res) {
  if (req.user.email_verified === true) return true;
  res.status(403).json({ error: { message: 'Verify your email before uploading a resume.' } });
  return false;
}

router.post('/sign-upload', verifyFirebaseToken, async (req, res) => {
  if (!verified(req, res) || !configured(res)) return;
  const fileName = typeof req.body.fileName === 'string' ? req.body.fileName.trim() : '';
  const fileSize = Number(req.body.fileSize);
  if (!validPdfName(fileName) || !Number.isInteger(fileSize) || fileSize < 5 || fileSize > maxResumeBytes) {
    return res.status(400).json({ error: { message: 'Choose a PDF no larger than 10 MB.' } });
  }

  try {
    const quotaRef = getFirestore(firebaseApp).collection('resume_upload_quotas').doc(req.user.uid);
    const day = new Date().toISOString().slice(0, 10);
    const permitted = await getFirestore(firebaseApp).runTransaction(async (transaction) => {
      const snapshot = await transaction.get(quotaRef);
      const count = snapshot.data()?.day === day ? snapshot.data().count ?? 0 : 0;
      if (count >= dailyUploadLimit) return false;
      transaction.set(quotaRef, { day, count: count + 1, updatedAt: FieldValue.serverTimestamp() });
      return true;
    });
    if (!permitted) {
      return res.status(429).json({ error: { message: 'Daily resume upload limit reached. Try again tomorrow.' } });
    }
  } catch (error) {
    console.error('[Resume upload quota]', error);
    return res.status(503).json({ error: { message: 'Could not prepare the resume upload.' } });
  }

  const params = {
    timestamp: Math.floor(Date.now() / 1000),
    public_id: `candidate_resumes/${req.user.uid}/${randomUUID()}.pdf`,
    type: 'authenticated',
    overwrite: 'false',
  };
  const signature = cloudinary.utils.api_sign_request(params, process.env.CLOUDINARY_API_SECRET);
  return res.json({
    uploadUrl: `https://api.cloudinary.com/v1_1/${encodeURIComponent(process.env.CLOUDINARY_CLOUD_NAME)}/raw/upload`,
    apiKey: process.env.CLOUDINARY_API_KEY,
    signature,
    params,
  });
});

router.post('/finalize', verifyFirebaseToken, async (req, res) => {
  if (!verified(req, res) || !configured(res)) return;
  const publicId = typeof req.body.publicId === 'string' ? req.body.publicId : '';
  const fileName = typeof req.body.fileName === 'string' ? req.body.fileName.trim() : '';
  if (!publicId.startsWith(`candidate_resumes/${req.user.uid}/`) || !publicId.endsWith('.pdf') || !validPdfName(fileName)) {
    return res.status(400).json({ error: { message: 'Invalid resume upload.' } });
  }
  try {
    const asset = await cloudinary.api.resource(publicId, { resource_type: 'raw', type: 'authenticated' });
    if (asset.public_id !== publicId || asset.resource_type !== 'raw' || asset.type !== 'authenticated' || asset.bytes < 5 || asset.bytes > maxResumeBytes || (asset.format && asset.format.toLowerCase() !== 'pdf')) {
      await cloudinary.uploader.destroy(publicId, { resource_type: 'raw', type: 'authenticated' });
      return res.status(400).json({ error: { message: 'The uploaded file is not an accepted PDF.' } });
    }

    const candidateRef = getFirestore(firebaseApp).collection('candidates').doc(req.user.uid);
    const previousId = await getFirestore(firebaseApp).runTransaction(async (transaction) => {
      const previous = await transaction.get(candidateRef);
      transaction.set(candidateRef, {
        uid: req.user.uid,
        resumePublicId: publicId,
        resumeFileName: fileName,
        resumeUpdatedAt: FieldValue.serverTimestamp(),
        resumePath: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return previous.data()?.resumePublicId;
    });
    if (previousId && previousId !== publicId) {
      cloudinary.uploader.destroy(previousId, { resource_type: 'raw', type: 'authenticated' }).catch((error) => console.error('[Resume cleanup]', error));
    }
    return res.json({ fileName });
  } catch (error) {
    console.error('[Resume finalize]', error);
    return res.status(502).json({ error: { message: 'Could not confirm the uploaded resume.' } });
  }
});

router.delete('/', verifyFirebaseToken, async (req, res) => {
  if (!verified(req, res) || !configured(res)) return;
  try {
    const candidateRef = getFirestore(firebaseApp).collection('candidates').doc(req.user.uid);
    const snapshot = await candidateRef.get();
    const publicId = snapshot.data()?.resumePublicId;
    if (publicId) {
      await cloudinary.uploader.destroy(publicId, { resource_type: 'raw', type: 'authenticated' });
    }
    await candidateRef.set({
      uid: req.user.uid,
      resumePublicId: FieldValue.delete(),
      resumeFileName: FieldValue.delete(),
      resumeUpdatedAt: FieldValue.delete(),
      resumePath: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return res.status(204).end();
  } catch (error) {
    console.error('[Resume delete]', error);
    return res.status(502).json({ error: { message: 'Could not remove the resume.' } });
  }
});

export default router;
