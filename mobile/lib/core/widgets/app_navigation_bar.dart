import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      (Icons.home_rounded, 'Beranda'),
      (Icons.menu_book_rounded, 'Materi'),
      (Icons.add_rounded, 'Upload'),
      (Icons.assignment_turned_in_outlined, 'Kuis'),
      (Icons.person_outline_rounded, 'Profil'),
    ];
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 84,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFECE6).withValues(alpha: .95),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(destinations.length, (index) {
                        final selected = selectedIndex == index;
                        final upload = index == 2;
                        return Expanded(
                          child: Semantics(
                            label: destinations[index].$2,
                            button: true,
                            selected: selected,
                            child: Tooltip(
                              message: destinations[index].$2,
                              excludeFromSemantics: true,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: duration,
                                  width: upload ? 52 : 56,
                                  height: upload ? 52 : 48,
                                  decoration: BoxDecoration(
                                    color: upload
                                        ? null
                                        : (selected
                                              ? Colors.white
                                              : Colors.transparent),
                                    gradient: upload
                                        ? const LinearGradient(
                                            begin: Alignment.bottomLeft,
                                            end: Alignment.topRight,
                                            colors: [
                                              AppColors.primaryDark,
                                              Color(0xFF8C84F7),
                                            ],
                                          )
                                        : null,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                    border: upload && selected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: upload
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x665B50E6),
                                              blurRadius: 16,
                                              offset: Offset(0, 6),
                                            ),
                                          ]
                                        : selected
                                        ? const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => onDestinationSelected(index),
                                      child: Center(
                                        child: Icon(
                                          destinations[index].$1,
                                          size: upload ? 26 : 22,
                                          color: upload
                                              ? Colors.white
                                              : AppColors.charcoal.withValues(
                                                  alpha: selected ? 1 : .55,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
