import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Kembali',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.borderLine, width: 1.4),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.charcoal,
          size: 20,
        ),
      ),
    ),
  );
}
