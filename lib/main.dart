import 'dart:async';

import 'package:electricsql/util.dart' show SatelliteErrorCode, SatelliteException, genUUID;
import 'package:electricsql_flutter/drivers/drift.dart';
import 'package:electricsql_flutter/electricsql_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todos_electrified/database/database.dart';
import 'package:todos_electrified/database/drift/connection/connection.dart' as impl;
import 'package:todos_electrified/database/drift/database.dart';
import 'package:todos_electrified/database/drift/drift_repository.dart';
import 'package:todos_electrified/electric.dart';
import 'package:todos_electrified/init.dart';
import 'package:todos_electrified/todos.dart';
import 'package:todos_electrified/util/confirmation_dialog.dart';

const kListId = "LIST-ID-SAMPLE";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(_Entrypoint());
}

StateProvider<bool> dbDeletedProvider = StateProvider((ref) => false);

typedef InitData = ({
  TodosDatabase todosDb,
  ElectricClient electricClient,
  ConnectivityStateController connectivityStateController,
});

class _Entrypoint extends StatefulWidget {
  @override
  State<_Entrypoint> createState() => _EntrypointState();
}

class _EntrypointState extends State<_Entrypoint> {
  InitData? initData;

  @override
  void initState() {
    super.initState();
    useInitializeApp(context);
  }

