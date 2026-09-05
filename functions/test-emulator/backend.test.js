const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Tests require local Firestore AND Auth emulators. Production access is forbidden.');
}
process.env.CBT_DATABASE_ID = '(default)';
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const app = initializeApp({ projectId: 'demo-cbt' });
const db = getFirestore();
const backend = require('../backend');
const guru = 'guru_12345678901234567890123';
const other = 'other_1234567890123456789012';
const siswa = 'siswa_1234567890123456789012';
const admin = 'admin_1234567890123456789012';
let env;
let exam;
let bundle;

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-cbt', firestore: {
    rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
  } });
  await env.clearFirestore();
  for (const [uid, role] of [[guru, 'guru'], [other, 'guru'], [siswa, 'siswa'], [admin, 'admin']]) {
    await db.doc(`users/${uid}`).set({ uid, role, isActive: true, name: role, email: `${role}@example.com`, createdAt: Timestamp.now() });
  }
});
after(async () => { await env?.cleanup(); await deleteApp(app); });

test('complete CBT workflow and authorization against real emulator transactions', async (t) => {
  await t.test('only teachers create validated exams; new exams start as drafts', async () => {
    const data = { title: 'Ujian', description: '', duration: 30,
      startDate: new Date(Date.now() - 60000).toISOString(), endDate: new Date(Date.now() + 3600000).toISOString(),
      shuffleQuestions: true, shuffleOptions: true };
    await assert.rejects(backend.createExam(siswa, data), { code: 'permission-denied' });
    await assert.rejects(backend.createExam(guru, { ...data, duration: 0 }), { code: 'invalid-argument' });
    await assert.rejects(backend.createExam(guru, { ...data, startDate: '2026-09-05T12:00:00' }), { code: 'invalid-argument' });
    exam = await backend.createExam(guru, data);
    assert.equal(exam.isActive, false);
    await assertFails(env.authenticatedContext(guru).firestore().doc(`exams/${exam.id}`).update({ isActive: true }));
  });
  await t.test('question import is atomic and synchronizes the count', async () => {
    await backend.editQuestions(guru, { examId: exam.id, action: 'add', questions: [
      { id: 'pg', type: 'pg', text: '2 + 2?', options: ['3', '4'], correctAnswer: 1, points: 3, maxScore: 3 },
      { id: 'essay', type: 'essay', text: 'Jelaskan', essayGuideline: 'PRIVATE', points: 7, maxScore: 7 },
    ] });
    assert.equal((await db.doc(`exams/${exam.id}`).get()).data().totalQuestions, 2);
    await assertSucceeds(env.authenticatedContext(guru).firestore().doc(`exams/${exam.id}`).update({ isActive: true }));
    await assert.rejects(backend.editQuestions(other, { examId: exam.id, action: 'delete', questionId: 'pg' }), { code: 'permission-denied' });
  });
  await t.test('concurrent starts return one stable shuffled session without answer keys', async () => {
    const sessions = await Promise.all([backend.startExam(siswa, { code: exam.code }), backend.startExam(siswa, { code: exam.code })]);
    bundle = sessions[0];
    assert.equal(bundle.session.id, sessions[1].session.id);
    assert.deepEqual(bundle.session.optionOrders, sessions[1].session.optionOrders);
    assert.equal((await db.collection('exam_sessions').get()).size, 1);
    assert.equal(JSON.stringify(bundle).includes('correctAnswer'), false);
    assert.equal(JSON.stringify(bundle).includes('PRIVATE'), false);
  });
  await t.test('retrying the same app-switch event does not inflate the count', async () => {
    const event = { sessionId: bundle.session.id, eventId: 'event_1', duration: 3 };
    await backend.logAppSwitch(siswa, event);
    await backend.logAppSwitch(siswa, event);
    assert.equal((await db.doc(`exam_sessions/${bundle.session.id}`).get()).data().appSwitchCount, 1);
  });
  await t.test('rules hide keys, other students and deny forged scores or session changes', async () => {
    const client = env.authenticatedContext(siswa).firestore();
    await assertFails(client.doc(`exams/${exam.id}/questions/pg`).get());
    await assertFails(client.doc(`session_content/${bundle.session.id}`).get());
    await assertFails(client.doc(`exam_sessions/${bundle.session.id}`).update({ startedAt: new Date(), answers: { pg: 0 } }));
    await assertFails(client.doc(`exam_results/${bundle.session.id}`).set({ userId: siswa, totalScore: 100 }));
    await assertFails(client.doc(`users/${siswa}`).update({ role: 'admin' }));
    await assertSucceeds(client.doc(`exam_sessions/${bundle.session.id}`).get());
    await assertFails(env.unauthenticatedContext().firestore().doc(`exams/${exam.id}`).get());
  });
  await t.test('question bank validates option types, sizes and score limits', async () => {
    const bank = env.authenticatedContext(guru).firestore().doc('question_bank/safe');
    const valid = { id: 'safe', type: 'pg', text: 'Aman?', options: ['Ya', 'Tidak'], correctAnswer: 0,
      maxScore: 1, points: 1, order: 0, createdBy: guru };
    await assertSucceeds(bank.set(valid));
    await assertFails(bank.set({ ...valid, options: ['Ya', 2] }));
    await assertFails(bank.set({ ...valid, points: 10001 }));
    await assertFails(bank.set({ ...valid, options: ['A'.repeat(2001), 'B'] }));
  });
  await t.test('used exams cannot lose questions, schedule or history', async () => {
    await assert.rejects(backend.deleteExam(guru, { examId: exam.id }), { code: 'failed-precondition' });
    await assert.rejects(backend.editQuestions(guru, { examId: exam.id, action: 'delete', questionId: 'pg' }), { code: 'failed-precondition' });
    await assertFails(env.authenticatedContext(guru).firestore().doc(`exams/${exam.id}`).update({ duration: 100 }));
    await assertSucceeds(env.authenticatedContext(guru).firestore().doc(`exams/${exam.id}`).update({ isActive: false }));
    await assertSucceeds(env.authenticatedContext(siswa).firestore().doc(`exams/${exam.id}`).get());
  });
  await t.test('submit includes last typed essay and computes score on server exactly once', async () => {
    const answer = bundle.session.optionOrders.pg.indexOf(1);
    const result = await backend.submitExam(siswa, { sessionId: bundle.session.id, answers: { pg: answer, essay: 'Final keystroke' }, pgScore: 999 });
    assert.equal(result.pgScore, 3);
    assert.equal(result.gradingStatus, 'pending_essay');
    assert.equal((await db.doc(`exam_sessions/${bundle.session.id}`).get()).data().answers.essay, 'Final keystroke');
    const duplicate = await backend.submitExam(siswa, { sessionId: bundle.session.id, answers: { pg: 100 } });
    assert.deepEqual(duplicate, result);
  });
  await t.test('essay grading rejects wrong teacher and excessive scores; uses server time', async () => {
    await assert.rejects(backend.submitGrades(other, { resultId: bundle.session.id, grades: {} }), { code: 'permission-denied' });
    await assert.rejects(backend.submitGrades(guru, { resultId: bundle.session.id, grades: { essay: { score: 8, feedback: '' } } }), { code: 'invalid-argument' });
    await backend.submitGrades(guru, { resultId: bundle.session.id, grades: { essay: { score: 6, feedback: 'Baik' } } });
    const result = (await db.doc(`exam_results/${bundle.session.id}`).get()).data();
    assert.equal(result.totalScore, 9);
    assert.equal(result.gradingStatus, 'graded');
    assert.ok(result.gradedAt instanceof Timestamp);
  });
  await t.test('expired sessions reject late answers and finish from accepted answers', async () => {
    const second = 'second_123456789012345678901';
    await db.doc(`users/${second}`).set({ role: 'siswa', isActive: true });
    await db.doc(`exams/${exam.id}`).update({ isActive: true });
    const session = (await backend.startExam(second, { code: exam.code })).session;
    await backend.saveAnswers(second, { sessionId: session.id, answers: { pg: session.optionOrders.pg.indexOf(1) } });
    await db.doc(`exam_sessions/${session.id}`).update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    await assert.rejects(backend.saveAnswers(second, { sessionId: session.id, answers: { essay: 'late' } }), { code: 'failed-precondition' });
    await backend.expireSessions();
    const result = await backend.submitExam(second, { sessionId: session.id, answers: { essay: 'late' } });
    assert.equal(result.pgScore, 3);
    const stored = (await db.doc(`exam_sessions/${session.id}`).get()).data();
    assert.equal(stored.status, 'auto_submitted');
    assert.equal(stored.answers.essay, undefined);
  });
  await t.test('force submission creates a result and denies a different teacher', async () => {
    const third = 'third_1234567890123456789012';
    await db.doc(`users/${third}`).set({ role: 'siswa', isActive: true });
    const session = (await backend.startExam(third, { code: exam.code })).session;
    await assert.rejects(backend.forceSubmit(other, { sessionId: session.id }), { code: 'permission-denied' });
    const result = await backend.forceSubmit(guru, { sessionId: session.id });
    assert.equal(result.pgScore, 0);
    assert.equal((await db.doc(`exam_sessions/${session.id}`).get()).data().status, 'auto_submitted');
  });
  await t.test('admin account lifecycle changes Auth and retains historical profile', async () => {
    await assert.rejects(backend.manageUser(siswa, { action: 'create' }), { code: 'permission-denied' });
    const created = await backend.manageUser(admin, { action: 'create', name: 'Student', role: 'siswa', email: `student-${Date.now()}@example.com`, password: 'local-test-123' });
    await backend.manageUser(admin, { action: 'update', uid: created.uid, isActive: false });
    assert.equal((await getAuth().getUser(created.uid)).disabled, true);
    await assert.rejects(backend.previewExam(created.uid, { code: exam.code }), { code: 'permission-denied' });
    await assertFails(env.authenticatedContext(created.uid).firestore().doc(`exams/${exam.id}`).get());
    await backend.manageUser(admin, { action: 'delete', uid: created.uid });
    await assert.rejects(getAuth().getUser(created.uid), { code: 'auth/user-not-found' });
    assert.equal((await db.doc(`users/${created.uid}`).get()).data().deleted, true);
    await assert.rejects(backend.manageUser(admin, { action: 'delete', uid: admin }), { code: 'failed-precondition' });
  });
  await t.test('50 students can save and submit concurrently without duplicate sessions or results', async () => {
    await db.doc(`exams/${exam.id}`).update({ isActive: true });
    const students = Array.from({ length: 50 }, (_, index) => `load_${String(index).padStart(2, '0')}_12345678901234567890`);
    await Promise.all(students.map((uid) => db.doc(`users/${uid}`).set({ uid, role: 'siswa', isActive: true })));
    const bundles = await Promise.all(students.map((uid) => backend.startExam(uid, { code: exam.code })));
    const retries = await Promise.all(students.map((uid) => backend.startExam(uid, { code: exam.code })));
    retries.forEach((retry, index) => assert.equal(retry.session.id, bundles[index].session.id));
    await Promise.all(bundles.map((item, index) => backend.saveAnswers(students[index], {
      sessionId: item.session.id,
      answers: { pg: item.session.optionOrders.pg.indexOf(1), essay: `Jawaban ${index}` },
    })));
    await Promise.all(bundles.map((item, index) => Promise.all([
      backend.submitExam(students[index], { sessionId: item.session.id, answers: {} }),
      backend.submitExam(students[index], { sessionId: item.session.id, answers: {} }),
    ])));
    const [sessions, results] = await Promise.all([
      db.collection('exam_sessions').where('examId', '==', exam.id).get(),
      db.collection('exam_results').where('examId', '==', exam.id).get(),
    ]);
    for (const [index, item] of bundles.entries()) {
      const stored = (await db.doc(`exam_sessions/${item.session.id}`).get()).data();
      assert.equal(stored.answers.essay, `Jawaban ${index}`);
      assert.equal((await db.doc(`exam_results/${item.session.id}`).get()).exists, true);
    }
    assert.equal(new Set(sessions.docs.map((doc) => doc.id)).size, sessions.size);
    assert.equal(new Set(results.docs.map((doc) => doc.id)).size, results.size);
  });
  await t.test('legacy migration previews without writes, backs up and restores missing results', async () => {
    const legacyExam = 'legacy_exam';
    const legacySession = `${siswa}_${legacyExam}_123`;
    const canonical = `${siswa}_${legacyExam}`;
    const question = { id: 'q', type: 'pg', text: 'Legacy', options: ['A', 'B'], correctAnswer: 0, points: 5, maxScore: 5, order: 0 };
    await db.doc(`exams/${legacyExam}`).set({ ...exam, id: legacyExam, code: 'OLD123', isActive: false, totalQuestions: 1,
      startDate: Timestamp.fromMillis(Date.now() - 7200000), endDate: Timestamp.fromMillis(Date.now() - 3600000) });
    await db.doc(`exams/${legacyExam}/questions/q`).set(question);
    await db.doc(`exam_sessions/${legacySession}`).set({ id: legacySession, userId: siswa, examId: legacyExam,
      startedAt: Timestamp.fromMillis(Date.now() - 5400000), status: 'completed', questionOrder: ['q'], optionOrders: { q: [0, 1] },
      answers: { q: 0 }, appSwitchCount: 0, appSwitchLogs: [] });
    const emptyDuplicate = `${siswa}_${legacyExam}_empty`;
    await db.doc(`exam_sessions/${emptyDuplicate}`).set({ id: emptyDuplicate, userId: siswa, examId: legacyExam,
      startedAt: Timestamp.fromMillis(Date.now() - 5300000), status: 'completed', questionOrder: ['q'], optionOrders: { q: [0, 1] },
      answers: {}, appSwitchCount: 0, appSwitchLogs: [] });
    const script = path.join(__dirname, '../scripts/migrate-legacy.js');
    await promisify(execFile)(process.execPath, [script, '--project', 'demo-cbt']);
    assert.equal((await db.doc(`exam_sessions/${legacySession}`).get()).exists, true);
    assert.equal((await db.doc(`exam_sessions/${emptyDuplicate}`).get()).exists, true);
    assert.equal((await db.doc(`exam_sessions/${canonical}`).get()).exists, false);
    await promisify(execFile)(process.execPath, [script, '--project', 'demo-cbt', '--apply']);
    assert.equal((await db.doc(`exam_sessions/${legacySession}`).get()).exists, false);
    assert.equal((await db.doc(`exam_sessions/${emptyDuplicate}`).get()).exists, false);
    assert.equal((await db.doc(`exam_results/${canonical}`).get()).data().pgScore, 5);
    assert.equal((await db.doc(`session_content/${canonical}`).get()).data().questions[0].correctAnswer, 0);
    // Recover a prior run interrupted between session migration and result creation.
    await db.doc(`exam_results/${canonical}`).delete();
    await promisify(execFile)(process.execPath, [script, '--project', 'demo-cbt', '--apply']);
    assert.equal((await db.doc(`exam_results/${canonical}`).get()).data().pgScore, 5);
  });
});
