import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ExamModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String code;
  final String createdBy;
  final int duration; // in minutes
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final int totalQuestions;

  const ExamModel({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.createdBy,
    required this.duration,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.totalQuestions,
  });

  ExamModel copyWith({
    String? id,
    String? title,
    String? description,
    String? code,
    String? createdBy,
    int? duration,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    int? totalQuestions,
  }) {
    return ExamModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      code: code ?? this.code,
      createdBy: createdBy ?? this.createdBy,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleOptions: shuffleOptions ?? this.shuffleOptions,
      totalQuestions: totalQuestions ?? this.totalQuestions,
    );
  }

  factory ExamModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ExamModel(
      id: id ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      code: json['code'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      startDate: json['startDate'] is Timestamp 
          ? (json['startDate'] as Timestamp).toDate() 
          : DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: json['endDate'] is Timestamp 
          ? (json['endDate'] as Timestamp).toDate() 
          : DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      shuffleQuestions: json['shuffleQuestions'] as bool? ?? false,
      shuffleOptions: json['shuffleOptions'] as bool? ?? false,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'code': code,
      'createdBy': createdBy,
      'duration': duration,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'totalQuestions': totalQuestions,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        code,
        createdBy,
        duration,
        startDate,
        endDate,
        isActive,
        shuffleQuestions,
        shuffleOptions,
        totalQuestions,
      ];
}
