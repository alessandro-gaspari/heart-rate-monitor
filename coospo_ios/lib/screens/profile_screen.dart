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
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
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
        backgroundColor: const Color(0xFFFC5200),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nuovo Profilo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, bool isActive) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFFFC5200).withOpacity(0.3),
                  const Color(0xFF0A0E21).withOpacity(0.8),
                ]
              : [
                  const Color(0xFFFC5200).withOpacity(0.1),
                  const Color(0xFF0A0E21).withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFC5200)
              : const Color(0xFFFC5200).withOpacity(0.3),
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
                    color: const Color(0xFFFC5200),
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isActive)
                        Text(
                          '✅ Profilo attivo',
                          style: TextStyle(
                            color: Color(0xFFFC5200),
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
                  if (!isActive)
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Colors.white54),
                      onPressed: () async {
                        await ProfileDatabase.setActiveProfile(profile.id);
                        _loadProfiles();
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await ProfileDatabase.deleteProfile(profile.id);
                      _loadProfiles();
                    },
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

  void _showCreateProfileDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final weightController = TextEditingController();
    String selectedGender = 'male';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
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
                      borderSide: BorderSide(color: Color(0xFFFC5200)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFC5200), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Maschio', style: TextStyle(color: Colors.white)),
                        value: 'male',
                        groupValue: selectedGender,
                        activeColor: Color(0xFFFC5200),
                        onChanged: (value) {
                          setDialogState(() => selectedGender = value!);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Femmina', style: TextStyle(color: Colors.white)),
                        value: 'female',
                        groupValue: selectedGender,
                        activeColor: Color(0xFFFC5200),
                        onChanged: (value) {
                          setDialogState(() => selectedGender = value!);
                        },
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
                      borderSide: BorderSide(color: Color(0xFFFC5200)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFC5200), width: 2),
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
                      borderSide: BorderSide(color: Color(0xFFFC5200)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFC5200), width: 2),
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
                
                // Se è il primo profilo, impostalo come attivo
                if (profiles.isEmpty) {
                  await ProfileDatabase.setActiveProfile(profile.id);
                }
                
                Navigator.pop(context);
                _loadProfiles();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFC5200)),
              child: Text('SALVA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
