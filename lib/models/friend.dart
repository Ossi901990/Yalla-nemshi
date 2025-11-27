// lib/models/friend.dart

class Friend {
  final String id;
  final String name;
  final String bio;
  final int walksTogether;
  final bool isFavorite;

  const Friend({
    required this.id,
    required this.name,
    required this.bio,
    required this.walksTogether,
    this.isFavorite = false,
  });

  Friend copyWith({
    String? id,
    String? name,
    String? bio,
    int? walksTogether,
    bool? isFavorite,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      walksTogether: walksTogether ?? this.walksTogether,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
