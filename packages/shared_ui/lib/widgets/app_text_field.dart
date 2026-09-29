import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final bool enabled;
  final bool readOnly;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;

  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.style,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark || theme.scaffoldBackgroundColor.computeLuminance() < 0.5;
    final defaultTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscureText : false,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      style: widget.style ?? TextStyle(
        color: widget.enabled ? defaultTextColor : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary.withValues(alpha: 0.6),
        ),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: iconColor)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: iconColor,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
      ),
    );
  }
}
