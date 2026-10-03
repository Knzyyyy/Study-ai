import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Course {
  final String id;
  final String name;
  const Course({required this.id, required this.name});
}

bool validCourseSelection(String? id, List<Course> courses) =>
    id != null && courses.any((course) => course.id == id);

String? validateCourseName(String? value) =>
    value == null || value.trim().isEmpty
    ? 'Nama mata kuliah wajib diisi.'
    : null;

final courseUserProvider = StreamProvider<String?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();
});

final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final userId = ref.watch(courseUserProvider).valueOrNull;
  if (userId == null) return [];
  final rows = await Supabase.instance.client
      .from('courses')
      .select('id, name')
      .eq('user_id', userId)
      .order('created_at');
  return rows.map((row) => Course(id: row['id'], name: row['name'])).toList();
});

Future<Course?> showAddCourseDialog(BuildContext context, WidgetRef ref) async {
  final course = await showDialog<Course>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AddCourseDialog(),
  );
  if (course != null) ref.invalidate(coursesProvider);
  return course;
}

class _AddCourseDialog extends StatefulWidget {
  const _AddCourseDialog();

  @override
  State<_AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<_AddCourseDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Silakan login kembali.');
      final row = await client
          .from('courses')
          .insert({'user_id': user.id, 'name': _name.text.trim()})
          .select('id, name')
          .single();
      if (mounted) {
        Navigator.pop(context, Course(id: row['id'], name: row['name']));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal menyimpan mata kuliah. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Tambah Mata Kuliah'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Nama mata kuliah'),
              validator: validateCourseName,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    ),
  );
}
