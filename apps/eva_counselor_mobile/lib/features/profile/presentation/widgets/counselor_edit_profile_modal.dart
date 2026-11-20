import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CounselorEditProfileModal {
  static void show(BuildContext context, {required PsychologistUserEntity? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditProfileContent(user: user),
    );
  }
}

class _EditProfileContent extends ConsumerStatefulWidget {
  final PsychologistUserEntity? user;

  const _EditProfileContent({required this.user});

  @override
  ConsumerState<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends ConsumerState<_EditProfileContent> {
  late TextEditingController _nameCtrl;
  late TextEditingController _degreeCtrl;
  String? _selectedPhotoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?.fullName ?? '');
    _degreeCtrl = TextEditingController(
        text: widget.user?.titleDegree ?? 'M.Psi., Psikolog');
    _selectedPhotoPath = widget.user?.profilePhotoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _degreeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file != null) {
      setState(() {
        _selectedPhotoPath = file.path ?? file.name;
      });
    }
  }

  void _saveProfile() {
    final newName = _nameCtrl.text.trim();
    final newDegree = _degreeCtrl.text.trim();

    if (newName.isEmpty) {
      TopToast.show(
        context,
        title: 'Nama Wajib Diisi',
        message: 'Mohon masukkan nama lengkap Anda.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    ref.read(authStateProvider.notifier).updateProfile(
          fullName: newName,
          titleDegree: newDegree.isNotEmpty ? newDegree : 'M.Psi., Psikolog',
          profilePhotoUrl: _selectedPhotoPath,
        );

    Navigator.pop(context);

    TopToast.show(
      context,
      title: 'Profil Diperbarui',
      message: 'Perubahan data profil Anda berhasil disimpan.',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Edit Profil Konselor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Perbarui identitas nama, gelar profesional, dan foto profil Anda:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // AVATAR PICKER
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage: getProfileImageProvider(_selectedPhotoPath),
                    child: getProfileImageProvider(_selectedPhotoPath) == null
                        ? const Icon(Icons.person,
                            size: 44, color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: -4,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_library_outlined, size: 15),
                label: const Text(
                  'Ganti Foto Profil',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // FORM FIELDS
            CustomTextField(
              label: 'Nama Lengkap',
              hint: 'Contoh: Khoirotun Nisa',
              controller: _nameCtrl,
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Gelar Profesional',
              hint: 'Contoh: M.Psi., Psikolog',
              controller: _degreeCtrl,
              prefixIcon: Icons.school_outlined,
            ),
            const SizedBox(height: 20),

            CustomButton(
              label: 'Simpan Perubahan',
              isLoading: _isLoading,
              onPressed: _saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
