import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class EssayGrade extends Equatable {
  final num score;
  final String feedback;

  const EssayGrade({
    required this.score,
    required this.feedback,
  });

  EssayGrade copyWith({
    num? score,
    String? feedback,
  }) {
    return EssayGrade(
      score: score ?? this.score,
      feedback: feedback ?? this.feedback,
    );
  }

  factory EssayGrade.fromJson(Map<String, dynamic> json) {
    return EssayGrade(
      score: json['score'] as num? ?? 0,
      feedback: json['feedback'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'feedback': feedback,
    };
  }

  @override
  List<Object?> get props => [score, feedback];
}

class ExamResultModel extends Equatable {
  final String id;
  final String examId;
  final String userId;
  final String sessionId;
  final num pgScore;
  final num? essayScore;
  final num totalScore;
  final String gradingStatus; // graded | pending_essay | auto_submitted
  final Map<String, EssayGrade>? essayGrades; // key: questionId
  final DateTime submittedAt;
  final DateTime? gradedAt;
  final String? gradedBy;

  const ExamResultModel({
    required this.id,
    required this.examId,
    required this.userId,
    required this.sessionId,
    required this.pgScore,
    this.essayScore,
    required this.totalScore,
    required this.gradingStatus,
    this.essayGrades,
    required this.submittedAt,
    this.gradedAt,
    this.gradedBy,
  });

  ExamResultModel copyWith({
    String? id,
    String? examId,
    String? userId,
    String? sessionId,
    num? pgScore,
    num? essayScore,
    num? totalScore,
    String? gradingStatus,
    Map<String, EssayGrade>? essayGrades,
    DateTime? submittedAt,
    DateTime? gradedAt,
    String? gradedBy,
  }) {
    return ExamResultModel(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      pgScore: pgScore ?? this.pgScore,
      essayScore: essayScore ?? this.essayScore,
      totalScore: totalScore ?? this.totalScore,
      gradingStatus: gradingStatus ?? this.gradingStatus,
      essayGrades: essayGrades ?? this.essayGrades,
      submittedAt: submittedAt ?? this.submittedAt,
      gradedAt: gradedAt ?? this.gradedAt,
      gradedBy: gradedBy ?? this.gradedBy,
    );
  }

  factory ExamResultModel.fromJson(Map<String, dynamic> json, {String? id}) {
    Map<String, EssayGrade>? grades;
    if (json['essayGrades'] != null) {
      grades = {};
      final rawGrades = json['essayGrades'] as Map<String, dynamic>;
      rawGrades.forEach((key, value) {
        grades![key] = EssayGrade.fromJson(Map<String, dynamic>.from(value as Map));
      });
    }

    return ExamResultModel(
      id: id ?? json['id'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      pgScore: json['pgScore'] as num? ?? 0,
      essayScore: json['essayScore'] as num?,
      totalScore: json['totalScore'] as num? ?? 0,
      gradingStatus: json['gradingStatus'] as String? ?? 'pending_essay',
      essayGrades: grades,
      submittedAt: json['submittedAt'] is Timestamp 
          ? (json['submittedAt'] as Timestamp).toDate() 
          : DateTime.tryParse(json['submittedAt']?.toString() ?? '') ?? DateTime.now(),
      gradedAt: json['gradedAt'] is Timestamp 
          ? (json['gradedAt'] as Timestamp).toDate() 
          : json['gradedAt'] != null ? DateTime.tryParse(json['gradedAt'].toString()) : null,
      gradedBy: json['gradedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'examId': examId,
      'userId': userId,
      'sessionId': sessionId,
      'pgScore': pgScore,
      'essayScore': essayScore,
      'totalScore': totalScore,
      'gradingStatus': gradingStatus,
      'essayGrades': essayGrades?.map((key, value) => MapEntry(key, value.toJson())),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'gradedAt': gradedAt != null ? Timestamp.fromDate(gradedAt!) : null,
      'gradedBy': gradedBy,
    };
  }

  @override
  List<Object?> get props => [
        id,
        examId,
        userId,
        sessionId,
        pgScore,
        essayScore,
        totalScore,
        gradingStatus,
        essayGrades,
        submittedAt,
        gradedAt,
        gradedBy,
      ];
}
