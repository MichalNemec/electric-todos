import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todos_electrified/database/database.dart';

final todosProvider = StreamProvider<List<Todo>>((ref) {
  final db = ref.watch(todosDatabaseProvider);

  return db.watchTodos();
});
