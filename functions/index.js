const { initializeApp } = require('firebase-admin/app');
const { onCall } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
initializeApp();
const backend = require('./backend');
for (const name of ['createExam', 'editQuestions', 'deleteExam', 'previewExam', 'startExam', 'loadExam', 'saveAnswers', 'logAppSwitch', 'submitExam', 'forceSubmit', 'submitGrades', 'manageUser']) {
  exports[name] = onCall({ region: 'asia-southeast2', maxInstances: 10 },
    (request) => backend[name](request.auth?.uid, request.data || {}));
}
exports.expireSessions = onSchedule({ region: 'asia-southeast2', schedule: 'every 1 minutes', maxInstances: 1 }, backend.expireSessions);
