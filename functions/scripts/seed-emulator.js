// Local-only accounts for integration tests and manual development.
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Seed is allowed only with local Firestore and Auth emulators.');
}
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
initializeApp({ projectId: 'demo-cbt' });
(async () => {
  const auth = getAuth();
  const db = getFirestore('cbt-db');
  for (const role of ['admin', 'guru', 'siswa']) {
    const uid = `local_${role}_12345678901234567890`;
    const data = { email: `${role}@cbt.test`, password: 'LocalCbt123!', displayName: `Demo ${role}`, disabled: false };
    try { await auth.createUser({ uid, ...data }); }
    catch (e) { if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e; await auth.updateUser(uid, data); }
    await db.doc(`users/${uid}`).set({ uid, name: data.displayName, email: data.email, role, isActive: true, createdAt: Timestamp.now() });
  }
  console.log('Local demo accounts ready: admin/guru/siswa@cbt.test (password: LocalCbt123!)');
})().catch((error) => { console.error(error); process.exitCode = 1; });
