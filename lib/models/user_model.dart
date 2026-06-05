import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String role; // admin | guru | siswa
  final DateTime createdAt;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.isActive,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'siswa',
      createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [uid, name, email, role, createdAt, isActive];
}
