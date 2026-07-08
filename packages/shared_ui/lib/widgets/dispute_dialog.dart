import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'app_text_field.dart';
import 'green_button.dart';

class DisputeDialog extends StatefulWidget {
  final Future<void> Function(String title, String description) onSubmit;

  const DisputeDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<DisputeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        _titleController.text.trim(),
        _descController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true); // Return true on success
      }
    } catch (_) {
      // Parents handle specific errors
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Uyuşmazlık / Sorun Bildir',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Yaşadığınız sorunu (fiyat anlaşmazlığı, hasar vb.) detaylandırarak bize iletebilirsiniz. Ekibimiz en kısa sürede inceleyecektir.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _titleController,
                  label: 'Konu Başlığı',
                  hint: 'Örn: Fiyat Anlaşmazlığı / Hasar Talebi',
                  prefixIcon: Icons.title_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Konu başlığı gereklidir.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descController,
                  label: 'Açıklama',
                  hint: 'Lütfen olayı detaylıca anlatınız...',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Lütfen açıklama yazınız.';
                    if (val.trim().length < 10) return 'Lütfen en az 10 karakter yazın.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GreenButton(
                        text: 'Talebi Gönder',
                        onPressed: _submit,
                        isLoading: _isSubmitting,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showDisputeDialog({
  required BuildContext context,
  required Future<void> Function(String title, String description) onSubmit,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => DisputeDialog(onSubmit: onSubmit),
  );
}
