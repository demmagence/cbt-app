const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { randomInt, randomUUID } = require('node:crypto');
const { HttpsError } = require('firebase-functions/v2/https');
const { shuffle, publicQuestion, validateAnswers, scorePg, gradeEssays } = require('./domain');

const db = () => getFirestore(process.env.CBT_DATABASE_ID || 'cbt-db');
const fail = (code, message) => { throw new HttpsError(code, message); };
const id = (value) => {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(value)) fail('invalid-argument', 'ID tidak valid.');
  return value;
};
const wire = (value) => {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(wire);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, wire(v)]));
  return value;
};
async function actor(uid, roles) {
  if (!uid) fail('unauthenticated', 'Silakan masuk kembali.');
  const user = (await db().doc(`users/${id(uid)}`).get()).data();
  if (!user?.isActive || !roles.includes(user.role)) fail('permission-denied', 'Akun tidak aktif atau tidak memiliki akses.');
  return user;
}
async function examByCode(code) {
  if (typeof code !== 'string' || !/^[A-Z0-9]{6}$/.test(code.trim().toUpperCase())) fail('invalid-argument', 'Kode harus enam karakter.');
  const found = await db().collection('exams').where('code', '==', code.trim().toUpperCase()).limit(2).get();
  if (found.size !== 1) fail('not-found', 'Kode ujian tidak ditemukan atau tidak unik.');
  return found.docs[0];
}
function checkWindow(exam, now) {
  if (!exam.isActive || now < exam.startDate.toMillis() || now >= exam.endDate.toMillis()) {
    fail('failed-precondition', 'Ujian belum dimulai, sudah berakhir, atau dinonaktifkan.');
  }
}

async function previewExam(uid, data) {
  await actor(uid, ['siswa']);
  const doc = await examByCode(data.code);
  checkWindow(doc.data(), Date.now());
  return wire({ ...doc.data(), id: doc.id });
}

async function createExam(uid, data) {
  await actor(uid, ['guru']);
  if (typeof data.startDate !== 'string' || typeof data.endDate !== 'string' ||
      !/(Z|[+-]\d{2}:\d{2})$/.test(data.startDate) || !/(Z|[+-]\d{2}:\d{2})$/.test(data.endDate)) {
    fail('invalid-argument', 'Jadwal harus menyertakan zona waktu.');
  }
  const start = Date.parse(data.startDate);
  const end = Date.parse(data.endDate);
  if (typeof data.title !== 'string' || !data.title.trim() || data.title.length > 200 ||
      typeof data.description !== 'string' || data.description.length > 1000 ||
      !Number.isInteger(data.duration) || data.duration <= 0 || data.duration > 1440 ||
      !Number.isFinite(start) || !Number.isFinite(end) || end <= start || end <= Date.now() ||
      typeof data.shuffleQuestions !== 'boolean' || typeof data.shuffleOptions !== 'boolean') {
    fail('invalid-argument', 'Judul, jadwal, atau durasi ujian tidak valid.');
  }
  const examId = randomUUID();
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = Array.from({ length: 6 }, () => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[randomInt(36)]).join('');
    const created = await db().runTransaction(async (tx) => {
      const codeRef = db().doc(`exam_codes/${code}`);
      const [reservation, legacy] = await Promise.all([tx.get(codeRef), tx.get(db().collection('exams').where('code', '==', code))]);
      if (reservation.exists || !legacy.empty) return null;
      const exam = { id: examId, title: data.title.trim(), description: data.description.trim(), code, createdBy: uid,
        duration: data.duration, startDate: Timestamp.fromMillis(start), endDate: Timestamp.fromMillis(end),
        isActive: false, shuffleQuestions: data.shuffleQuestions, shuffleOptions: data.shuffleOptions, totalQuestions: 0, locked: false };
      tx.set(codeRef, { examId });
      tx.set(db().doc(`exams/${examId}`), exam);
      return exam;
    });
    if (created) return wire(created);
  }
  fail('aborted', 'Gagal membuat kode unik. Coba kembali.');
}

