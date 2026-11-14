import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, writeBatch, serverTimestamp, updateDoc } from 'firebase/firestore';

const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));
const environment = await initializeTestEnvironment({
  projectId: 'demo-career360',
  firestore: {
    host: '127.0.0.1',
    port: 8080,
    rules: readFileSync(rulesPath, 'utf8'),
  },
});

function registration(uid, extra = {}) {
  const database = environment.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    email_verified: true,
  }).firestore();
  const batch = writeBatch(database);
  batch.set(doc(database, 'users', uid), {
    uid,
    email: `${uid}@example.com`,
    role: 'employer',
    displayName: 'Test Recruiter',
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(database, 'employers', uid), {
    uid,
    email: `${uid}@example.com`,
    contactName: 'Test Recruiter',
    designation: 'Owner',
    companyName: 'Test Company',
    industry: 'Manufacturing',
    companySize: '1-10',
    phone: '9876543210',
    whatsappPhone: '9876543210',
    whatsappSameAsPhone: true,
    website: '',
    address: 'Main Road',
    city: '',
    description: '',
    state: 'Tamil Nadu',
    district: 'Erode',
    postalCode: '638001',
    registrationNumber: '',
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  });
  return { database, commit: batch.commit() };
}

try {
  await environment.clearFirestore();
  const pending = registration('pending-employer');
  await assertSucceeds(pending.commit);
  await assertFails(registration('approved-employer', { status: 'approved' }).commit);
  await assertFails(registration('credited-employer', { postingCredits: 1 }).commit);
  await assertFails(updateDoc(doc(pending.database, 'employers', 'pending-employer'), {
    status: 'approved', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(pending.database, 'employers', 'pending-employer'), {
    postingCredits: 1, updatedAt: serverTimestamp(),
  }));
  console.log('Firestore rules: pending registration allowed; client approval and credits denied.');
} finally {
  await environment.cleanup();
}
