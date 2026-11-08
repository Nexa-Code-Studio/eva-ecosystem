import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/features/auth/domain/entities/emergency_contact_entity.dart';
import 'package:eva_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_mobile/features/emergency/presentation/widgets/contact_form_dialog.dart';
import 'package:eva_mobile/features/emergency/presentation/widgets/emergency_contacts_skeleton_loader.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/widgets/staggered_entrance.dart';

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends ConsumerState<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.showSuccess(
      context,
      '$label ($text) berhasil disalin ke clipboard',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await ref.read(authRepositoryProvider).getEmergencyContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts.map<Map<String, dynamic>>((c) => {
            'id': c.id,
            'name': c.name,
            'relation': c.relationship.isEmpty ? 'Kontak Darurat' : c.relationship,
            'phone': c.phone,
            'isPrimary': c.isPrimary,
          }).toList();
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveContactToBackend({
    required String name,
    required String relation,
    required String phone,
    required bool isPrimary,
    Map<String, dynamic>? contactToEdit,
  }) async {
    setState(() {
      if (isPrimary) {
        for (var c in _contacts) {
          c['isPrimary'] = false;
        }
      }
      if (contactToEdit != null) {
        contactToEdit['name'] = name;
        contactToEdit['relation'] = relation;
        contactToEdit['phone'] = phone;
        contactToEdit['isPrimary'] = isPrimary;
      } else {
        _contacts.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': name,
          'relation': relation.isEmpty ? 'Kontak Darurat' : relation,
          'phone': phone,
          'isPrimary': isPrimary || _contacts.isEmpty,
        });
      }
    });

    try {
      await ref.read(authRepositoryProvider).addEmergencyContact(
        EmergencyContactEntity(
          id: contactToEdit != null ? (contactToEdit['id']?.toString() ?? '') : '',
          name: name,
          relationship: relation.isEmpty ? 'Keluarga' : relation,
          phone: phone,
          isPrimary: isPrimary,
        ),
      );
      _loadContacts();
    } catch (_) {}
  }

  Future<void> _deleteContactFromBackend(Map<String, dynamic> contact) async {
    final contactId = contact['id']?.toString();
    setState(() {
      _contacts.removeWhere((c) => c['id'] == contact['id']);
      if (contact['isPrimary'] == true && _contacts.isNotEmpty) {
        _contacts.first['isPrimary'] = true;
      }
    });

    if (contactId != null && contactId.isNotEmpty) {
      try {
        await ref.read(authRepositoryProvider).deleteEmergencyContact(contactId);
      } catch (_) {}
    }
  }



  void _showContactFormDialog({Map<String, dynamic>? contactToEdit}) {
    ContactFormDialog.show(
      context: context,
      contactToEdit: contactToEdit,
      onSave: ({
        required String name,
        required String relation,
        required String phone,
        required bool isPrimary,
        Map<String, dynamic>? contactToEdit,
      }) {
        _saveContactToBackend(
          name: name,
          relation: relation,
          phone: phone,
          isPrimary: isPrimary,
          contactToEdit: contactToEdit,
        );
      },
    );
  }

  void _confirmDeleteContact(Map<String, dynamic> contact) {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

          title: Text(

            'Hapus Kontak Darurat?',

            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),

          ),

          content: Text(

            'Apakah Anda yakin ingin menghapus "${contact['name']}" dari daftar kontak darurat?',

            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(context),

              child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary)),

            ),

            ElevatedButton(

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFFD32F2F),

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),

              ),

              onPressed: () {
                _deleteContactFromBackend(contact);
                Navigator.pop(context);
                AppSnackBar.showWarning(
                  context,
                  'Kontak "${contact['name']}" telah dihapus.',
                );
              },

              child: Text(

                'Hapus',

                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),

              ),

            ),

          ],

        );

      },

    );

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        width: double.infinity,

        height: double.infinity,

        decoration: const BoxDecoration(

          gradient: LinearGradient(

            colors: [

              Color(0xFFF6F8FF),

              Color(0xFFEFF2FE),

              Color(0xFFF8F9FE),

            ],

            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,

          ),

        ),

        child: SafeArea(

          child: Column(

            children: [

              // Header Bar with Back Button Only (Cleaned App Bar)
              StaggeredEntrance(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      const AppBackButton(),
                      const SizedBox(width: 12),
                      Text(
                        'Kontak Darurat Krisis',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEBECEF)),



              // Scrollable Content

              Expanded(

                child: SingleChildScrollView(

                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      // Info Banner Card
                      StaggeredEntrance(
                        index: 1,
                        child: GlassCard(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFDCDD),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  color: Color(0xFFD32F2F),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RENCANA KESELAMATAN KRISIS',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textLight,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kontak ini siap dihubungi secara instan saat sistem EVA mendeteksi indikasi krisis emosional tinggi.',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // List Header Title (Cleaned header without duplicate button)
                      StaggeredEntrance(
                        index: 2,
                        child: Text(
                          'DAFTAR KONTAK (${_contacts.length})',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),



                      // Contacts List Items
                      StaggeredEntrance(
                        index: 3,
                        child: _isLoading
                            ? const EmergencyContactsSkeletonLoader()
                            : _contacts.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.contacts_outlined, size: 48, color: AppColors.textLight),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Belum ada kontak darurat',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _contacts.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final contact = _contacts[index];
                                      final bool isPrimary = contact['isPrimary'] == true;
                                      return GlassCard(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: isPrimary ? const Color(0xFFFFDCDD) : AppColors.primaryContainer,
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Icon(
                                                    isPrimary ? Icons.star_rounded : Icons.person_outline,
                                                    color: isPrimary ? const Color(0xFFD32F2F) : AppColors.primary,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              contact['name'] ?? '',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.textPrimary,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (isPrimary) ...[
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFFEBEE),
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: Border.all(color: const Color(0xFFFFCDD2)),
                                                              ),
                                                              child: Text(
                                                                'UTAMA',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: const Color(0xFFD32F2F),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        contact['relationship'] ?? '',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            const Divider(height: 1, color: Color(0xFFF0F1F5)),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () => _copyToClipboard(contact['phone'] ?? '', 'Nomor Telepon'),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                                                          const SizedBox(width: 8),
                                                          Flexible(
                                                            child: Text(
                                                              contact['phone'] ?? '',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.w600,
                                                                color: AppColors.textPrimary,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                                  color: AppColors.primary,
                                                  onPressed: () => _showContactFormDialog(contactToEdit: contact),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 20),
                                                  color: const Color(0xFFD32F2F),
                                                  onPressed: () => _confirmDeleteContact(contact),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),

                      const SizedBox(height: 28),

                      // Official Emergency & Counseling Hotlines Section
                      StaggeredEntrance(
                        index: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4DCFF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.support_agent,
                                    size: 16,
                                    color: Color(0xFF6C5CE7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hotline Resmi 24 Jam',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildOfficialHotlineCard(
                              title: 'Layanan SEJIWA (Kemenkes & BNPB)',
                              desc: 'Konseling psikologis gratis dari pemerintah RI',
                              number: '119',
                              displayNumber: '119 (Ekstensi 8)',
                              icon: Icons.local_hospital_outlined,
                              accentColor: const Color(0xFF6C5CE7),
                              badgeBg: const Color(0xFFF3F0FF),
                            ),
                            const SizedBox(height: 10),
                            _buildOfficialHotlineCard(
                              title: 'LISA - Sahabat Jiwa',
                              desc: 'Hotline pencegahan krisis & WhatsApp 24 Jam',
                              number: '08113855472',
                              displayNumber: '0811-3855-472',
                              icon: Icons.phone_in_talk_outlined,
                              accentColor: const Color(0xFF00CEC9),
                              badgeBg: const Color(0xFFD7F3FF),
                            ),
                            const SizedBox(height: 10),
                            _buildOfficialHotlineCard(
                              title: 'Nomor Darurat Nasional Terpadu',
                              desc: 'Panggilan darurat nasional bebas pulsa (Polisi/Damkar/Medis)',
                              number: '112',
                              displayNumber: '112',
                              icon: Icons.emergency_outlined,
                              accentColor: const Color(0xFFD32F2F),
                              badgeBg: const Color(0xFFFFDCDD),
                            ),
                            const SizedBox(height: 10),
                            _buildOfficialHotlineCard(
                              title: 'Halo Kemenkes',
                              desc: 'Informasi fasilitas kesehatan & layanan rujukan',
                              number: '1500567',
                              displayNumber: '1500-567',
                              icon: Icons.info_outline,
                              accentColor: const Color(0xFF0984E3),
                              badgeBg: const Color(0xFFDFE6E9),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),

                    ],

                  ),

                ),

              ),

            ],

          ),

        ),

      ),
      // Single Efficient Floating Action Button (FAB)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactFormDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah Kontak',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildOfficialHotlineCard({
    required String title,
    required String desc,
    required String number,
    required String displayNumber,
    required IconData icon,
    required Color accentColor,
    required Color badgeBg,
  }) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayNumber,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
            tooltip: 'Salin nomor',
            onPressed: () => _copyToClipboard(number, title),
          ),
        ],
      ),
    );
  }
}

