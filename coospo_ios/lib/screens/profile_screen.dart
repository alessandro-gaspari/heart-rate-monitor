import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../database/profili_db.dart';
import 'package:uuid/uuid.dart';

class ProfilesScreen extends StatefulWidget {
  @override
  _ProfilesScreenState createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<UserProfile> profiles = [];
  UserProfile? activeProfile;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final loadedProfiles = await ProfileDatabase.getAllProfiles();
    final active = await ProfileDatabase.getActiveProfile();
    
    setState(() {
      profiles = loadedProfiles;
      activeProfile = active;
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 80, color: Colors.white30),
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
                final isActive = activeProfile?.id == profile.id;
                
                return _buildProfileCard(profile, isActive);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProfileDialog(),
        backgroundColor: const Color.fromARGB(255, 255, 210, 31),
        icon: Icon(Icons.add, color: const Color.fromARGB(255, 0, 0, 0)),
        label: Text(
          'Nuovo Profilo',
          style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, bool isActive) {
    final canDelete = profiles.length > 1; // ⭐ Può cancellare solo se ci sono più profili
    
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
                  // ⭐ BOTTONE MODIFICA
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _showEditProfileDialog(profile),
                  ),
                  if (!isActive)
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Colors.white54),
                      onPressed: () async {
                        await ProfileDatabase.setActiveProfile(profile.id);
                        _loadProfiles();
                      },
                    ),
                  // ⭐ BOTTONE CANCELLA (disabilitato se unico profilo)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: canDelete ? Colors.red : Colors.grey,
                    ),
                    onPressed: canDelete ? () => _deleteProfile(profile) : null,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip('Età', '${profile.age} anni'),
              _buildInfoChip('Peso', '${profile.weight.toStringAsFixed(1)} kg'),
              _buildInfoChip('Sesso', profile.gender == 'male' ? 'M' : 'F'),
            ],
          ),
        ],
      ),
    );
  }

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

  // ⭐ DIALOG MODIFICA PROFILO
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
              onPressed: () => Navigator.pop(context),
              child: Text('ANNULLA', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    ageController.text.isEmpty ||
                    weightController.text.isEmpty) {
                  return;
                }

                final updatedProfile = UserProfile(
                  id: profile.id, // ⭐ Mantieni stesso ID
                  name: nameController.text,
                  gender: selectedGender,
                  age: int.parse(ageController.text),
                  weight: double.parse(weightController.text),
                );

                await ProfileDatabase.saveProfile(updatedProfile);
                Navigator.pop(context);
                _loadProfiles();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color.fromARGB(255, 255, 210, 31)),
              child: Text('SALVA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ CANCELLA PROFILO (con controllo)
  Future<void> _deleteProfile(UserProfile profile) async {
    if (profiles.length == 1) {
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
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULLA', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ProfileDatabase.deleteProfile(profile.id);
              Navigator.pop(context);
              _loadProfiles();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ELIMINA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
              onPressed: () => Navigator.pop(context),
              child: Text('ANNULLA', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    ageController.text.isEmpty ||
                    weightController.text.isEmpty) {
                  return;
                }

                final profile = UserProfile(
                  id: Uuid().v4(),
                  name: nameController.text,
                  gender: selectedGender,
                  age: int.parse(ageController.text),
                  weight: double.parse(weightController.text),
                );

                await ProfileDatabase.saveProfile(profile);
                
                if (profiles.isEmpty) {
                  await ProfileDatabase.setActiveProfile(profile.id);
                }
                
                Navigator.pop(context);
                _loadProfiles();
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
