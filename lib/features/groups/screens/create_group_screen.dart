import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import 'group_detail_screen.dart';

/// Screen to create a new group with name, description, and initial member emails
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<String> _inviteEmails = [];
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Create Group',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.lg),
          children: [
            // Group Name
            _buildLabel('Group Name'),
            const SizedBox(height: AppTokens.sm),
            TextFormField(
              controller: _nameController,
              style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
              decoration: _inputDecoration(
                hint: 'e.g., Goa Trip 2026',
                icon: Icons.group_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a group name' : null,
            ),

            const SizedBox(height: AppTokens.lg),

            // Description
            _buildLabel('Description (optional)'),
            const SizedBox(height: AppTokens.sm),
            TextFormField(
              controller: _descController,
              style: GoogleFonts.outfit(color: AppColors.text, fontSize: 15),
              maxLines: 3,
              decoration: _inputDecoration(
                hint: 'What is this group for?',
                icon: Icons.description_rounded,
              ),
            ),

            const SizedBox(height: AppTokens.lg),

            // Invite Members
            _buildLabel('Invite Members by Email'),
            const SizedBox(height: AppTokens.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.outfit(
                        color: AppColors.text, fontSize: 15),
                    decoration: _inputDecoration(
                      hint: 'friend@email.com',
                      icon: Icons.person_add_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.sm),
                GestureDetector(
                  onTap: _addEmail,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            // Email chips
            if (_inviteEmails.isNotEmpty) ...[
              const SizedBox(height: AppTokens.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _inviteEmails.map((email) {
                  return Chip(
                    label: Text(
                      email,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.brand,
                      ),
                    ),
                    backgroundColor: AppColors.brandSoft,
                    deleteIcon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                    onDeleted: () {
                      setState(() => _inviteEmails.remove(email));
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                      side: BorderSide(
                        color: AppColors.brand.withOpacity(0.2),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: AppTokens.xxl),

            // Create Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  elevation: 0,
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create Group',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSoft,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }

  void _addEmail() {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    if (!RegExp(r'^[\w\.\-\+]+@[\w\.\-]+\.\w{2,}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid email format',
              style: GoogleFonts.outfit()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_inviteEmails.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email already added',
              style: GoogleFonts.outfit()),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _inviteEmails.add(email);
      _emailController.clear();
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final provider = context.read<GroupProvider>();
    final group = await provider.createGroup(
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
    );

    if (group != null && mounted) {
      // Send invitations to all emails
      for (final email in _inviteEmails) {
        await provider.addMember(group.id, email);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(groupId: group.id),
          ),
        );
      }
    } else if (mounted) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Failed to create group',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
