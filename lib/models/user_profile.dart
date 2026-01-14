// lib/models/user_profile.dart

class UserProfile {
  final String name;
  final int age;
  final String gender;
  final String bio;

  // Mobile/desktop: local file path
  final String? profileImagePath;

  // Web testing: base64-encoded image bytes
  final String? profileImageBase64;

  UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.bio,
    this.profileImagePath,
    this.profileImageBase64,
  });


  // Convert object → Map (for SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'bio': bio,
            'profileImagePath': profileImagePath,
      'profileImageBase64': profileImageBase64,

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
      profileImageBase64: map['profileImageBase64'],

    );
  }

  // For updating parts of the profile (used in ProfileScreen)
   UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? bio,
    String? profileImagePath,
    String? profileImageBase64,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
    );
  }
}
