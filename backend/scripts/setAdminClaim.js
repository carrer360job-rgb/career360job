import 'dotenv/config';
import { auth, firebaseApp } from '../src/config/firebase.js';
import { getFirestore } from 'firebase-admin/firestore';

const email = process.argv[2]?.trim().toLowerCase();
if (!auth || !email || process.argv[3] !== '--confirm') {
  console.error('Usage: node scripts/setAdminClaim.js admin@example.com --confirm');
  process.exit(1);
}

let user = await auth.getUserByEmail(email);
if (!user.emailVerified) {
  user = await auth.updateUser(user.uid, { emailVerified: true });
  console.log(`Marked ${email} as verified.`);
}

const database = getFirestore(firebaseApp);
const accountDocuments = await database.getAll(
  database.collection('users').doc(user.uid),
  database.collection('candidates').doc(user.uid),
  database.collection('employers').doc(user.uid),
);
if (accountDocuments.some((document) => document.exists)) {
  console.error('Use a separate Firebase account that is not a candidate or employer.');
  process.exit(1);
}

await auth.setCustomUserClaims(user.uid, { ...user.customClaims, admin: true });
console.log(`Admin claim granted to verified Firebase user ${user.uid}. Sign in again to refresh the ID token.`);