  void useInitializeApp(BuildContext context) async {
    final driftRepo = await initDriftTodosDatabase();
    try {
      const dbName = "todos_db";

      final DriftElectricClient<AppDatabase> electricClient;
      electricClient = await startElectricDrift(dbName, driftRepo.db);
      electricClient.syncTables(["todo", "todolist"]);

      final todosDb = TodosDatabase(driftRepo);
      final connectivityStateController = ConnectivityStateController(electricClient)..init();

      final init = (
        todosDb: todosDb,
        electricClient: electricClient,
        connectivityStateController: connectivityStateController,
      );
      setState(() {
        initData = init;
      });
    } on SatelliteException catch (e) {
      if (e.code == SatelliteErrorCode.unknownSchemaVersion) {
        // Ask to delete the database
        final shouldDeleteLocal = await launchConfirmationDialog(
          title: "Local schema doesn't match server's",
          content: const Text("Delete local state and retry?"),
          context: context,
          barrierDismissible: false,
        );

        if (shouldDeleteLocal == true) {
          await driftRepo.close();

          if (!kIsWeb) {
            await impl.deleteTodosDbFile();

            //retryVN.value++;
            return;
          } else {
            // On web, we cannot properly retry automatically, so just ask the user to refresh
            // the page

            unawaited(impl.deleteTodosDbFile());
            await Future<void>.delayed(const Duration(milliseconds: 200));

            if (!context.mounted) return;

            await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return const AlertDialog(
                    title: Text("Local database deleted"),
                    content: Text("Please refresh the page"),
                  );
                });

            // Wait indefinitely until user refreshes
            await Future<void>.delayed(const Duration(days: 9999));
          }
        }
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    // Cleanup resources on app unmount
    if (initData != null) {
      initData!.electricClient.close();
      initData!.todosDb.todosRepo.close();
      print("Everything closed");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (initData == null) {
      // This will initialize the app and will update the initData ValueNotifier
      return const InitAppLoader();
    }

    // Database and Electric are ready
    return ProviderScope(
      overrides: [
        todosDatabaseProvider.overrideWithValue(initData!.todosDb),
        electricClientProvider.overrideWithValue(initData!.electricClient),
        connectivityStateControllerProvider.overrideWith(
          (ref) => initData!.connectivityStateController,
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todos Electrified',
      home: Consumer(
        builder: (context, ref, _) {
          final dbDeleted = ref.watch(dbDeletedProvider);

          if (dbDeleted) {
            return const _DeleteDbScreen();
          }

          return const MyHomePage();
        },
      ),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAV = ref.watch(todosProvider);
    ref.watch(electricClientProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Center(
          child: FlutterLogo(
            size: 35,
          ),
        ),
        title: const Row(
          children: [
            Text("todos", style: TextStyle(fontSize: 30)),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const ConnectivityButton(),
          const SizedBox(height: 10),
          Expanded(
            child: todosAV.when(
              data: (todos) {
                return _TodosLoaded(todos: todos);
              },
              error: (e, st) {
                return Center(child: Text(e.toString()));
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    "Unofficial Dart client running on top of\nthe sync service powered by",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: _DeleteDbButton(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteDbButton extends ConsumerWidget {
  const _DeleteDbButton();

  @override
  Widget build(BuildContext context, ref) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      onPressed: () async {
        ref.read(dbDeletedProvider.notifier).update((state) => true);

        final todosDb = ref.read(todosDatabaseProvider);
        await todosDb.todosRepo.close();

        await impl.deleteTodosDbFile();
      },
      icon: const Icon(Icons.delete),
      label: const Text("Delete local database"),
    );
  }
}

class ConnectivityButton extends ConsumerWidget {
  const ConnectivityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(
      connectivityStateControllerProvider.select((value) => value.connectivityState),
    );

    final theme = Theme.of(context);

    final ({Color color, IconData icon}) iconInfo = switch (connectivityState.status) {
      ConnectivityStatus.connected => (icon: Icons.wifi, color: theme.colorScheme.primary),
      ConnectivityStatus.disconnected => (icon: Icons.wifi_off, color: theme.colorScheme.error),
    };

    final String label = switch (connectivityState.status) {
      ConnectivityStatus.connected => "Connected",
      ConnectivityStatus.disconnected => "Disconnected",
    };

    return ElevatedButton.icon(
      onPressed: () async {
        final connectivityStateController = ref.read(connectivityStateControllerProvider);
        final electricClient = ref.read(electricClientProvider);
        final state = connectivityStateController.connectivityState;
        switch (state.status) {
          case ConnectivityStatus.connected:
            electricClient.disconnect();
          case ConnectivityStatus.disconnected:
            electricClient.connect();
        }
      },
      style: ElevatedButton.styleFrom(foregroundColor: iconInfo.color),
      icon: Icon(iconInfo.icon),
      label: Text(label),
    );
  }
}

class _TodosLoaded extends ConsumerWidget {
  _TodosLoaded({required this.todos});

  final List<Todo> todos;
  final TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.topCenter,
      child: Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: "What needs to be done?",
                  ),
                  onEditingComplete: () async {
                    final text = textController.text;
                    if (text.trim().isEmpty) {
                      // clear focus
                      FocusScope.of(context).requestFocus(FocusNode());
                      return;
                    }
                    print("done");
                    final db = ref.read(todosDatabaseProvider);
                    await db.insertTodo(
                      Todo(
                        id: genUUID(),
                        listId: kListId,
                        text: textController.text,
                        editedAt: DateTime.now(),
                        completed: false,
                      ),
                    );

                    textController.clear();
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                Flexible(
                  child: todos.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("No todos yet"),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          separatorBuilder: (context, i) => const Divider(
                            height: 0,
                          ),
                          itemBuilder: (context, i) {
                            return TodoTile(todo: todos[i]);
                          },
                          itemCount: todos.length,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodoTile extends ConsumerWidget {
  final Todo todo;
  const TodoTile({super.key, required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: IconButton(
        onPressed: () async {
          final db = ref.read(todosDatabaseProvider);
          await db.updateTodo(todo.copyWith(completed: !todo.completed));
        },
        icon: todo.completed
            ? Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              )
            : const Icon(Icons.circle_outlined),
      ),
      title: Text(
        todo.text ?? "",
        style: TextStyle(
          decoration: todo.completed ? TextDecoration.lineThrough : null,
          color: todo.completed ? Colors.grey : null,
        ),
      ),
      subtitle: Text(
        "Last edited: ${DateFormat.yMMMd().add_jm().format(todo.editedAt)}",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        onPressed: () async {
          final db = ref.read(todosDatabaseProvider);
          await db.removeTodo(todo.id);
        },
        icon: const Icon(Icons.delete),
      ),
    );
  }
}

class _DeleteDbScreen extends StatelessWidget {
  const _DeleteDbScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Local database has been deleted, please restart the app'),
      ),
    );
  }
}
