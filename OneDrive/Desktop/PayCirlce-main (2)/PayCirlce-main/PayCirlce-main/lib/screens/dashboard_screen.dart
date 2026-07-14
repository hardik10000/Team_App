import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/group_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../models/transaction_model.dart';
import '../services/member_service.dart';
import '../widgets/main_bottom_nav.dart';
import 'member_profile_screen.dart';
import '../widgets/app_logo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<User>>? _membersFuture;
  String? _listeningGroupId;

  Future<void> _openAdminGroupSettings({
    required List<User> members,
    required String adminId,
  }) async {
    final groupProvider = context.read<GroupProvider>();
    final group = groupProvider.currentGroup;
    final user = context.read<UserProvider>().currentUser;
    if (group == null || user == null || user.userId != adminId) {
      return;
    }

    final groupNameController = TextEditingController(text: group.groupName);
    final tagsController = TextEditingController(text: group.tags.join(', '));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final removableMembers = members
                .where((m) => m.userId != adminId)
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        hintText: 'Food, Travel, Rent',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Remove Members',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (removableMembers.isEmpty)
                      const Text(
                        'No removable members',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ...removableMembers.map(
                        (member) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(member.name),
                          subtitle: Text(
                            member.email.isEmpty ? '-' : member.email,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove_outlined),
                            color: Colors.red,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Member'),
                                  content: Text(
                                    'Remove ${member.name} from this group?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm != true) return;
                              final ok = await groupProvider.removeMember(
                                member.userId,
                              );
                              if (!context.mounted) return;
                              if (ok) {
                                setSheetState(() {});
                                setState(() {
                                  _membersFuture =
                                      MemberService.getGroupMembers(
                                        group.groupId,
                                      );
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${member.name} removed'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      groupProvider.error ??
                                          'Unable to remove member',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final groupName = groupNameController.text.trim();
                          if (groupName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Group name is required'),
                              ),
                            );
                            return;
                          }

                          final tags = tagsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toSet()
                              .toList();

                          final ok = await groupProvider.updateGroupSettings(
                            groupName: groupName,
                            tags: tags,
                          );

                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Group updated')),
                            );
                            await _refreshDashboard();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  groupProvider.error ??
                                      'Unable to update group',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Group Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        _refreshDashboard();
      }
    });

    groupNameController.dispose();
    tagsController.dispose();
  }

  Future<void> _refreshDashboard() async {
    final groupProvider = context.read<GroupProvider>();
    await groupProvider.loadStoredGroup();
    final group = groupProvider.currentGroup;
    if (group != null) {
      _membersFuture = MemberService.getGroupMembers(group.groupId);
      // ignore: use_build_context_synchronously
      context.read<TransactionProvider>().startListening(group.groupId);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Map<String, double> _computeBalances({
    required List<Transaction> transactions,
    required Iterable<String> memberIds,
  }) {
    final balances = <String, double>{for (final id in memberIds) id: 0};

    for (final txn in transactions) {
      if (txn.deleted || txn.participants.isEmpty) {
        continue;
      }
      final share = txn.amount / txn.participants.length;
      balances[txn.paidBy] = (balances[txn.paidBy] ?? 0) + (txn.amount - share);

      for (final participant in txn.participants) {
        if (participant == txn.paidBy) {
          continue;
        }
        balances[participant] = (balances[participant] ?? 0) - share;
      }
    }

    return balances;
  }

  ImageProvider? _getProfileImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    if (!photoUrl.startsWith('http')) {
      try {
        final imageBytes = base64Decode(photoUrl);
        return MemoryImage(imageBytes);
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(photoUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = context.read<GroupProvider>().currentGroup;
    if (group != null && _listeningGroupId != group.groupId) {
      _listeningGroupId = group.groupId;
      _membersFuture = MemberService.getGroupMembers(group.groupId);
      context.read<TransactionProvider>().startListening(group.groupId);
    }
  }

  @override
  void dispose() {
    context.read<TransactionProvider>().stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final group = context.watch<GroupProvider>().currentGroup;
    final transactions = context.watch<TransactionProvider>().transactions;
    final balances = group == null
        ? <String, double>{}
        : _computeBalances(
            transactions: transactions,
            memberIds: group.members,
          );

    // Deep purple base colors aligned to UI image
    const primaryPurple = Color(0xFF673AB7);
    const deepBgPurple = Color(0xFF512DA8);

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FE,
      ), // Modern light off-white background
      appBar: AppBar(
        backgroundColor: deepBgPurple,
        elevation: 0,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: AppLogo(size: 38),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Welcome back, ${user?.name.split(' ').first ?? 'User'}!',
                  style: TextStyle(
                    fontSize: 13,
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshDashboard,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top overlapping banner color simulation
            Container(
              height: 20,
              decoration: const BoxDecoration(
                color: deepBgPurple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. User profile group card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.purple.withOpacity(0.04),
                            spreadRadius: 4,
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.deepPurple.shade50,
                              child: Text(
                                user?.name.substring(0, 2).toUpperCase() ??
                                    'RS',
                                style: const TextStyle(
                                  color: primaryPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Hi ${user?.name ?? 'Sarvaiya Rutvik'}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1A1B2D),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '👋',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      _buildGroupMetaDataItem(
                                        Icons.group_outlined,
                                        'Group: ${group?.groupName ?? 'Friends'}',
                                      ),
                                      _buildGroupMetaDataItem(
                                        Icons.qr_code_scanner,
                                        'Code: ${group?.groupCode ?? 'CJTFC3'}',
                                      ),
                                      _buildGroupMetaDataItem(
                                        Icons.people_outline,
                                        'Members: ${group?.members.length ?? 2}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EFFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.swap_horiz,
                                  color: primaryPurple,
                                ),
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/join-group');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Purple Gradient Dice Banner ("Random Payer")
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3F1EBE),
                            Color(0xFF9B51E0),
                            Color(0xFFE040FB),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: const Color(0xFF3F1EBE).withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () =>
                              Navigator.of(context).pushNamed(routeRandomPayer),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 22,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    // ignore: deprecated_member_use
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.casino_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Random Payer',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Spin the wheel and let luck decide!',
                                        style: TextStyle(
                                          color: Color(0xFFE5D5FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: primaryPurple,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Member Balances Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.02),
                            spreadRadius: 2,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Member Balances',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1B2D),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'See who owes and who gets',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              if (group != null &&
                                  user?.userId == group.adminId)
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Manage group',
                                    onPressed: () => _openAdminGroupSettings(
                                      members: group.members
                                          .map(
                                            (id) => User(
                                              userId: id,
                                              name: 'User $id',
                                              email: '',
                                              photoUrl: '',
                                              pinHash: '',
                                              createdAt: DateTime.now(),
                                            ),
                                          )
                                          .toList(), // Mock conversion or replace with snapshot array if parsed from backend
                                      adminId: group.adminId,
                                    ),
                                    icon: const Icon(
                                      Icons.settings_outlined,
                                      color: primaryPurple,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Dynamic conditional builder mapped from Future snapshot
                          if (group != null)
                            FutureBuilder<List<User>>(
                              future: _membersFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    _membersFuture != null) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(
                                        color: primaryPurple,
                                      ),
                                    ),
                                  );
                                }
                                final members = snapshot.data ?? [];
                                if (members.isEmpty) {
                                  // Fallback dummy styling to replicate visual snapshot perfectly
                                  return Column(
                                    children: [
                                      _buildBalanceTile(
                                        name: 'Rutvik sarvaiya',
                                        balance: 25.00,
                                        isYou: true,
                                        isAdmin: false,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildBalanceTile(
                                        name: 'Sarvaiya Rutvik',
                                        balance: -25.00,
                                        isYou: true,
                                        isAdmin: true,
                                      ),
                                    ],
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: members.length,
                                  // ignore: non_constant_identifier_names
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final member = members[index];
                                    final balance =
                                        balances[member.userId] ?? 0.0;
                                    final isCurrentUser =
                                        user?.userId == member.userId;
                                    final isAdmin =
                                        group.adminId == member.userId;

                                    return InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => MemberProfileScreen(
                                              member: member,
                                              balance: balance,
                                              groupName: group.groupName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: _buildBalanceTile(
                                        name: member.name,
                                        balance: balance,
                                        isYou: isCurrentUser,
                                        isAdmin: isAdmin,
                                        photoUrl: member.photoUrl,
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          else
                            const Center(child: Text('No active group data.')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Bottom Grid Analytics Container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAnalyticsStat(
                            Icons.group_outlined,
                            '${group?.members.length ?? 2}',
                            'Members',
                            const Color(0xFF673AB7),
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade200,
                          ),
                          _buildAnalyticsStat(
                            Icons.account_balance_wallet_outlined,
                            '₹${transactions.isEmpty ? "0.00" : "Calculated"}',
                            'Total Settled',
                            Colors.green,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade200,
                          ),
                          _buildAnalyticsStat(
                            Icons.swap_horiz,
                            '${transactions.length}',
                            'Transactions',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 80,
                    ), // extra padding space for FAB layout clearance
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(routeAddExpense),
        backgroundColor: primaryPurple,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 0),
    );
  }

  // Component Helper widget for inline text meta-data tags
  Widget _buildGroupMetaDataItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Component Helper widget for Modern Member Balance Item rows matching target layout
  Widget _buildBalanceTile({
    required String name,
    required double balance,
    required bool isYou,
    required bool isAdmin,
    String? photoUrl,
  }) {
    final isReceivable = balance >= 0;
    final displayColor = isReceivable
        ? const Color(0xFF2E7D32)
        : const Color(0xFFD32F2F);
    final bgColor = isReceivable
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);
    final statusIcon = isReceivable
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            // ignore: deprecated_member_use
            backgroundColor: const Color(0xFF673AB7).withOpacity(0.1),
            backgroundImage: _getProfileImage(photoUrl),
            child: photoUrl == null
                ? const Icon(Icons.person, color: Color(0xFF673AB7))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1B2D),
                  ),
                ),
                const SizedBox(width: 6),
                if (isYou)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F6EA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Color(0xFF27AE60),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isAdmin) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: displayColor, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${balance.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: displayColor,
                    ),
                  ),
                  Text(
                    isReceivable ? 'to receive' : 'to pay',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Component Helper widget for Bottom Metrics Row
  Widget _buildAnalyticsStat(
    IconData icon,
    String val,
    String title,
    Color itemColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: itemColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: itemColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          val,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1B2D),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
