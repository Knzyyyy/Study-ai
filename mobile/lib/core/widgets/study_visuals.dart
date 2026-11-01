import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CutoutStatCard extends StatelessWidget {
  const CutoutStatCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.peach = false,
  });
  final String label;
  final IconData icon;
  final Widget value;
  final bool peach;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: peach ? AppColors.peachSoft : AppColors.lavenderSoft,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: peach ? AppColors.peachBorder : AppColors.lavenderBorder,
        width: 2,
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: 48,
            height: 40,
            decoration: BoxDecoration(
              color: peach ? const Color(0xFFFFAE78) : const Color(0xFFA5A0F6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Icon(icon, size: 19, color: AppColors.charcoal),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 48, 12, 20),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                value,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class StudyIllustration extends StatelessWidget {
  const StudyIllustration({super.key, this.trophy = false, this.size = 110});
  final bool trophy;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            right: 4,
            child: Icon(
              Icons.auto_awesome,
              size: size * .2,
              color: const Color(0xFFFFD166),
            ),
          ),
          Transform.rotate(
            angle: -.244,
            child: Stack(
              children: [
                Transform.translate(
                  offset: const Offset(3, 4),
                  child: Icon(
                    trophy ? Icons.emoji_events_rounded : Icons.school_rounded,
                    size: size * .88,
                    color: AppColors.charcoal,
                  ),
                ),
                Icon(
                  trophy ? Icons.emoji_events_rounded : Icons.school_rounded,
                  size: size * .88,
                  color: trophy ? const Color(0xFFFFAE42) : AppColors.hero,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
