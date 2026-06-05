import 'package:equatable/equatable.dart';

class QuestionModel extends Equatable {
  final String id;
  final String type; // pg | essay
  final String text;
  final List<String>? options; // null or empty for essay
  final int? correctAnswer; // index of correct option, null for essay
  final String? essayGuideline; // null for pg
  final num maxScore; // default 1 for pg
  final int order;
  final num points; // default: 1

  const QuestionModel({
    required this.id,
    required this.type,
    required this.text,
    this.options,
    this.correctAnswer,
    this.essayGuideline,
    required this.maxScore,
    required this.order,
    required this.points,
  });

  bool get isPg => type == 'pg';
  bool get isEssay => type == 'essay';

  QuestionModel copyWith({
    String? id,
    String? type,
    String? text,
    List<String>? options,
    int? correctAnswer,
    String? essayGuideline,
    num? maxScore,
    int? order,
    num? points,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      essayGuideline: essayGuideline ?? this.essayGuideline,
      maxScore: maxScore ?? this.maxScore,
      order: order ?? this.order,
      points: points ?? this.points,
    );
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return QuestionModel(
      id: id ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'pg',
      text: json['text'] as String? ?? '',
      options: json['options'] != null 
          ? List<String>.from(json['options'] as List) 
          : null,
      correctAnswer: json['correctAnswer'] as int?,
      essayGuideline: json['essayGuideline'] as String?,
      maxScore: json['maxScore'] as num? ?? 1,
      order: json['order'] as int? ?? 0,
      points: json['points'] as num? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'text': text,
      if (options != null) 'options': options,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
      if (essayGuideline != null) 'essayGuideline': essayGuideline,
      'maxScore': maxScore,
      'order': order,
      'points': points,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        text,
        options,
        correctAnswer,
        essayGuideline,
        maxScore,
        order,
        points,
      ];
}