function validQuestion(q) {
  id(q.id);
  if (!['pg', 'essay'].includes(q.type) || typeof q.text !== 'string' || !q.text.trim() || q.text.length > 2000 ||
      !Number.isFinite(q.points) || q.points <= 0 || q.points > 10000 ||
      !Number.isFinite(q.maxScore) || q.maxScore <= 0 || q.maxScore > 10000 ||
      (q.type === 'pg' && (!Array.isArray(q.options) || q.options.length < 2 || q.options.length > 10 ||
        q.options.some((v) => typeof v !== 'string' || !v.trim() || v.length > 2000) ||
        !Number.isInteger(q.correctAnswer) || q.correctAnswer < 0 || q.correctAnswer >= q.options.length)) ||
      (q.essayGuideline != null && (typeof q.essayGuideline !== 'string' || q.essayGuideline.length > 2000))) {
    fail('invalid-argument', 'Soal, opsi, atau bobot tidak valid.');
  }
  return { id: q.id, type: q.type, text: q.text.trim(), points: q.points, maxScore: q.maxScore, order: 0,
    ...(q.type === 'pg' ? { options: q.options, correctAnswer: q.correctAnswer } : { essayGuideline: q.essayGuideline || '' }) };
}

async function editQuestions(uid, data) {
  await actor(uid, ['guru']);
  const ref = db().doc(`exams/${id(data.examId)}`);
  await db().runTransaction(async (tx) => {
    const [exam, snapshot, sessions] = await Promise.all([tx.get(ref), tx.get(ref.collection('questions')),
      tx.get(db().collection('exam_sessions').where('examId', '==', data.examId).limit(1))]);
    if (exam.data()?.createdBy !== uid) fail('permission-denied', 'Ujian bukan milik Anda.');
    if (exam.data().locked || !sessions.empty) fail('failed-precondition', 'Soal dikunci karena ujian sudah pernah dikerjakan. Buat ujian baru untuk mengubah soal.');
    let questions = snapshot.docs.map((doc) => ({ ...doc.data(), id: doc.id })).sort((a, b) => a.order - b.order);
    if (data.action === 'add') {
      if (!Array.isArray(data.questions)) fail('invalid-argument', 'Daftar soal tidak valid.');
      for (const value of data.questions) {
        const q = validQuestion(value);
        if (questions.some((item) => item.id === q.id)) fail('already-exists', 'Soal sudah ada.');
        questions.push(q);
      }
    } else if (data.action === 'update') {
      const q = validQuestion(data.question);
      if (!questions.some((item) => item.id === q.id)) fail('not-found', 'Soal tidak ditemukan.');
      questions = questions.map((item) => item.id === q.id ? q : item);
    } else if (data.action === 'delete') {
      questions = questions.filter((q) => q.id !== id(data.questionId));
    } else if (data.action === 'reorder') {
      if (!Array.isArray(data.ids) || new Set(data.ids).size !== questions.length || data.ids.length !== questions.length ||
          data.ids.some((key) => !questions.some((q) => q.id === key))) fail('failed-precondition', 'Daftar soal berubah. Muat ulang halaman.');
      questions = data.ids.map((key) => questions.find((q) => q.id === key));
    } else fail('invalid-argument', 'Aksi tidak valid.');
    if (questions.length > 100) fail('invalid-argument', 'Maksimal 100 soal per ujian.');
    for (const doc of snapshot.docs) if (!questions.some((q) => q.id === doc.id)) tx.delete(doc.ref);
    questions.forEach((q, order) => tx.set(ref.collection('questions').doc(q.id), { ...q, order }));
    tx.update(ref, { totalQuestions: questions.length, ...(questions.length ? {} : { isActive: false }) });
  });
  return { saved: true };
}

async function deleteExam(uid, data) {
  await actor(uid, ['guru']);
  const ref = db().doc(`exams/${id(data.examId)}`);
  await db().runTransaction(async (tx) => {
    const [exam, questions, sessions] = await Promise.all([tx.get(ref), tx.get(ref.collection('questions')),
      tx.get(db().collection('exam_sessions').where('examId', '==', data.examId).limit(1))]);
    if (exam.data()?.createdBy !== uid) fail('permission-denied', 'Ujian bukan milik Anda.');
    if (exam.data().locked || !sessions.empty) fail('failed-precondition', 'Ujian memiliki riwayat. Nonaktifkan ujian untuk menutup akses.');
    questions.docs.forEach((q) => tx.delete(q.ref));
    tx.delete(ref);
    tx.delete(db().doc(`exam_codes/${exam.data().code}`));
  });
  return { saved: true };
}

