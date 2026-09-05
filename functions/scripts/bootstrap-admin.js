// Assign the first admin role to an existing Auth account; dry run by default.
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const args = process.argv.slice(2);
const option = (name) => args[args.indexOf(name) + 1];
if (!args.includes('--project') || !args.includes('--uid')) throw new Error('Required: --project PROJECT_ID --uid AUTH_UID [--apply]');
initializeApp({ projectId: option('--project') });
(async () => {
  const user = await getAuth().getUser(option('--uid'));
  if (user.disabled || !user.email) throw new Error('Choose an active email/password Auth account.');
  const ref = getFirestore('cbt-db').doc(`users/${user.uid}`);
  const existing = (await ref.get()).data();
  console.log(`Project ${option('--project')}: grant admin role to UID ${user.uid}.`);
  if (!args.includes('--apply')) { console.log('Dry run only. Add --apply after reviewing the target.'); return; }
  if (existing && existing.role !== 'admin') throw new Error('Refusing to convert an existing teacher/student with possible history. Use a dedicated account.');
  await ref.set({ uid: user.uid, email: user.email, name: user.displayName || 'Administrator', role: 'admin', isActive: true,
    createdAt: existing?.createdAt || Timestamp.now() });
  console.log('Admin profile saved.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
