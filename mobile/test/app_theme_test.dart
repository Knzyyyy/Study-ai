import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/core/theme/app_theme.dart';

void main() {
  test('app theme uses the bundled Plus Jakarta Sans font', () {
    final theme = AppTheme.light;

    expect(theme.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
    expect(theme.textTheme.titleLarge?.fontFamily, 'PlusJakartaSans');
  });
}
