import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../database/profili_db.dart';
import 'package:uuid/uuid.dart';

class WelcomeProfileScreen extends StatefulWidget {
  @override
  _WelcomeProfileScreenState createState() => _WelcomeProfileScreenState();
}

class _WelcomeProfileScreenState extends State<WelcomeProfileScreen> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  String selectedGender = 'male';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Emoji per il benvenuto
              const Text(
                '👋',
                style: TextStyle(fontSize: 80),
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                'Benvenuto!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 210, 31),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'SF Pro Display',
                ),
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                'Crea il tuo profilo per iniziare\na tracciare le tue attività',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Nome
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Nome',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.person, color: Color.fromARGB(255, 255, 210, 31)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 3),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Selezione genere con icone
              const Text(
                'Genere',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'male'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: selectedGender == 'male'
                              ? const Color.fromARGB(255, 41, 134, 204).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedGender == 'male'
                                ? const Color.fromARGB(255, 41, 134, 204)
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.man,
                              color: selectedGender == 'male'
                                  ? const Color.fromARGB(255, 41, 134, 204)
                                  : Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Maschio',
                              style: TextStyle(
                                color: selectedGender == 'male'
                                    ? const Color.fromARGB(255, 41, 134, 204)
                                    : Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: selectedGender == 'female'
                              ? const Color.fromARGB(255, 201, 0, 118).withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedGender == 'female'
                                ? const Color.fromARGB(255, 201, 0, 118)
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.woman,
                              color: selectedGender == 'female'
                                  ? const Color.fromARGB(255, 201, 0, 118)
                                  : Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Femmina',
                              style: TextStyle(
                                color: selectedGender == 'female'
                                    ? const Color.fromARGB(255, 201, 0, 118)
                                    : Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Età
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Età (anni)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.cake, color: Color.fromARGB(255, 255, 210, 31)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 3),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Peso
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Peso (kg)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.monitor_weight, color: Color.fromARGB(255, 255, 210, 31)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 3),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Bottone Inizia
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 210, 31),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color.fromARGB(255, 255, 210, 31).withOpacity(0.5),
                  ),
                  child: const Text(
                    'INIZIA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    if (nameController.text.isEmpty ||
        ageController.text.isEmpty ||
        weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compila tutti i campi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final profile = UserProfile(
      id: const Uuid().v4(),
      name: nameController.text,
      gender: selectedGender,
      age: int.parse(ageController.text),
      weight: double.parse(weightController.text),
    );

    await ProfileDatabase.saveProfile(profile);
    await ProfileDatabase.setActiveProfile(profile.id);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
