import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_config.dart';
import '../constants/app_constants.dart';
import '../models/group_model.dart';
import '../providers/group_provider.dart';
import '../providers/user_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_logo.dart';
import '../widgets/main_bottom_nav.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _joinFormKey = GlobalKey<FormState>();
  final _createFormKey = GlobalKey<FormState>();
  final _groupCodeController = TextEditingController();
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupCodeController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  /// Fetch groups where user is member
  Future<List<Group>> _getUserMemberGroups() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return [];

    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db
          .collection('groups')
          .where('members', arrayContains: user.userId)
          .get();

      return snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch groups where user is admin
  Future<List<Group>> _getUserAdminGroups() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return [];

    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db
          .collection('groups')
          .where('adminId', isEqualTo: user.userId)
          .get();

      return snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Switch to a different group
  Future<void> _switchToGroup(Group group) async {
    try {
      final provider = context.read<GroupProvider>();
      await provider.setCurrentGroup(group);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(routeDashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error switching group: $e')));
      }
    }
  }

  Future<void> _joinGroup() async {
    if (!(_joinFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      return;
    }
    final provider = context.read<GroupProvider>();
    final ok = await provider.joinGroup(
      groupCode: _groupCodeController.text.trim().toUpperCase(),
      user: user,
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      Navigator.of(context).pushReplacementNamed(routeDashboard);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.error ?? 'Unable to join group.')),
    );
  }

  Future<void> _createGroup() async {
    if (!(_createFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      return;
    }

    final provider = context.read<GroupProvider>();
    final ok = await provider.createGroup(
      groupName: _groupNameController.text.trim(),
      user: user,
    );

    if (!mounted) {
      return;
    }

    if (ok) {
      Navigator.of(context).pushReplacementNamed(routeDashboard);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.error ?? 'Unable to create group.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<GroupProvider>().isLoading;

    const primaryPurple = Color(0xFF673AB7);
    const deepBgPurple = Color(0xFF512DA8);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      bottomNavigationBar: const MainBottomNav(currentIndex: 1),
      appBar: AppBar(
        backgroundColor: deepBgPurple,
        elevation: 0,
        toolbarHeight: 70,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: AppLogo(size: 36),
        ),
        title: const Text(
          'Manage Groups',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() {});
            },
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pushReplacementNamed(routeDashboard);
        },
        child: DefaultTabController(
          length: 2,
        child: Column(
          children: [
            // Top Accent Tab Header Bar
            Container(
              color: deepBgPurple,
              child: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(
                    text: 'Join Existing',
                    icon: Icon(Icons.group_add_outlined, size: 20),
                  ),
                  Tab(
                    text: 'Create New',
                    icon: Icon(Icons.add_box_outlined, size: 20),
                  ),
                ],
              ),
            ),

            // Configuration / Warning Strip
            if (!FirebaseConfig.isReady)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.orange.shade50,
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Platform configuration missing. Setup FlutterFire to continue.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: TabBarView(
                children: [
                  // --- JOIN TAB ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Form(
                        key: _joinFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _buildInputCard(
                              title: 'Enter Group Code',
                              subtitle:
                                  'Ask your friends for the 6-character room code.',
                              child: TextFormField(
                                controller: _groupCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 6,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.vpn_key_outlined,
                                    color: primaryPurple,
                                  ),
                                  labelText: 'Group Code',
                                  hintText: 'ABC123',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  counterText: '',
                                ),
                                validator: Validators.validateGroupCode,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              onPressed: isLoading ? null : _joinGroup,
                              label: isLoading
                                  ? 'Joining...'
                                  : 'Join Group Workspace',
                              icon: Icons.login_rounded,
                              backgroundColor: primaryPurple,
                            ),
                            const SizedBox(height: 28),
                            _buildSectionHeader('Subscribed Workspaces'),
                            const SizedBox(height: 8),
                            FutureBuilder<List<Group>>(
                              future: _getUserMemberGroups(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: CircularProgressIndicator(
                                        color: primaryPurple,
                                      ),
                                    ),
                                  );
                                }

                                final groups = snapshot.data ?? [];
                                if (groups.isEmpty) {
                                  return _buildEmptyState(
                                    'No workspaces linked yet. Enter a valid code above!',
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: groups.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final group = groups[index];
                                    return _buildGroupRowTile(
                                      group: group,
                                      badgeText: 'Member',
                                      badgeColor: const Color(0xFFE2F6EA),
                                      textColor: const Color(0xFF27AE60),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- CREATE TAB ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Form(
                        key: _createFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _buildInputCard(
                              title: 'Workspace Identity',
                              subtitle:
                                  'Create a hub name for tracking expenses clearly.',
                              child: TextFormField(
                                controller: _groupNameController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.edit_note_outlined,
                                    color: primaryPurple,
                                  ),
                                  labelText: 'Group Name',
                                  hintText: 'e.g., Goa Trip 2026',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: Validators.validateGroupName,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              onPressed: isLoading ? null : _createGroup,
                              label: isLoading
                                  ? 'Creating...'
                                  : 'Initialize Workspace',
                              icon: Icons.add_moderator_outlined,
                              backgroundColor: const Color(0xFFE040FB),
                            ),
                            const SizedBox(height: 28),
                            _buildSectionHeader('Managed Environments'),
                            const SizedBox(height: 8),
                            FutureBuilder<List<Group>>(
                              future: _getUserAdminGroups(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: CircularProgressIndicator(
                                        color: primaryPurple,
                                      ),
                                    ),
                                  );
                                }

                                final groups = snapshot.data ?? [];
                                if (groups.isEmpty) {
                                  return _buildEmptyState(
                                    "You haven't initialized an admin workspace room yet.",
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: groups.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final group = groups[index];
                                    return _buildGroupRowTile(
                                      group: group,
                                      badgeText: 'Admin Owned',
                                      badgeColor: const Color(0xFFFFF3E0),
                                      textColor: Colors.orange.shade800,
                                      showCount: true,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
     ),
    );
  }

  // Visual Form Wrapper Layer Component
  Widget _buildInputCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            spreadRadius: 2,
            blurRadius: 16,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1B2D),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // Section Header Component
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A1B2D),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // Modern Button Action Block Component
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Color backgroundColor,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // Workspace Row Record Card matching balance tile profiles
  Widget _buildGroupRowTile({
    required Group group,
    required String badgeText,
    required Color badgeColor,
    required Color textColor,
    bool showCount = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _switchToGroup(group),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EFFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.maps_home_work_outlined,
                    color: Color(0xFF673AB7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            group.groupName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1B2D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${group.groupCode}${showCount ? " • Members: ${group.members.length}" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade300,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fallback Placeholder Empty State
  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F9).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
