import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

Future<void> showResetPasswordBottomSheet({
  required BuildContext context,
  required String initialEmail,
  required Future<void> Function(String email) sendResetEmail,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 280),
  pageBuilder: (context, animation, secondaryAnimation) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ColoredBox(color: Colors.black.withValues(alpha: .42)),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _ResetPasswordSheet(
            initialEmail: initialEmail,
            sendResetEmail: sendResetEmail,
          ),
        ),
      ),
    ],
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    final slide = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(slide),
      child: child,
    );
  },
);

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({
    required this.initialEmail,
    required this.sendResetEmail,
  });

  final String initialEmail;
  final Future<void> Function(String email) sendResetEmail;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  late final TextEditingController _emailController;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!_isEmail(email)) {
      setState(() => _error = 'Masukkan alamat email yang valid.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.sendResetEmail(email);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Tautan belum bisa dikirim. Periksa koneksi lalu coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: AppColors.borderLine),
    );

    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _sent ? 'Cek email kamu' : 'Reset Kata Sandi',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.inkMeta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _sent
                    ? 'Jika email ini terdaftar, tautan pemulihan kata sandi akan segera dikirim.'
                    : 'Masukkan email kampusmu untuk menerima tautan pemulihan kata sandi.',
                style: const TextStyle(
                  color: AppColors.inkSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (!_sent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  enabled: !_sending,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'nama@mahasiswa.ac.id',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder.copyWith(
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.7,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _sending || _sent ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _sent ? 'Tautan reset dikirim' : 'Kirim Tautan Reset',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
