class UserProfile {
  final String id;
  final String name;
  final String gender;
  final int age;
  final double weight;

  UserProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.weight,
  });

  // Fattore correttivo in base al sesso (dispendio calorico leggermente diverso)
  double get genderFactor => gender == 'male' ? 1.05 : 0.95;

  // Fattore correttivo in base all’età (leggera riduzione del metabolismo con l’età)
  double get ageFactor => 1 - 0.005 * (age - 30);

  // Calcola le calorie bruciate in base a distanza, peso e velocità media
double calculateCalories(double distanceKm, double avgSpeedKmh, double durationSeconds) {
  double met;
  if (avgSpeedKmh < 4) {
    met = 2.5;
  } else if (avgSpeedKmh < 6) {
    met = 3.5;
  } else if (avgSpeedKmh < 8) {
    met = 5.0;
  } else if (avgSpeedKmh < 10) {
    met = 8.3;
  } else if (avgSpeedKmh < 12) {
    met = 10.0;
  } else if (avgSpeedKmh < 15) {
    met = 12.3;
  } else {
    met = 15.0;
  }

  double hours = durationSeconds / 3600;

  return met * weight * hours * genderFactor * ageFactor;
}

  // Converte l’oggetto in formato JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'age': age,
      'weight': weight,
    };
  }

  // Crea un oggetto UserProfile da una mappa JSON
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