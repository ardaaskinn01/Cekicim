import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;

  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: AppColors.textSecondary)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
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
