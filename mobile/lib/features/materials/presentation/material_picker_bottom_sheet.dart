import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/material_model.dart';
import 'courses.dart';

Future<MaterialModel?> showMaterialPickerBottomSheet({
  required BuildContext context,
  required List<MaterialModel> materials,
  required List<Course> courses,
}) => showModalBottomSheet<MaterialModel>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black54,
  builder: (context) => _MaterialPickerSheet(
    materials: materials.where((item) => item.status == 'done').toList(),
    courses: courses,
  ),
);

class _MaterialPickerSheet extends StatelessWidget {
  const _MaterialPickerSheet({required this.materials, required this.courses});

  final List<MaterialModel> materials;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final courseNames = {for (final course in courses) course.id: course.name};
    final visibleCount = materials.length < 4 ? materials.length : 4;
    final listHeight = visibleCount == 0
        ? 0.0
        : visibleCount * 64.0 + (visibleCount - 1) * 8.0;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih Materi Sumber',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih materi kuliah yang sudah siap untuk membuka fitur ini:',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 14),
              if (materials.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada materi yang siap dipelajari.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSecondary),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: materials.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final material = materials[index];
                      final courseName =
                          courseNames[material.courseId] ?? 'Materi kuliah';
                      final count = material.pageCount;
                      final isPresentation = material.fileType
                          .toLowerCase()
                          .contains('ppt');
                      final detail = count == null
                          ? material.fileType.toUpperCase()
                          : '$count ${isPresentation ? 'slide' : 'halaman'}';

                      return Material(
                        color: const Color(0xFFF3EEE7),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, material),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 64),
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE8DFD3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        material.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$courseName • $detail',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.inkSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF7D73F6),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