async function startExam(uid, data) {
  await actor(uid, ['siswa']);
  const examDoc = await examByCode(data.code);
  const examId = examDoc.id;
  const sessionId = `${uid}_${examId}`;
  const ref = db().doc(`exam_sessions/${sessionId}`);
  // Legacy documents cannot be created by clients. Keep this range query out of
  // the transaction so simultaneous students do not contend on the collection.
  const oldSessions = await db().collection('exam_sessions')
    .where('userId', '==', uid).where('examId', '==', examId).get();
  await db().runTransaction(async (tx) => {
    const [examSnap, sessionSnap, questionSnap] = await Promise.all([
      tx.get(examDoc.ref), tx.get(ref),
      tx.get(examDoc.ref.collection('questions')),
    ]);
    if (sessionSnap.exists) return; // Idempotent across retries and two devices.
    if (!oldSessions.empty) fail('failed-precondition', 'Sesi versi lama ditemukan. Selesaikan migrasi sebelum melanjutkan ujian ini.');
    const exam = examSnap.data();
    const now = Date.now();
    checkWindow(exam, now);
    let questions = questionSnap.docs.map((doc) => ({ ...doc.data(), id: doc.id })).sort((a, b) => a.order - b.order);
    if (!questions.length || questions.length > 100) fail('failed-precondition', 'Ujian harus memiliki 1–100 soal.');
    if (exam.shuffleQuestions) questions = shuffle(questions);
    const optionOrders = Object.fromEntries(questions.map((q) => {
      const options = q.type === 'pg' ? q.options.map((_, i) => i) : [];
      return [q.id, exam.shuffleOptions ? shuffle(options) : options];
    }));
    tx.set(ref, {
      id: sessionId, userId: uid, examId, startedAt: Timestamp.fromMillis(now),
      expiresAt: Timestamp.fromMillis(Math.min(now + exam.duration * 60000, exam.endDate.toMillis())),
      status: 'in_progress', questionOrder: questions.map((q) => q.id), optionOrders,
      answers: {}, appSwitchCount: 0, appSwitchLogs: [],
      questions: questions.map(publicQuestion),
    });
    tx.set(db().doc(`session_content/${sessionId}`), { examId, questions, exam });
    // Only the first participant writes the shared exam document. Rewriting it
    // for every concurrent start creates a transaction hotspot.
    if (!exam.locked) tx.update(examDoc.ref, { locked: true });
  });
  return loadExam(uid, { examId });
}

async function loadExam(uid, data) {
  await actor(uid, ['siswa']);
  const sessionId = `${uid}_${id(data.examId)}`;
  let snap = await db().doc(`exam_sessions/${sessionId}`).get();
  if (!snap.exists) fail('not-found', 'Sesi belum dimulai. Masukkan kode ujian terlebih dahulu.');
  if (snap.data().status === 'in_progress' && snap.data().expiresAt.toMillis() <= Date.now()) {
    await finish(sessionId, null, true);
    snap = await snap.ref.get();
  }
  const [content, result] = await Promise.all([
    db().doc(`session_content/${sessionId}`).get(), db().doc(`exam_results/${sessionId}`).get(),
  ]);
  if (!content.exists) fail('failed-precondition', 'Snapshot sesi tidak tersedia.');
  return wire({ session: snap.data(), questions: snap.data().questions,
    exam: content.data().exam, result: result.data() || null, serverNow: Timestamp.now() });
}

async function saveAnswers(uid, data) {
  await actor(uid, ['siswa']);
  const ref = db().doc(`exam_sessions/${id(data.sessionId)}`);
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const session = snap.data();
    if (!session || session.userId !== uid) fail('permission-denied', 'Sesi tidak dapat diakses.');
    if (session.status !== 'in_progress' || Date.now() >= session.expiresAt.toMillis()) {
      fail('failed-precondition', 'Waktu ujian berakhir atau jawaban sudah dikumpulkan.');
    }
    let answers;
    try { answers = validateAnswers(data.answers, session.questions); }
    catch (e) { fail('invalid-argument', e.message); }
    tx.update(ref, { answers: { ...session.answers, ...answers } });
    return { saved: true };
  });
}

