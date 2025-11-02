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
  double calculateCalories(double distanceKm, double avgSpeedKmh) {
    return distanceKm * weight *
           ((0.035 + 0.029 * (avgSpeedKmh / 10)) * genderFactor * ageFactor);
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