import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  bool loading = false;
  Map<String, dynamic>? data;

  final firstNameCtl = TextEditingController();
  final lastNameCtl = TextEditingController();
  final usernameCtl = TextEditingController();
  final emailCtl = TextEditingController();
  List<String> preferences = [];

  String? avatarUrl;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    data = res;

    firstNameCtl.text = res['first_name'] ?? '';
    lastNameCtl.text = res['last_name'] ?? '';
    usernameCtl.text = res['username'] ?? '';
    emailCtl.text = res['email'] ?? '';
    avatarUrl = res['avatar_url'];
    preferences = List<String>.from(res['preferences'] ?? []);

    setState(() => loading = false);
  }

  Future<void> updateProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    await supabase
        .from('profiles')
        .update({
          'first_name': firstNameCtl.text.trim(),
          'last_name': lastNameCtl.text.trim(),
          'username': usernameCtl.text.trim(),
          'email': emailCtl.text.trim(),
          'preferences': preferences,
          'avatar_url': avatarUrl,
        })
        .eq('id', user.id);

    setState(() => loading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Profile updated")));
  }

  Future<void> pickImage() async {
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    await uploadAvatar(bytes, img.name);
  }

  Future<void> uploadAvatar(Uint8List bytes, String filename) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    final path = "${user.id}/$filename";

    await supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

    avatarUrl = publicUrl;

    await updateProfile();

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5E5D1),

      body: Stack(
        children: [
          Container(
            height: 260,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/profile_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 60)
                      : null,
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 260),
            child: Column(
              children: [
                const SizedBox(height: 50),

                Text(
                  "${firstNameCtl.text} ${lastNameCtl.text}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                ElevatedButton.icon(
                  onPressed: () => showEditSheet(),
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Profile"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF5E5D1),
                    foregroundColor: Colors.black87,
                  ),
                ),

                const SizedBox(height: 20),

                buildSectionTitle("Preferences"),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preferences.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E4C8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.brown, width: 0.7),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                buildSectionTitle("Username"),
                Text(usernameCtl.text, style: const TextStyle(fontSize: 16)),

                const SizedBox(height: 16),

                buildSectionTitle("Email"),
                Text(emailCtl.text, style: const TextStyle(fontSize: 16)),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        color: const Color(0xFFF5E5D1),
        height: 85,
        notchMargin: 8.0,
        elevation: 3.0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildNavItem(
                    iconPath: 'assets/icons/explore.png',
                    label: 'Explore',
                    onPressed: () {
                      Navigator.pushNamed(context, "/homescreen");
                    },
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/icons/favs.png',
                    label: 'FAVs',
                    onPressed: () {
                      Navigator.pushNamed(context, "/favs");
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNavItem(
                    iconPath: 'assets/icons/agenda.png',
                    label: 'Agenda',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/icons/profile.png',
                    label: 'Profile',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSectionTitle(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  void showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameCtl,
                  decoration: const InputDecoration(labelText: "First Name"),
                ),
                TextField(
                  controller: lastNameCtl,
                  decoration: const InputDecoration(labelText: "Last Name"),
                ),
                TextField(
                  controller: usernameCtl,
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                TextField(
                  controller: emailCtl,
                  decoration: const InputDecoration(labelText: "Email"),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await updateProfile();
                    loadProfile();
                  },
                  child: const Text("Save"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required String iconPath,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 40,
            alignment: Alignment.center,
            decoration: label == 'Profile'
                ? BoxDecoration(
                    color: const Color(0xFFE9DDC9),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Image.asset(
              iconPath,
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F1F1F),
              fontSize: 14.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
