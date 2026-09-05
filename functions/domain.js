const { randomInt } = require('node:crypto');

function shuffle(values) {
  const result = [...values];
  for (let i = result.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function publicQuestion(question) {
  const { correctAnswer, essayGuideline, ...visible } = question;
  return visible;
}

function validateAnswers(answers, questions) {
  if (!answers || typeof answers !== 'object' || Array.isArray(answers)) {
    throw new Error('Jawaban tidak valid.');
  }
  const result = {};
  for (const [id, answer] of Object.entries(answers)) {
    const q = questions.find((item) => item.id === id);
    if (!q || (q.type === 'pg'
      ? !Number.isInteger(answer) || answer < 0 || answer >= q.options.length
      : typeof answer !== 'string' || answer.length > 10000)) {
      throw new Error('Jawaban tidak sesuai dengan soal.');
    }
    result[id] = answer;
  }
  return result;
}

function scorePg(questions, answers, optionOrders) {
  return questions.reduce((total, q) => {
    if (q.type !== 'pg' || !Number.isInteger(answers[q.id])) return total;
    const original = (optionOrders[q.id] || [])[answers[q.id]];
    return total + (original === q.correctAnswer ? q.points : 0);
  }, 0);
}

function gradeEssays(questions, grades) {
  const essays = questions.filter((q) => q.type === 'essay');
  if (!grades || typeof grades !== 'object' || Array.isArray(grades) ||
      Object.keys(grades).length !== essays.length) throw new Error('Nilai semua soal esai harus diisi.');
  let total = 0;
  for (const q of essays) {
    const grade = grades[q.id];
    if (!grade || !Number.isFinite(grade.score) || grade.score < 0 || grade.score > q.maxScore ||
        typeof grade.feedback !== 'string' || grade.feedback.length > 2000) {
      throw new Error('Nilai esai di luar rentang atau umpan balik terlalu panjang.');
    }
    total += grade.score;
  }
  return total;
}

module.exports = { shuffle, publicQuestion, validateAnswers, scorePg, gradeEssays };
