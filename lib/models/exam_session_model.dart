import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppSwitchLog extends Equatable {
  final DateTime timestamp;
  final int duration; // in seconds
  final String type; // e.g. "app_switch"

  const AppSwitchLog({
    required this.timestamp,
    required this.duration,
    required this.type,
  });

  AppSwitchLog copyWith({
    DateTime? timestamp,
    int? duration,
    String? type,
  }) {
    return AppSwitchLog(
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      type: type ?? this.type,
    );
  }

  factory AppSwitchLog.fromJson(Map<String, dynamic> json) {
    return AppSwitchLog(
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      duration: json['duration'] as int? ?? 0,
      type: json['type'] as String? ?? 'app_switch',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration,
      'type': type,
    };
  }

  @override
  List<Object?> get props => [timestamp, duration, type];
}

class ExamSessionModel extends Equatable {
  final String id;
  final String examId;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // in_progress | completed | auto_submitted
  final List<String> questionOrder; // shuffled question IDs
  final Map<String, List<int>> optionOrders; // key: questionId, value: shuffled option indices
  final Map<String, dynamic> answers; // key: questionId, value: selectedIndex (int) or essayText (String)
  final int appSwitchCount;
  final List<AppSwitchLog> appSwitchLogs;

  const ExamSessionModel({
    required this.id,
    required this.examId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    required this.questionOrder,
    required this.optionOrders,
    required this.answers,
    required this.appSwitchCount,
    required this.appSwitchLogs,
  });

  ExamSessionModel copyWith({
    String? id,
    String? examId,
    String? userId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? status,
    List<String>? questionOrder,
    Map<String, List<int>>? optionOrders,
    Map<String, dynamic>? answers,
    int? appSwitchCount,
    List<AppSwitchLog>? appSwitchLogs,
  }) {
    return ExamSessionModel(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      questionOrder: questionOrder ?? this.questionOrder,
      optionOrders: optionOrders ?? this.optionOrders,
      answers: answers ?? this.answers,
      appSwitchCount: appSwitchCount ?? this.appSwitchCount,
      appSwitchLogs: appSwitchLogs ?? this.appSwitchLogs,
    );
  }

  factory ExamSessionModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final qOrder = List<String>.from(json['questionOrder'] as List? ?? []);

    final rawOptionOrders = json['optionOrders'] as Map<String, dynamic>? ?? {};
    final oOrders = rawOptionOrders.map((key, value) {
      return MapEntry(key, List<int>.from(value as List));
    });

    final ans = Map<String, dynamic>.from(json['answers'] as Map? ?? {});

    final rawLogs = json['appSwitchLogs'] as List? ?? [];
    final logs = rawLogs.map((item) {
      return AppSwitchLog.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();

    return ExamSessionModel(
      id: id ?? json['id'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      startedAt: json['startedAt'] is Timestamp 
          ? (json['startedAt'] as Timestamp).toDate() 
          : DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] is Timestamp 
          ? (json['endedAt'] as Timestamp).toDate() 
          : json['endedAt'] != null ? DateTime.tryParse(json['endedAt'].toString()) : null,
      status: json['status'] as String? ?? 'in_progress',
      questionOrder: qOrder,
      optionOrders: oOrders,
      answers: ans,
      appSwitchCount: json['appSwitchCount'] as int? ?? 0,
      appSwitchLogs: logs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'examId': examId,
      'userId': userId,
      'startedAt': Timestamp.fromDate(startedAt),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'status': status,
      'questionOrder': questionOrder,
      'optionOrders': optionOrders,
      'answers': answers,
      'appSwitchCount': appSwitchCount,
      'appSwitchLogs': appSwitchLogs.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        examId,
        userId,
        startedAt,
        endedAt,
        status,
        questionOrder,
        optionOrders,
        answers,
        appSwitchCount,
        appSwitchLogs,
      ];
}
