import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_back_button.dart';

class StudyFeatureAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const StudyFeatureAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.showBackButton = true,
  });

  static const double toolbarHeight = kToolbarHeight;

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: toolbarHeight,
    titleSpacing: showBackButton ? 8 : 20,
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: showBackButton
        ? AppBackButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          )
        : null,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.charcoal,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              color: AppColors.inkSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    ),
    actions: actions,
  );
}
