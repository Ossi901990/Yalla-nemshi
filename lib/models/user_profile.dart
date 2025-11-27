// lib/models/user_profile.dart

class UserProfile {
  final String name;
  final int age;
  final String gender;
  final String bio;
  final String? profileImagePath; // local path for profile photo

  UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.bio,
    this.profileImagePath,
  });

  // Convert object → Map (for SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'bio': bio,
      'profileImagePath': profileImagePath,
    };
  }

  // Convert Map → object
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? 'Not set',
      bio: map['bio'] ?? '',
      profileImagePath: map['profileImagePath'],
    );
  }

  // For updating parts of the profile (used in ProfileScreen)
  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? bio,
    String? profileImagePath,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }
}
