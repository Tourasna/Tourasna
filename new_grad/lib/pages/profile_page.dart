import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/network_navigator.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);
  final Color cardColor = const Color(0xFFF7F1E6);
  String _selectedBudget = 'medium';
  String _selectedTravelType = 'solo';
  List<String> _selectedPreferences = [];
  static const List<String> _allPreferences = [
    'Ancient Monument',
    'Pharaonic Site',
    'Islamic Monument',
    'Coptic Site',
    'Museum',
    'Art Gallery',
    'Cultural Center',
    'Park / Garden',
    'Nature Reserve',
    'Zoo / Aquarium',
    'Bazaar / Souq',
    'Shopping Mall',
    'Gold & Jewelry Market',
    'Souvenir Shop',
    'Antiques',
    'Nile Cruise',
    'Nile View Restaurant',
    'Rooftop Restaurant',
    'Traditional Restaurant',
    'Activity',
    'Horse Riding',
    'Water & Amusement Parks',
    'Theme Park',
    'Escape Room',
    'Sport & Recreation',
    'Day Trip Site',
    'Landmark',
  ];
  bool loading = true;
  Map<String, dynamic>? data;

  // Accordion state
  final Map<String, bool> _expanded = {
    'basic': true,
    'account': false,
    'preferences': false,
  };

  // Edit controllers
  final firstNameCtl = TextEditingController();
  final lastNameCtl = TextEditingController();
  final usernameCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    firstNameCtl.dispose();
    lastNameCtl.dispose();
    usernameCtl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => loading = true);
    try {
      final res = await ApiClient.get('/api/profiles/me');
      if (res.statusCode == 200) {
        data = jsonDecode(res.body);
        _selectedBudget = data?['budget'] ?? 'medium';
        _selectedTravelType = data?['travel_type'] ?? 'solo';
        _selectedPreferences = List<String>.from(data?['preferences'] ?? []);
        firstNameCtl.text = data?['first_name'] ?? '';
        lastNameCtl.text = data?['last_name'] ?? '';
        usernameCtl.text = data?['username'] ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveAllChanges() async {
    setState(() => loading = true);
    try {
      // 1. Basic info + travel settings in one call
      await ApiClient.put(
        '/api/profiles/update',
        body: {
          'firstName': firstNameCtl.text.trim(),
          'lastName': lastNameCtl.text.trim(),
          'username': usernameCtl.text.trim(),
          'budget': _selectedBudget,
          'travelType': _selectedTravelType,
        },
      );

      // 2. Preferences
      await ApiClient.put(
        '/api/profiles/preferences',
        body: {'preferences': _selectedPreferences},
      );

      // 3. Reload once after both are done
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully'),
            backgroundColor: darkColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save changes'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  final _picker = ImagePicker();

  Future<void> _pickAndUploadAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() => loading = true);

    try {
      final token = await ApiClient.getToken();
      final uri = Uri.parse('${ApiClient.baseUrl}/api/profiles/avatar');

      // Determine mimetype from extension
      final ext = picked.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            picked.path,
            contentType: MediaType('image', mimeType.split('/').last),
          ),
        );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadProfile();
        // Force image cache clear
        final avatarUrl = data?['avatar_url'];
        if (avatarUrl != null) {
          imageCache.evict(NetworkImage(avatarUrl));
        }
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile photo updated'),
              backgroundColor: darkColor,
            ),
          );
        }
      } else {
        throw Exception('${response.statusCode}: $body');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => loading = false);
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE2D1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: goldColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Change Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar();
              },
            ),
            if (data?['avatar_url'] != null)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAvatar() async {
    setState(() => loading = true);
    try {
      final res = await ApiClient.delete('/api/profiles/avatar');
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _loadProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile photo removed'),
              backgroundColor: darkColor,
            ),
          );
        }
      } else {
        throw Exception('Failed: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  String _fullName() {
    final first = data?['first_name'] ?? '';
    final last = data?['last_name'] ?? '';
    return '$first $last'.trim();
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: goldColor)),
      );
    }

    final preferences = List<String>.from(data?['preferences'] ?? []);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: goldColor.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.chevron_left, color: darkColor),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'PROFILE',
                    style: TextStyle(
                      color: darkColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 42),
                ],
              ),
            ),

            // ── BODY ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  children: [
                    // AVATAR + NAME
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: goldColor, width: 2),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: darkColor.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: data?['avatar_url'] != null
                                ? Image.network(
                                    '${data!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.person,
                                      size: 48,
                                      color: darkColor.withOpacity(0.4),
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 48,
                                    color: darkColor.withOpacity(0.4),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showAvatarOptions(),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: darkColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: bgColor, width: 2),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: goldColor,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Personal Details',
                      style: TextStyle(
                        fontFamily: 'Gambetta',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'YOUR REGISTERED INFORMATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: goldColor,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // BASIC INFORMATION ACCORDION
                    _accordion(
                      key: 'basic',
                      title: 'Basic Information',
                      children: [
                        _infoRow(
                          Icons.person_outline,
                          'FULL NAME',
                          _fullName(),
                        ),
                        _infoRow(
                          Icons.email_outlined,
                          'EMAIL',
                          data?['email'] ?? '—',
                        ),
                        _infoRow(
                          Icons.badge_outlined,
                          'USERNAME',
                          data?['username'] ?? '—',
                        ),
                        _infoRow(
                          Icons.flag_outlined,
                          'NATIONALITY',
                          data?['nationality'] ?? '—',
                        ),
                        _infoRow(
                          Icons.cake_outlined,
                          'DATE OF BIRTH',
                          _formatDate(data?['date_of_birth']),
                        ),
                        _infoRow(
                          Icons.person_2_outlined,
                          'GENDER',
                          data?['gender'] ?? '—',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ACCOUNT & IDENTITY ACCORDION
                    _accordion(
                      key: 'account',
                      title: 'Account & Identity',
                      children: [
                        _infoRow(
                          Icons.wallet_outlined,
                          'BUDGET',
                          data?['budget'] ?? '—',
                        ),
                        _infoRow(
                          Icons.group_outlined,
                          'TRAVEL TYPE',
                          data?['travel_type'] ?? '—',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // PREFERENCES ACCORDION
                    _accordion(
                      key: 'preferences',
                      title: 'Travel Preferences',
                      children: [
                        if (preferences.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No preferences set',
                              style: TextStyle(
                                color: darkColor.withOpacity(0.4),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: preferences.map((p) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: darkColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    p,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: darkColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // LOGOUT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          'END SESSION',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── BOTTOM NAV ────────────────────────────
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        color: bgColor,
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
                    onPressed: () =>
                        navigateWithNetworkCheck(context, '/homescreen'),
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/icons/favs.png',
                    label: 'FAVs',
                    onPressed: () => navigateWithNetworkCheck(context, '/favs'),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNavItem(
                    iconPath: 'assets/icons/agenda.png',
                    label: 'Agenda',
                    onPressed: () =>
                        navigateWithNetworkCheck(context, '/agenda'),
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/images/Discovery-3.png',
                    label: 'Discovery',
                    onPressed: () =>
                        navigateWithNetworkCheck(context, '/discovery'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ACCORDION ──────────────────────────────────
  Widget _accordion({
    required String key,
    required String title,
    required List<Widget> children,
  }) {
    final isOpen = _expanded[key] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: goldColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: darkColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // HEADER
          GestureDetector(
            onTap: () => setState(() => _expanded[key] = !isOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: goldColor.withOpacity(0.06),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(24),
                  bottom: isOpen ? Radius.zero : const Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Gambetta',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                    ),
                  ),
                  Row(
                    children: [
                      if (isOpen && key != 'preferences')
                        GestureDetector(
                          onTap: () => _showEditSheet(),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: goldColor,
                            ),
                          ),
                        ),
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: goldColor,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // CONTENT
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(children: children),
            ),
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // ── INFO ROW ───────────────────────────────────
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAE2D1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: goldColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: goldColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EDIT SHEET ─────────────────────────────────
  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontFamily: 'Gambetta',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── BASIC INFO ──────────────────
                  _sheetSectionLabel('Basic Info'),
                  const SizedBox(height: 10),
                  _editField('First Name', firstNameCtl),
                  const SizedBox(height: 10),
                  _editField('Last Name', lastNameCtl),
                  const SizedBox(height: 10),
                  _editField('Username', usernameCtl),
                  const SizedBox(height: 10),

                  // Email read-only
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E1D3).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: darkColor.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: darkColor.withOpacity(0.4),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMAIL',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: darkColor.withOpacity(0.4),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data?['email'] ?? '—',
                              style: TextStyle(
                                fontSize: 13,
                                color: darkColor.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── TRAVEL SETTINGS ─────────────
                  _sheetSectionLabel('Travel Settings'),
                  const SizedBox(height: 10),

                  // Budget
                  Text(
                    'Budget',
                    style: TextStyle(
                      fontSize: 11,
                      color: darkColor.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['low', 'medium', 'high'].map((b) {
                      final isSelected = _selectedBudget == b;
                      return GestureDetector(
                        onTap: () => setSheetState(() => _selectedBudget = b),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? darkColor
                                : const Color(0xFFE9E1D3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            b.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? goldColor : darkColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Travel Type
                  Text(
                    'Travel Type',
                    style: TextStyle(
                      fontSize: 11,
                      color: darkColor.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['solo', 'family', 'group'].map((t) {
                      final isSelected = _selectedTravelType == t;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => _selectedTravelType = t),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? darkColor
                                : const Color(0xFFE9E1D3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            t.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? goldColor : darkColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── PREFERENCES ─────────────────
                  _sheetSectionLabel('Travel Preferences'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allPreferences.map((p) {
                      final isSelected = _selectedPreferences.contains(p);
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              _selectedPreferences.remove(p);
                            } else {
                              _selectedPreferences.add(p);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? darkColor
                                : const Color(0xFFE9E1D3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              color: isSelected ? goldColor : darkColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _saveAllChanges();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'SAVE ALL CHANGES',
                        style: TextStyle(
                          color: goldColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Gambetta',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: darkColor,
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E1D3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctl,
        style: TextStyle(color: darkColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: darkColor.withOpacity(0.5),
            fontSize: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ── NAV ITEM ───────────────────────────────────
  Widget _buildNavItem({
    required String iconPath,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 62,
            height: 40, // ← reduced from 46
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? darkColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              iconPath,
              width: 38, // ← reduced from 42
              height: 38,
              fit: BoxFit.contain,
              color: isActive ? Colors.white : null,
              colorBlendMode: isActive ? BlendMode.srcIn : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isActive ? darkColor : const Color(0xFF1F1F1F),
              fontSize: 11, // ← reduced from 12.5
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
