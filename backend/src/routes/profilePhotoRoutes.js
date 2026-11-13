import { randomUUID } from 'node:crypto';
import express from 'express';
import { v2 as cloudinary } from 'cloudinary';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { firebaseApp } from '../config/firebase.js';
import { verifyFirebaseToken } from '../middlewares/authMiddleware.js';

const router = express.Router();
const maxPhotoBytes = 3 * 1024 * 1024;
const allowedFormats = new Set(['jpg', 'jpeg', 'png', 'webp']);

function configure(res) {
  if (!firebaseApp || !process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
    res.status(503).json({ error: { message: 'Profile photo uploads are not configured.' } });
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
  res.status(403).json({ error: { message: 'Verify your email before uploading a photo.' } });
  return false;
}

function validFileName(fileName) {
  if (!fileName || fileName.length > 160 ||
      Array.from(fileName).some((character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127 || character === '/' || character === '\\')) return false;
  return allowedFormats.has(fileName.split('.').pop().toLowerCase());
}

router.post('/sign-upload', verifyFirebaseToken, async (req, res) => {
  if (!verified(req, res) || !configure(res)) return;
  const fileName = typeof req.body.fileName === 'string' ? req.body.fileName.trim() : '';
  const fileSize = Number(req.body.fileSize);
  if (!validFileName(fileName) || !Number.isInteger(fileSize) || fileSize < 16 || fileSize > maxPhotoBytes) {
    return res.status(400).json({ error: { message: 'Choose a JPG, PNG, or WebP photo under 3 MB.' } });
  }

  try {
    const quotaRef = getFirestore(firebaseApp).collection('profile_photo_upload_quotas').doc(req.user.uid);
    const day = new Date().toISOString().slice(0, 10);
    const permitted = await getFirestore(firebaseApp).runTransaction(async (transaction) => {
      const snapshot = await transaction.get(quotaRef);
      const count = snapshot.data()?.day === day ? snapshot.data().count ?? 0 : 0;
      if (count >= 10) return false;
      transaction.set(quotaRef, { day, count: count + 1, updatedAt: FieldValue.serverTimestamp() });
      return true;
    });
    if (!permitted) return res.status(429).json({ error: { message: 'Daily photo upload limit reached. Try again tomorrow.' } });
  } catch (error) {
    console.error('[Profile photo quota]', error);
    return res.status(503).json({ error: { message: 'Could not prepare the photo upload.' } });
  }

  const params = {
    timestamp: Math.floor(Date.now() / 1000),
    public_id: `candidate_photos/${req.user.uid}/${randomUUID()}`,
    type: 'upload',
    overwrite: 'false',
    allowed_formats: 'jpg,jpeg,png,webp',
  };
  return res.json({
    uploadUrl: `https://api.cloudinary.com/v1_1/${encodeURIComponent(process.env.CLOUDINARY_CLOUD_NAME)}/image/upload`,
    apiKey: process.env.CLOUDINARY_API_KEY,
    signature: cloudinary.utils.api_sign_request(params, process.env.CLOUDINARY_API_SECRET),
    params,
  });
});

router.post('/finalize', verifyFirebaseToken, async (req, res) => {
  if (!verified(req, res) || !configure(res)) return;
  const publicId = typeof req.body.publicId === 'string' ? req.body.publicId : '';
  const prefix = `candidate_photos/${req.user.uid}/`;
  if (!publicId.startsWith(prefix) || !/^[0-9a-f-]{36}$/.test(publicId.slice(prefix.length))) {
    return res.status(400).json({ error: { message: 'Invalid profile photo upload.' } });
  }

  try {
    const asset = await cloudinary.api.resource(publicId, { resource_type: 'image', type: 'upload' });
    if (asset.public_id !== publicId || asset.resource_type !== 'image' || asset.type !== 'upload' ||
        !allowedFormats.has(String(asset.format).toLowerCase()) || asset.bytes < 16 || asset.bytes > maxPhotoBytes ||
        !Number.isInteger(asset.width) || !Number.isInteger(asset.height)) {
      await cloudinary.uploader.destroy(publicId, { resource_type: 'image', type: 'upload' });
      return res.status(400).json({ error: { message: 'The uploaded file is not an accepted photo.' } });
    }

    const photoUrl = cloudinary.url(publicId, {
      secure: true,
      resource_type: 'image',
      type: 'upload',
      version: asset.version,
      transformation: [{ width: 320, height: 320, crop: 'fill', gravity: 'auto' }, { fetch_format: 'auto', quality: 'auto' }],
    });
    const candidateRef = getFirestore(firebaseApp).collection('candidates').doc(req.user.uid);
    const publicProfileRef = getFirestore(firebaseApp).collection('candidate_public_profiles').doc(req.user.uid);
    const previousId = await getFirestore(firebaseApp).runTransaction(async (transaction) => {
      const previous = await transaction.get(candidateRef);
      transaction.set(candidateRef, {
        uid: req.user.uid,
        profilePhotoPublicId: publicId,
        profilePhotoUrl: photoUrl,
        profilePhotoUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(publicProfileRef, {
        uid: req.user.uid,
        photoUrl,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return previous.data()?.profilePhotoPublicId;
    });
    if (previousId && previousId !== publicId) {
      try {
        await cloudinary.uploader.destroy(previousId, { resource_type: 'image', type: 'upload', invalidate: true });
      } catch (error) {
        console.error('[Previous profile photo cleanup]', error);
      }
    }
    return res.json({ photoUrl });
  } catch (error) {
    console.error('[Profile photo finalize]', error);
    return res.status(502).json({ error: { message: 'Could not confirm the uploaded profile photo.' } });
  }
});

router.delete('/', verifyFirebaseToken, async (req, res) => {
  if (!verified(req, res) || !configure(res)) return;
  try {
    const candidateRef = getFirestore(firebaseApp).collection('candidates').doc(req.user.uid);
    const publicProfileRef = getFirestore(firebaseApp).collection('candidate_public_profiles').doc(req.user.uid);
    const snapshot = await candidateRef.get();
    const publicId = snapshot.data()?.profilePhotoPublicId;
    if (publicId) {
      await cloudinary.uploader.destroy(publicId, { resource_type: 'image', type: 'upload', invalidate: true });
    }
    const batch = getFirestore(firebaseApp).batch();
    batch.set(candidateRef, {
      profilePhotoPublicId: FieldValue.delete(),
      profilePhotoUrl: FieldValue.delete(),
      profilePhotoUpdatedAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.delete(publicProfileRef);
    await batch.commit();
    return res.status(204).end();
  } catch (error) {
    console.error('[Profile photo delete]', error);
    return res.status(502).json({ error: { message: 'Could not remove the profile photo.' } });
  }
});

export default router;
