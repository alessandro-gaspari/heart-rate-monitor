class UserProfile {
  final String id;
  final String name;
  final String gender; // 'male' o 'female'
  final int age;
  final double weight; // in kg

  UserProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.weight,
  });

  // Fattore sesso
  double get genderFactor => gender == 'male' ? 1.05 : 0.95;

  // Fattore età
  double get ageFactor => 1 - 0.005 * (age - 30);

  // Calcola calorie consumate
  double calculateCalories(double distanceKm, double avgSpeedKmh) {
    return distanceKm * weight * 
           ((0.035 + 0.029 * (avgSpeedKmh / 10)) * genderFactor * ageFactor);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'age': age,
      'weight': weight,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      gender: json['gender'],
      age: json['age'],
      weight: json['weight'].toDouble(),
    );
  }
}
