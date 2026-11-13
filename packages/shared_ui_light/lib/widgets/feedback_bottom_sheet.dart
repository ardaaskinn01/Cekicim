import 'package:flutter/material.dart';
import '../app_colors.dart';

typedef FeedbackSubmitCallback = Future<void> Function({
  required String title,
  required String message,
  required String category,
  required String userRole,
});

class FeedbackBottomSheet extends StatefulWidget {
  final String userRole; // 'customer' or 'driver'
  final FeedbackSubmitCallback onSubmit;

  const FeedbackBottomSheet({
    super.key,
    required this.userRole,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String userRole,
    required FeedbackSubmitCallback onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FeedbackBottomSheet(
        userRole: userRole,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'suggestion';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'suggestion', 'label': 'Öneri & Fikir', 'icon': Icons.lightbulb_outline},
    {'key': 'bug', 'label': 'Hata Bildirimi', 'icon': Icons.bug_report_outlined},
    {'key': 'complaint', 'label': 'Şikayet', 'icon': Icons.sentiment_dissatisfied_outlined},
    {'key': 'satisfaction', 'label': 'Memnuniyet', 'icon': Icons.thumb_up_alt_outlined},
    {'key': 'general', 'label': 'Genel Görüş', 'icon': Icons.chat_bubble_outline},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen konu başlığı yazınız.'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen mesajınızı/önerinizi detaylandırınız.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        title: title,
        message: message,
        category: _selectedCategory,
        userRole: widget.userRole,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geri bildiriminiz için teşekkürler! Ekibimiz titizlikle inceleyecektir.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gönderilemedi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.feedback_outlined, color: AppColors.accent),
                    SizedBox(width: 10),
                    Text(
                      'Öneri & Geri Bildirim',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Uygulamamızı geliştirmek için görüşleriniz bizim için çok kıymetli. Karşılaştığınız sorunları veya yeni özellik fikirlerinizi paylaşabilirsiniz.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Category selector
            const Text('Kategori:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'] as IconData, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(cat['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat['key'] as String);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Konu Başlığı',
                hintText: 'Örn: Navigasyon ekranı önerisi',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Message input
            TextField(
              controller: _messageController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Detaylı Açıklama',
                hintText: 'Fikrinizi veya yaşadığınız durumu açıklayınız...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Geri Bildirimi Gönder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
