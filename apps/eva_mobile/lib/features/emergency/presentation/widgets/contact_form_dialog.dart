import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_snack_bar.dart';

/// Modal dialog for adding or editing emergency contacts.
class ContactFormDialog extends StatefulWidget {
  final Map<String, dynamic>? contactToEdit;
  final void Function({
    required String name,
    required String relation,
    required String phone,
    required bool isPrimary,
    Map<String, dynamic>? contactToEdit,
  }) onSave;

  const ContactFormDialog({
    super.key,
    this.contactToEdit,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    Map<String, dynamic>? contactToEdit,
    required void Function({
      required String name,
      required String relation,
      required String phone,
      required bool isPrimary,
      Map<String, dynamic>? contactToEdit,
    }) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ContactFormDialog(
        contactToEdit: contactToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<ContactFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationController;
  late final TextEditingController _phoneController;
  late bool _isPrimary;

  bool get _isEditing => widget.contactToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _isEditing ? (widget.contactToEdit!['name'] ?? '') : '',
    );
    _relationController = TextEditingController(
      text: _isEditing ? (widget.contactToEdit!['relation'] ?? '') : '',
    );
    _phoneController = TextEditingController(
      text: _isEditing ? (widget.contactToEdit!['phone'] ?? '') : '',
    );
    _isPrimary = _isEditing ? (widget.contactToEdit!['isPrimary'] ?? false) : false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isEditing
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : const Color(0xFFFFDCDD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_note_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: _isEditing
                          ? AppColors.primary
                          : const Color(0xFFD32F2F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? 'Edit Kontak Darurat'
                              : 'Tambah Kontak Baru',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Orang terpercaya untuk situasi darurat',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textLight,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Input 1: Nama Lengkap
              _buildFormFieldLabel(
                icon: Icons.badge_outlined,
                label: 'NAMA LENGKAP',
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: _buildInputDecoration(
                  hint: 'Misal: Ayah, Ibu, Sahabat',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 14),

              // Input 2: Hubungan / Peran
              _buildFormFieldLabel(
                icon: Icons.group_outlined,
                label: 'HUBUNGAN / PERAN',
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _relationController,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: _buildInputDecoration(
                  hint: 'Misal: Ibu Kandung, Sahabat Kantor',
                  prefixIcon: Icons.diversity_1_outlined,
                ),
              ),
              const SizedBox(height: 14),

              // Input 3: Nomor Telepon
              _buildFormFieldLabel(
                icon: Icons.call_outlined,
                label: 'NOMOR TELEPON / WHATSAPP',
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: _buildInputDecoration(
                  hint: '0812-XXXX-XXXX',
                  prefixIcon: Icons.phone_android_rounded,
                ),
              ),
              const SizedBox(height: 16),

              // Switch: Kontak Utama
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isPrimary
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isPrimary
                        ? const Color(0xFF86EFAC).withValues(alpha: 0.6)
                        : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isPrimary
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: _isPrimary
                            ? const Color(0xFF047857)
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jadikan Kontak Utama',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Prioritas panggilan darurat pertama',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isPrimary,
                      activeThumbColor: const Color(0xFF10B981),
                      activeTrackColor: const Color(0xFFD1FAE5),
                      onChanged: (val) {
                        setState(() {
                          _isPrimary = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: Icon(
                        _isEditing
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _isEditing ? 'Simpan Perubahan' : 'Tambah Kontak',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        final name = _nameController.text.trim();
                        final relation = _relationController.text.trim();
                        final phone = _phoneController.text.trim();

                        if (name.isEmpty || phone.isEmpty) {
                          AppSnackBar.showWarning(
                            context,
                            'Nama dan nomor telepon wajib diisi',
                            duration: const Duration(seconds: 2),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        widget.onSave(
                          name: name,
                          relation: relation,
                          phone: phone,
                          isPrimary: _isPrimary,
                          contactToEdit: _isEditing ? widget.contactToEdit : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFieldLabel({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 13,
        color: AppColors.textLight,
      ),
      prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textSecondary),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
