import 'package:drift/drift.dart';
import 'package:todos_electrified/database/drift/database.dart';

class TodosDatabase {
  final AppDatabase db;

  TodosDatabase(this.db);

  Future<void> close() async {
    await db.close();
  }

  Future<List<Todo>> fetchTodos() async {
    return (db.todo.select()
          ..orderBy(
            [(tbl) => OrderingTerm(expression: tbl.text$.lower())],
          ))
        .map(
          (todo) => Todo(
            completed: todo.completed,
            id: todo.id,
            listId: todo.listid,
            editedAt: todo.editedAt,
            text: todo.text$!,
          ),
        )
        .get();
  }

  Stream<List<Todo>> watchTodos() {
    return (db.todo.select()
          ..orderBy(
            [(tbl) => OrderingTerm(expression: tbl.text$.lower())],
          ))
        .map(
          (todo) => Todo(
            completed: todo.completed,
            id: todo.id,
            listId: todo.listid,
            editedAt: todo.editedAt,
            text: todo.text$!,
          ),
        )
        .watch();
  }

  Future<void> updateTodo(Todo todo) async {
    await (db.todo.update()
          ..where(
            (tbl) => tbl.id.equals(todo.id),
          ))
        .write(
      TodoCompanion(
        completed: Value(todo.completed),
        listid: Value(todo.listId),
        text$: Value(todo.text),
        editedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> insertTodo(Todo todo) async {
    await db.todo.insertOne(
      TodoCompanion.insert(
        id: todo.id,
        completed: todo.completed,
        listid: Value(todo.listId),
        text$: Value(todo.text),
        editedAt: todo.editedAt,
      ),
    );
  }

  Future<void> removeTodo(String id) async {
    await db.todo.deleteWhere((tbl) => tbl.id.equals(id));
  }
}

class Todo {
  final String id;
  final String? listId;
  final String? text;
  final DateTime editedAt;
  final bool completed;

  Todo({
    required this.id,
    required this.listId,
    required this.text,
    required this.editedAt,
    required this.completed,
  });

  Todo copyWith({
    String? Function()? listId,
    String? text,
    DateTime? editedAt,
    bool? completed,
  }) {
    return Todo(
      id: id,
      listId: listId != null ? listId() : this.listId,
      text: text ?? this.text,
      editedAt: editedAt ?? this.editedAt,
      completed: completed ?? this.completed,
    );
  }
}
