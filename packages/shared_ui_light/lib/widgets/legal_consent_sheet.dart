import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'green_button.dart';
import 'legal_documents_dialog.dart';

class LegalConsentSheet extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback? onCancelled;

  const LegalConsentSheet({
    super.key,
    required this.onAccepted,
    this.onCancelled,
  });

  /// Displays the legal consent bottom sheet and waits for approval.
  /// Returns true if user accepted and proceeded, false otherwise.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LegalConsentSheet(
        onAccepted: () => Navigator.of(context).pop(true),
        onCancelled: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  State<LegalConsentSheet> createState() => _LegalConsentSheetState();
}

class _LegalConsentSheetState extends State<LegalConsentSheet> {
  bool _kvkkAccepted = false;
  bool _termsAccepted = false;
  bool _consentAccepted = false;

  bool get _canProceed => _kvkkAccepted && _termsAccepted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yasal Koşullar ve Onay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Devam etmek için lütfen aşağıdaki şartları onaylayınız.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Kutucuk 1: KVKK (Zorunlu)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _kvkkAccepted,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _kvkkAccepted = val ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.kvkk),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          children: [
                            TextSpan(text: 'ÇEKİCİM '),
                            TextSpan(
                              text: 'KVKK Aydınlatma Metni\'ni',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: ' okudum, bilgi edindim. (Zorunlu)'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Kutucuk 2: Kullanım Koşulları (Zorunlu)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _termsAccepted,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.terms),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          children: [
                            TextSpan(
                              text: 'Sorumluluk Reddi Beyanı ve Platform Kullanım Koşulları\'nı',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: ' okudum, kabul ediyorum. (Zorunlu)'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Kutucuk 3: Açık Rıza Metni (İsteğe Bağlı)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consentAccepted,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _consentAccepted = val ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.consent),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          children: [
                            TextSpan(
                              text: 'Açık Rıza Metni',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ' kapsamında özel nitelikli kişisel verilerimin işlenmesine ve analiz/iyileştirme amaçlı konum verisi kullanımına rıza gösteriyorum. (İsteğe Bağlı)',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            GreenButton(
              text: 'Onayla ve Devam Et',
              onPressed: _canProceed ? widget.onAccepted : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onCancelled,
              child: const Text(
                'Vazgeç ve Çıkış Yap',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