async function logAppSwitch(uid, data) {
  await actor(uid, ['siswa']);
  const ref = db().doc(`exam_sessions/${id(data.sessionId)}`);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const session = snap.data();
    if (!session || session.userId !== uid) fail('permission-denied', 'Sesi tidak dapat diakses.');
    if (session.status !== 'in_progress') return;
    id(data.eventId);
    if (session.appSwitchLogs.some((log) => log.eventId === data.eventId)) return;
    if (!Number.isInteger(data.duration) || data.duration < 0 || data.duration > 86400) fail('invalid-argument', 'Durasi tidak valid.');
    const logs = [...session.appSwitchLogs, { eventId: data.eventId, timestamp: Timestamp.now(), duration: data.duration, type: 'app_switch' }].slice(-1000);
    tx.update(ref, { appSwitchCount: session.appSwitchCount + 1, appSwitchLogs: logs });
  });
  return { saved: true };
}

async function finish(sessionId, submittedAnswers, forced, expectedUid) {
  const ref = db().doc(`exam_sessions/${id(sessionId)}`);
  const resultRef = db().doc(`exam_results/${sessionId}`);
  return db().runTransaction(async (tx) => {
    const [snap, contentSnap, resultSnap] = await Promise.all([
      tx.get(ref), tx.get(db().doc(`session_content/${sessionId}`)), tx.get(resultRef),
    ]);
    const session = snap.data();
    if (!session || (expectedUid && session.userId !== expectedUid)) fail('permission-denied', 'Sesi tidak dapat diakses.');
    if (resultSnap.exists) return wire(resultSnap.data());
    if (!contentSnap.exists) fail('failed-precondition', 'Sesi lama harus dimigrasikan terlebih dahulu.');
    const now = Date.now();
    const expired = now >= session.expiresAt.toMillis();
    let answers = session.answers;
    // After the deadline only answers already accepted by the server are graded.
    if (!expired && !forced && submittedAnswers) {
      try { answers = { ...answers, ...validateAnswers(submittedAnswers, session.questions) }; }
      catch (e) { fail('invalid-argument', e.message); }
    }
    const questions = contentSnap.data().questions;
    const pgScore = scorePg(questions, answers, session.optionOrders);
    const endedAt = Timestamp.fromMillis(expired ? session.expiresAt.toMillis() : now);
    const result = {
      id: sessionId, userId: session.userId, examId: session.examId, sessionId,
      pgScore, totalScore: pgScore, gradingStatus: questions.some((q) => q.type === 'essay') ? 'pending_essay' : 'graded',
      submittedAt: endedAt, appSwitchCount: session.appSwitchCount,
    };
    tx.update(ref, { answers, endedAt, status: forced || expired ? 'auto_submitted' : 'completed' });
    tx.set(resultRef, result);
    return wire(result);
  });
}

async function submitExam(uid, data) {
  await actor(uid, ['siswa']);
  return finish(id(data.sessionId), data.answers, false, uid);
}

async function forceSubmit(uid, data) {
  const user = await actor(uid, ['guru', 'admin']);
  const session = (await db().doc(`exam_sessions/${id(data.sessionId)}`).get()).data();
  if (!session) fail('not-found', 'Sesi tidak ditemukan.');
  const exam = (await db().doc(`exams/${session.examId}`).get()).data();
  if (user.role !== 'admin' && exam?.createdBy !== uid) fail('permission-denied', 'Ujian bukan milik Anda.');
  return finish(data.sessionId, null, true);
}

