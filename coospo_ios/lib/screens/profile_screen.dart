import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../database/profili_db.dart';
import 'package:uuid/uuid.dart';

class ProfilesScreen extends StatefulWidget {
  @override
  _ProfilesScreenState createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<UserProfile> profiles = []; // Lista profili
  UserProfile? activeProfile; // Profilo attivo

  @override
  void initState() {
    super.initState();
    _loadProfiles(); // Carica profili all'avvio
  }

  Future<void> _loadProfiles() async {
    final loadedProfiles = await ProfileDatabase.getAllProfiles(); // Prendi tutti i profili
    final active = await ProfileDatabase.getActiveProfile(); // Prendi profilo attivo
    
    setState(() {
      profiles = loadedProfiles; // Aggiorna lista profili
      activeProfile = active; // Aggiorna profilo attivo
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        title: const Text(
          'Profili Utente',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Torna indietro
        ),
      ),
      body: profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 80, color: Colors.white30), // Icona vuota
                  SizedBox(height: 20),
                  Text(
                    'Nessun profilo creato',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isActive = activeProfile?.id == profile.id; // Controlla se attivo
                
                return _buildProfileCard(profile, isActive); // Mostra scheda profilo
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProfileDialog(), // Apre dialog nuovo profilo
        backgroundColor: const Color.fromARGB(255, 255, 210, 31),
        icon: Icon(Icons.add, color: const Color.fromARGB(255, 0, 0, 0)),
        label: Text(
          'Nuovo Profilo',
          style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Scheda profilo utente
  Widget _buildProfileCard(UserProfile profile, bool isActive) {
    final canDelete = profiles.length > 1; // Si può eliminare se più di uno
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color.fromARGB(255, 255, 210, 31).withOpacity(0.3),
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
                ]
              : [
                  const Color.fromARGB(255, 255, 210, 31).withOpacity(0.1),
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color.fromARGB(255, 255, 210, 31)
              : const Color.fromARGB(255, 255, 210, 31).withOpacity(0.3),
          width: isActive ? 3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    profile.gender == 'male' ? Icons.male : Icons.female,
                    color: const Color.fromARGB(255, 255, 210, 31),
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: const Color.fromARGB(255, 255, 210, 31),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isActive)
                        Text(
                          '✅ Profilo attivo',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 210, 31),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _showEditProfileDialog(profile), // Modifica profilo
                  ),
                  if (!isActive)
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Colors.white54),
                      onPressed: () async {
                        await ProfileDatabase.setActiveProfile(profile.id); // Imposta profilo attivo
                        _loadProfiles();
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: canDelete ? Colors.red : Colors.grey,
                    ),
                    onPressed: canDelete ? () => _deleteProfile(profile) : null, // Elimina profilo
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip('Età', '${profile.age} anni'), // Età
              _buildInfoChip('Peso', '${profile.weight.toStringAsFixed(1)} kg'), // Peso
              _buildInfoChip('Sesso', profile.gender == 'male' ? 'M' : 'F'), // Sesso
            ],
          ),
        ],
      ),
    );
  }

  // Chip informativo
  Widget _buildInfoChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // Dialog modifica profilo
  void _showEditProfileDialog(UserProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final ageController = TextEditingController(text: profile.age.toString());
    final weightController = TextEditingController(text: profile.weight.toString());
    String selectedGender = profile.gender;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromARGB(255, 30, 30, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Modifica Profilo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedGender = 'male'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedGender == 'male'
                                ? const Color.fromARGB(255, 41, 134, 204).withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
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
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'M',
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedGender = 'female'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedGender == 'female'
                                ? const Color.fromARGB(255, 201, 0, 118).withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
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
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'F',
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
                SizedBox(height: 16),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Età (anni)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Peso (kg)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Annulla modifica
              child: Text('ANNULLA', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    ageController.text.isEmpty ||
                    weightController.text.isEmpty) {
                  return; // Non salva se campi vuoti
                }

                final updatedProfile = UserProfile(
                  id: profile.id, // Stesso ID
                  name: nameController.text,
                  gender: selectedGender,
                  age: int.parse(ageController.text),
                  weight: double.parse(weightController.text),
                );

                await ProfileDatabase.saveProfile(updatedProfile); // Salva profilo
                Navigator.pop(context);
                _loadProfiles(); // Ricarica lista
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color.fromARGB(255, 255, 210, 31)),
              child: Text('SALVA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // Elimina profilo con conferma
  Future<void> _deleteProfile(UserProfile profile) async {
    if (profiles.length == 1) { // Non elimina se unico profilo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non puoi eliminare l\'unico profilo esistente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Elimina Profilo',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Vuoi eliminare il profilo "${profile.name}"?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Annulla eliminazione
            child: Text('ANNULLA', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ProfileDatabase.deleteProfile(profile.id); // Elimina profilo
              Navigator.pop(context);
              _loadProfiles(); // Ricarica lista
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ELIMINA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Dialog crea nuovo profilo
  void _showCreateProfileDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final weightController = TextEditingController();
    String selectedGender = 'male';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromARGB(255, 30, 30, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Nuovo Profilo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedGender = 'male'), // Seleziona maschio
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedGender == 'male'
                                ? const Color.fromARGB(255, 41, 134, 204).withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
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
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'M',
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedGender = 'female'), // Seleziona femmina
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedGender == 'female'
                                ? const Color.fromARGB(255, 201, 0, 118).withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
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
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'F',
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
                SizedBox(height: 16),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Età (anni)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Peso (kg)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 255, 210, 31), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Annulla creazione
              child: Text('ANNULLA', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    ageController.text.isEmpty ||
                    weightController.text.isEmpty) {
                  return; // Non crea se campi vuoti
                }

                final profile = UserProfile(
                  id: Uuid().v4(), // Nuovo ID univoco
                  name: nameController.text,
                  gender: selectedGender,
                  age: int.parse(ageController.text),
                  weight: double.parse(weightController.text),
                );

                await ProfileDatabase.saveProfile(profile); // Salva profilo
                
                if (profiles.isEmpty) {
                  await ProfileDatabase.setActiveProfile(profile.id); // Imposta attivo se primo
                }
                
                Navigator.pop(context);
                _loadProfiles(); // Ricarica lista
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color.fromARGB(255, 255, 210, 31)),
              child: Text('SALVA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}