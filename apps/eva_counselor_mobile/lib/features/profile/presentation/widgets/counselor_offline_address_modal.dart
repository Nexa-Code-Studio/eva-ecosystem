import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';

class CounselorOfflineAddressModal {
  static void show({
    required BuildContext context,
    required PsychologistUserEntity? user,
    required Function({
      required String placeName,
      required String address,
      required String city,
      String? notes,
    }) onSave,
  }) {
    final placeController = TextEditingController(
      text: user?.offlinePlaceName ?? 'Biro Konsultasi Psikologi Mandiri Anindya',
    );
    final addressController = TextEditingController(
      text: user?.offlineAddress ?? 'Jl. Menteng Raya No. 42, RT 02/RW 03',
    );
    final cityController = TextEditingController(
      text: user?.offlineCity ?? 'Jakarta Pusat',
    );
    final notesController = TextEditingController(
      text: user?.offlineNotes ?? 'Lantai 2, Ruang Konseling Melati 1',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                        Icon(Icons.location_on_rounded, size: 22, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Alamat Praktik Tatap Muka',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pasien yang memilih konsultasi offline akan mendatangi lokasi ini sesuai slot yang dikonfirmasi. Pastikan alamat tertera dengan jelas.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Nama Tempat / Klinik Praktik',
                  hint: 'mis. Biro Psikologi Anindya atau Klinik Pratama Sehat',
                  controller: placeController,
                  prefixIcon: Icons.business_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Alamat Lengkap Praktik',
                  hint: 'Nama jalan, nomor bangunan, RT/RW, kelurahan/kecamatan',
                  controller: addressController,
                  maxLines: 2,
                  prefixIcon: Icons.map_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Kota / Wilayah',
                  hint: 'mis. Jakarta Pusat, Bandung, atau Surabaya',
                  controller: cityController,
                  prefixIcon: Icons.location_city_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Petunjuk Ruang / Akses (Opsional)',
                  hint: 'mis. Lantai 2, Ruang Melati. Laporkan ke resepsionis gedung.',
                  controller: notesController,
                  maxLines: 2,
                  prefixIcon: Icons.meeting_room_outlined,
                ),
                const SizedBox(height: 20),
                CustomButton(
                  label: 'Simpan Alamat Praktik',
                  onPressed: () {
                    final place = placeController.text.trim();
                    final address = addressController.text.trim();
                    final city = cityController.text.trim();
                    final notes = notesController.text.trim();

                    if (place.isEmpty || address.isEmpty) {
                      TopToast.show(
                        context,
                        title: 'Data Belum Lengkap',
                        message: 'Nama klinik dan alamat lengkap wajib diisi.',
                        type: ToastType.warning,
                      );
                      return;
                    }

                    onSave(
                      placeName: place,
                      address: address,
                      city: city.isEmpty ? 'Indonesia' : city,
                      notes: notes.isEmpty ? null : notes,
                    );
                    Navigator.pop(ctx);
                    TopToast.show(
                      context,
                      title: 'Alamat Praktik Disimpan! 📍',
                      message: 'Lokasi praktik tatap muka Anda telah berhasil diperbarui.',
                      type: ToastType.success,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
