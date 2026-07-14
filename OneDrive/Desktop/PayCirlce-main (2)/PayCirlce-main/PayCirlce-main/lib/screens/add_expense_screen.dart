import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../providers/group_provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/member_service.dart';
import '../utils/helpers.dart';
import '../widgets/main_bottom_nav.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _selectedTag;
  final Set<String> _selectedParticipants = <String>{};

  // High-End Premium Editorial Color Palette
  static const Color primaryPurple = Color(0xFF320B7B);
  static const Color accentPurple = Color(0xFF673AB7);
  static const Color deepCanvasBg = Color(0xFFF3F2F8);
  static const Color subtleGray = Color(0xFF8E8E93);

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _areAllSelected(Iterable<String> memberIds) {
    if (memberIds.isEmpty) return false;
    return memberIds.every(_selectedParticipants.contains);
  }

  void _toggleSelectAll(Iterable<String> memberIds, bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedParticipants.addAll(memberIds);
      } else {
        _selectedParticipants.clear();
      }
    });
  }

  Future<bool> _showPinDialog() async {
    final pinController = TextEditingController();
    try {
      final result =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              title: const Text(
                'Security PIN Verification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(
                    color: subtleGray,
                    letterSpacing: 16,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: deepCanvasBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: accentPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (result && pinController.text.isNotEmpty) {
        return await AuthService.verifyStoredPin(pinController.text);
      }
      return false;
    } finally {
      pinController.dispose();
    }
  }

  Future<void> _addExpense() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    final group = groupProvider.currentGroup;

    if (user == null || group == null) return;

    final pinVerified = await _showPinDialog();
    if (!pinVerified) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN verification failed')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final participants = {..._selectedParticipants, user.userId}.toList();

      final transaction = Transaction(
        txnId: Helpers.generateUserId(),
        amount: amount,
        paidBy: user.userId,
        participants: participants,
        timestamp: DateTime.now(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        tag: _selectedTag,
      );

      await FirebaseService.addTransaction(
        groupId: group.groupId,
        transaction: transaction,
      ).timeout(const Duration(seconds: 10));

      final share = amount / participants.length;
      for (final participant in participants) {
        final balanceChange = participant == user.userId
            ? (amount - share)
            : -share;
        await FirebaseService.updateBalance(
          groupId: group.groupId,
          userId: participant,
          amount: balanceChange,
        ).timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = context.watch<GroupProvider>().currentGroup;
    final user = context.watch<UserProvider>().currentUser;

    if (group == null || user == null) {
      return const Scaffold(body: Center(child: Text('Data Context Missing.')));
    }

    return Scaffold(
      backgroundColor: deepCanvasBg,
      bottomNavigationBar: const MainBottomNav(currentIndex: 2),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Premium Blended Header Navigation Bar
            SliverAppBar(
              pinned: true,
              expandedHeight: 90,
              backgroundColor: primaryPurple,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.history_toggle_off,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => setState(() {}),
                ),
              ],
              flexibleSpace: const FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(bottom: 14),
                centerTitle: true,
                title: Text(
                  'Add Expense',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            // Main UI Layout Elements Container
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Context Card (Shows current Context / Group metadata)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryPurple, accentPurple],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              group.groupName.substring(0, 2).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.groupName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Paid by You',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtleGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Beautiful Transaction Input Card Panel
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ENTER AMOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: subtleGray,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Expensive Display Style Entry Field
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: primaryPurple,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    letterSpacing: -1,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFE5E5EA),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (v) =>
                                      (v == null ||
                                          double.tryParse(v) == null ||
                                          double.parse(v) <= 0)
                                      ? 'Invalid amount entry'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, thickness: 1.2),

                          // Textual Memo Row
                          TextFormField(
                            controller: _descriptionController,
                            maxLength: 100,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              icon: Icon(
                                Icons.notes,
                                color: primaryPurple,
                                size: 20,
                              ),
                              hintText: 'What was this expense for?',
                              hintStyle: TextStyle(
                                color: subtleGray,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Modern Interactive Participant Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: StreamBuilder<List<User>>(
                        stream: MemberService.streamGroupMembers(group.groupId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: primaryPurple,
                                ),
                              ),
                            );
                          }

                          final members = snapshot.data!;
                          final memberIds = members
                              .map((m) => m.userId)
                              .toSet();
                          final allSelected = _areAllSelected(memberIds);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'SPLIT BETWEEN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: subtleGray,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                      ),
                                      icon: Icon(
                                        allSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: accentPurple,
                                        size: 16,
                                      ),
                                      label: Text(
                                        allSelected
                                            ? 'Deselect All'
                                            : 'Select All',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: accentPurple,
                                        ),
                                      ),
                                      onPressed: () => _toggleSelectAll(
                                        memberIds,
                                        !allSelected,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(bottom: 12),
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: members.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  indent: 24,
                                  endIndent: 24,
                                ),
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final isMe = member.userId == user.userId;
                                  final isSelected = _selectedParticipants
                                      .contains(member.userId);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedParticipants.remove(
                                            member.userId,
                                          );
                                        } else {
                                          _selectedParticipants.add(
                                            member.userId,
                                          );
                                        }
                                      });
                                    },
                                    child: _ParticipantTile(
                                      member: member,
                                      isMe: isMe,
                                      isSelected: isSelected,
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Continuous Floating Primary CTA Action Button
                    Container(
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [primaryPurple, accentPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _isLoading ? null : _addExpense,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Publish Expense',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Highly stylized customized selection line tile component
class _ParticipantTile extends StatelessWidget {
  final User member;
  final bool isMe;
  final bool isSelected;

  const _ParticipantTile({
    required this.member,
    required this.isMe,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5E5EA),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${member.name} (You)' : member.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (member.isGroupAdmin) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE65100),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Premium Designed Check Ring indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 22,
            width: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF320B7B) : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF320B7B)
                    : const Color(0xFFD1D1D6),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ],
      ),
    );
  }
}
