const { test } = require('node:test');
const assert = require('node:assert/strict');
const { publicQuestion, validateAnswers, scorePg, gradeEssays, shuffle } = require('../domain');
const questions = [
  { id: 'pg', type: 'pg', options: ['A', 'B'], correctAnswer: 1, points: 3 },
  { id: 'essay', type: 'essay', maxScore: 7, essayGuideline: 'private' },
];
test('student questions never contain scoring secrets', () => {
  for (const question of questions) {
    assert.equal('correctAnswer' in publicQuestion(question), false);
    assert.equal('essayGuideline' in publicQuestion(question), false);
  }
});
test('PG score uses the original option after shuffling', () => {
  assert.equal(scorePg(questions, { pg: 0 }, { pg: [1, 0] }), 3);
  assert.equal(scorePg(questions, { pg: 1 }, { pg: [1, 0] }), 0);
  assert.equal(scorePg(questions, {}, { pg: [1, 0] }), 0);
});
test('answer validation rejects unknown questions, wrong types and oversized essays', () => {
  for (const answers of [{ unknown: 0 }, { pg: 2 }, { pg: '1' }, { essay: 1 }, { essay: 'x'.repeat(10001) }]) {
    assert.throws(() => validateAnswers(answers, questions));
  }
  assert.deepEqual(validateAnswers({ pg: 0, essay: 'Jawaban' }, questions), { pg: 0, essay: 'Jawaban' });
});
test('all essays must be graded within each question maximum', () => {
  assert.equal(gradeEssays(questions, { essay: { score: 7, feedback: '' } }), 7);
  for (const grades of [{}, { essay: { score: 8, feedback: '' } }, { essay: { score: -1, feedback: '' } }, { essay: { score: NaN, feedback: '' } }]) {
    assert.throws(() => gradeEssays(questions, grades));
  }
});
test('shuffle preserves every option exactly once', () => {
  for (let i = 0; i < 100; i++) assert.deepEqual(shuffle([0, 1, 2, 3]).sort(), [0, 1, 2, 3]);
});
