import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, writeBatch, serverTimestamp, updateDoc, getDoc, setDoc } from 'firebase/firestore';

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
  await environment.withSecurityRulesDisabled(async (context) => {
    const trusted = context.firestore();
    await setDoc(doc(trusted, 'jobs', 'owned-job'), { employerUid: 'pending-employer', status: 'active' });
    await setDoc(doc(trusted, 'applications', 'private-application'), {
      employerUid: 'pending-employer', candidateUid: 'candidate-a', jobId: 'owned-job',
      candidateEmail: 'candidate@example.com', candidatePhone: '9876543210', status: 'Applied',
    });
    await setDoc(doc(trusted, 'candidate_public_profiles', 'candidate-a'), { photoUrl: 'https://example.com/photo.jpg' });
  });
  await assertFails(setDoc(doc(pending.database, 'jobs', 'new-job'), { employerUid: 'pending-employer' }));
  await assertFails(getDoc(doc(pending.database, 'applications', 'private-application')));
  await assertFails(getDoc(doc(pending.database, 'candidate_public_profiles', 'candidate-a')));
  await assertFails(setDoc(doc(pending.database, 'employer_entitlements', 'pending-employer'), { profileUnlockLimit: 100 }));
  await assertFails(setDoc(doc(pending.database, 'employer_plans', 'forged'), { pricePaise: 0 }));
  const adminDatabase = environment.authenticatedContext('claimed-admin', {
    email_verified: true, admin: true,
  }).firestore();
  await assertFails(setDoc(doc(adminDatabase, 'users', 'claimed-admin'), {
    uid: 'claimed-admin', email: 'admin@example.com', role: 'candidate',
  }));
  const candidate = environment.authenticatedContext('candidate-a', { email_verified: true }).firestore();
  await assertSucceeds(getDoc(doc(candidate, 'applications', 'private-application')));
  console.log('Firestore rules: client approval, plan/credit/job writes, employer application reads, and admin role mixing denied.');
} finally {
  await environment.cleanup();
}