async function submitGrades(uid, data) {
  await actor(uid, ['guru', 'admin']);
  const ref = db().doc(`exam_results/${id(data.resultId)}`);
  await db().runTransaction(async (tx) => {
    const result = (await tx.get(ref)).data();
    if (!result) fail('not-found', 'Hasil tidak ditemukan.');
    const [examSnap, contentSnap] = await Promise.all([
      tx.get(db().doc(`exams/${result.examId}`)), tx.get(db().doc(`session_content/${result.sessionId}`)),
    ]);
    if (examSnap.data()?.createdBy !== uid) fail('permission-denied', 'Ujian bukan milik Anda.');
    if (!contentSnap.exists) fail('failed-precondition', 'Snapshot sesi lama belum dimigrasikan.');
    let essayScore;
    try { essayScore = gradeEssays(contentSnap.data().questions, data.grades); }
    catch (e) { fail('invalid-argument', e.message); }
    tx.update(ref, { essayScore, essayGrades: data.grades, totalScore: result.pgScore + essayScore,
      gradedBy: uid, gradedAt: Timestamp.now(), gradingStatus: 'graded' });
  });
  return { saved: true };
}

async function manageUser(uid, data) {
  await actor(uid, ['admin']);
  const auth = getAuth();
  if (data.action === 'create') {
    if (!['guru', 'siswa'].includes(data.role) || typeof data.name !== 'string' || !data.name.trim() || data.name.trim().length > 100) {
      fail('invalid-argument', 'Nama atau peran pengguna tidak valid.');
    }
    let user;
    try {
      user = await auth.createUser({ email: data.email?.trim(), password: data.password, displayName: data.name.trim() });
      await db().doc(`users/${user.uid}`).set({ uid: user.uid, name: data.name.trim(), email: user.email,
        role: data.role, isActive: true, createdAt: Timestamp.now() });
    } catch (e) {
      if (user) await auth.deleteUser(user.uid);
      fail('failed-precondition', e.code === 'auth/email-already-exists' ? 'Email sudah terdaftar.' : 'Gagal membuat akun. Periksa email dan kata sandi (minimal 6 karakter).');
    }
    return { uid: user.uid };
  }
  const targetId = id(data.uid);
  if (targetId === uid) fail('failed-precondition', 'Akun sendiri tidak dapat diubah melalui pengelolaan pengguna.');
  const ref = db().doc(`users/${targetId}`);
  const user = (await ref.get()).data();
  if (!user || user.role === 'admin') fail('permission-denied', 'Akun tidak dapat diubah.');
  if (data.action === 'delete') {
    // Preserve history and a tombstone profile for report labels; revoke login permanently.
    await ref.update({ isActive: false });
    try { await auth.deleteUser(targetId); }
    catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
    await ref.update({ deleted: true });
  } else if (data.action === 'update') {
    const name = data.name ?? user.name;
    const role = data.role ?? user.role;
    const isActive = data.isActive ?? user.isActive;
    if (user.deleted || typeof name !== 'string' || !name.trim() || name.length > 100 || !['guru', 'siswa'].includes(role) || typeof isActive !== 'boolean') {
      fail('invalid-argument', 'Data pengguna tidak valid atau akun telah dihapus.');
    }
    if (role !== user.role) {
      const [exams, sessions] = await Promise.all([
        db().collection('exams').where('createdBy', '==', targetId).limit(1).get(),
        db().collection('exam_sessions').where('userId', '==', targetId).limit(1).get(),
      ]);
      if (!exams.empty || !sessions.empty) fail('failed-precondition', 'Peran akun dengan riwayat ujian tidak dapat diubah.');
    }
    // Deny Firestore access before disabling Auth; enabling happens in reverse order.
    if (!isActive) await ref.update({ isActive: false });
    await auth.updateUser(targetId, { displayName: name.trim(), disabled: !isActive });
    await ref.update({ name: name.trim(), role, isActive });
    if (!isActive) await auth.revokeRefreshTokens(targetId);
  } else fail('invalid-argument', 'Aksi tidak dikenal.');
  return { saved: true };
}

async function expireSessions() {
  const expired = await db().collection('exam_sessions').where('status', '==', 'in_progress')
    .where('expiresAt', '<=', Timestamp.now()).limit(200).get();
  for (const snap of expired.docs) await finish(snap.id, null, true);
}

module.exports = { createExam, editQuestions, deleteExam, previewExam, startExam, loadExam, saveAnswers, logAppSwitch, submitExam, forceSubmit, submitGrades, manageUser, expireSessions, finalizeSession: finish };
