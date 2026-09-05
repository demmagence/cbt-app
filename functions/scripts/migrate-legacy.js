// Preview old data before deploying the new app/rules. Writes require --apply.
// Each changed source document is backed up inside migration_backups (server only).
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { publicQuestion } = require('../domain');
const args = process.argv.slice(2);
if (!args.includes('--project')) throw new Error('Required: --project PROJECT_ID [--apply]');
initializeApp({ projectId: args[args.indexOf('--project') + 1] });
const db = getFirestore(process.env.CBT_DATABASE_ID || 'cbt-db');
const apply = args.includes('--apply');
const run = `legacy_${Date.now()}`;

async function migrate() {
  const [sessionDocs, examDocs, bankDocs, results] = await Promise.all([
    db.collection('exam_sessions').get(), db.collection('exams').get(), db.collection('question_bank').get(), db.collection('exam_results').get(),
  ]);
  const groups = new Map();
  for (const doc of sessionDocs.docs) {
    const key = `${doc.data().userId}_${doc.data().examId}`;
    groups.set(key, [...(groups.get(key) || []), doc]);
  }
  // Preserve the only attempt containing the most answers. Empty duplicate retries are
  // archived with the run backup. Ties remain ambiguous and stop the whole migration.
  const selectedGroups = new Map();
  const discardedDuplicates = new Map();
  const ambiguous = [];
  for (const [key, docs] of groups) {
    if (!examDocs.docs.some((exam) => exam.id === docs[0].data().examId)) {
      ambiguous.push([key, docs]);
      continue;
    }
    const ranked = [...docs].sort((a, b) =>
      Object.keys(b.data().answers || {}).length - Object.keys(a.data().answers || {}).length);
    const bestCount = Object.keys(ranked[0].data().answers || {}).length;
    const secondCount = ranked[1] ? Object.keys(ranked[1].data().answers || {}).length : -1;
    if (ranked.length > 1 && (bestCount === 0 || bestCount === secondCount)) {
      ambiguous.push([key, docs]);
      continue;
    }
    selectedGroups.set(key, [ranked[0]]);
    discardedDuplicates.set(key, ranked.slice(1));
  }
  if (ambiguous.length) {
    console.error('Resolve tied/empty duplicate sessions or missing exams before migration:', ambiguous.map(([key]) => key));
    process.exitCode = 1;
    return;
  }
  for (const [key, docs] of discardedDuplicates) {
    if (!docs.length) continue;
    const resultIds = new Set(results.docs.filter((result) =>
      docs.some((doc) => result.id === doc.id || result.data().sessionId === doc.id)).map((result) => result.id));
    if (resultIds.size) throw new Error(`Discarded duplicate for ${key} has a result (${[...resultIds]}); select it manually.`);
    console.log(`Keep answered session for ${key}; archive empty duplicate(s): ${docs.map((doc) => doc.id).join(', ')}`);
  }
  const plans = [];
  const recoverResults = [];
  for (const [key, docs] of selectedGroups) {
    const doc = docs[0];
    if (doc.id === key && (await db.doc(`session_content/${key}`).get()).exists) {
      if (!results.docs.some((r) => r.id === key) && doc.data().expiresAt?.toMillis() <= Date.now()) {
        console.log(`Restore missing result from existing snapshot: ${key}`);
        recoverResults.push(key);
      }
      continue;
    }
    const session = doc.data();
    const examDoc = examDocs.docs.find((item) => item.id === session.examId);
    const exam = examDoc.data();
    const questionDocs = await examDoc.ref.collection('questions').get();
    const questionMap = new Map(questionDocs.docs.map((q) => [q.id, { ...q.data(), id: q.id }]));
    const order = session.questionOrder?.length ? session.questionOrder : [...questionMap.values()].sort((a, b) => a.order - b.order).map((q) => q.id);
    const questions = order.map((id) => questionMap.get(id));
    if (!questions.length || questions.some((q) => !q)) throw new Error(`Missing original questions for ${key}; recover a backup before migration.`);
    const optionOrders = { ...session.optionOrders };
    for (const q of questions.filter((q) => q.type === 'pg')) {
      if (!Array.isArray(q.options) || !Number.isInteger(q.correctAnswer) || q.correctAnswer < 0 || q.correctAnswer >= q.options.length) {
        throw new Error(`Invalid original answer key for ${key}/${q.id}.`);
      }
      if (!optionOrders[q.id] && !exam.shuffleOptions) optionOrders[q.id] = q.options.map((_, i) => i);
      const indices = optionOrders[q.id];
      if (!Array.isArray(indices) || indices.length !== q.options.length || new Set(indices).size !== indices.length || indices.some((i) => !Number.isInteger(i) || i < 0 || i >= q.options.length)) {
        throw new Error(`Missing or invalid original option order for ${key}/${q.id}; recover a backup.`);
      }
    }
    const startedAt = session.startedAt instanceof Timestamp ? session.startedAt : Timestamp.fromDate(new Date(session.startedAt));
    const expiresAt = Timestamp.fromMillis(Math.min(startedAt.toMillis() + exam.duration * 60000, exam.endDate.toMillis()));
    if (session.status === 'in_progress' && expiresAt.toMillis() > Date.now()) {
      throw new Error(`Session ${key} is still active; wait until all exams end before migration.`);
    }
    const resultDoc = results.docs.find((r) => r.data().sessionId === doc.id) || results.docs.find((r) => r.data().userId === session.userId && r.data().examId === session.examId);
    console.log(`Session ${doc.id} -> ${key}; ${resultDoc ? 'preserve existing score' : 'compute score from saved answers'}`);
    plans.push({ key, doc, session, examDoc, exam, questions, order, optionOrders, startedAt, expiresAt, resultDoc,
      discarded: discardedDuplicates.get(key) || [] });
  }
  // Validate every session before writing any of them.
  for (const { key, doc, session, examDoc, exam, questions, order, optionOrders, startedAt, expiresAt, resultDoc, discarded } of plans) {
    if (apply) {
      const batch = db.batch();
      batch.set(db.doc(`migration_backups/${run}/documents/session_${doc.id}`), { path: doc.ref.path, data: session });
      batch.set(db.doc(`migration_backups/${run}/documents/exam_${examDoc.id}`), { path: examDoc.ref.path, data: exam });
      for (const duplicate of discarded) {
        batch.set(db.doc(`migration_backups/${run}/documents/session_${duplicate.id}`), {
          path: duplicate.ref.path, data: duplicate.data(), archivedReason: 'empty_duplicate_attempt', keptSessionId: doc.id,
        });
        batch.delete(duplicate.ref);
      }
      const normalized = { ...session, id: key, startedAt, expiresAt, questionOrder: order, optionOrders, questions: questions.map(publicQuestion) };
      if (normalized.endedAt != null && !(normalized.endedAt instanceof Timestamp)) normalized.endedAt = Timestamp.fromDate(new Date(normalized.endedAt));
      if (normalized.endedAt == null) delete normalized.endedAt;
      batch.set(db.doc(`exam_sessions/${key}`), normalized);
      batch.set(db.doc(`session_content/${key}`), { examId: session.examId, exam, questions });
      batch.update(examDoc.ref, { locked: true });
      if (doc.id !== key) batch.delete(doc.ref);
      if (resultDoc) {
        batch.set(db.doc(`migration_backups/${run}/documents/result_${resultDoc.id}`), { path: resultDoc.ref.path, data: resultDoc.data() });
        const result = { ...resultDoc.data(), id: key, sessionId: key };
        for (const field of ['submittedAt', 'gradedAt']) {
          if (result[field] != null && !(result[field] instanceof Timestamp)) result[field] = Timestamp.fromDate(new Date(result[field]));
        }
        batch.set(db.doc(`exam_results/${key}`), result);
        if (resultDoc.id !== key) batch.delete(resultDoc.ref);
      }
      await batch.commit();
      if (!resultDoc) await require('../backend').finalizeSession(key, null, true);
    }
  }
  if (apply) {
    for (const key of recoverResults) await require('../backend').finalizeSession(key, null, true);
  }
  for (const doc of bankDocs.docs) {
    if (!('createdAt' in doc.data())) continue;
    console.log(`Normalize question bank ${doc.id}`);
    if (apply) {
      const { createdAt, ...data } = doc.data();
      const batch = db.batch();
      batch.set(db.doc(`migration_backups/${run}/documents/bank_${doc.id}`), { path: doc.ref.path, data: doc.data() });
      batch.set(doc.ref, data);
      await batch.commit();
    }
  }
  console.log(apply ? `Migration complete. Backup run: ${run}` : 'Dry run complete. No writes. Run --apply only during maintenance after a Firestore export.');
}
migrate().catch((error) => { console.error(error); process.exitCode = 1; });
