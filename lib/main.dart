import 'dart:async';

import 'package:electricsql/util.dart' show genUUID;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todos_electrified/database/database.dart';
import 'package:todos_electrified/services/electric_service.dart';

const kListId = "LIST-ID-SAMPLE";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ElectricService().init();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    ElectricService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Home();
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Todos Electrified',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: StreamBuilder<List<Todo>>(
              stream: ElectricService().todosDb!.watchTodos(),
              builder: (context, snapshot) {
                //if (snapshot.connectionState == ConnectionState.waiting) {
                //  return const Center(child: CircularProgressIndicator());
                //}
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return _TodosLoaded(todos: snapshot.data ?? []);
                }
                return const Center(child: Text("empty"));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* class ConnectivityButton extends ConsumerWidget {
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
        final electricClient = ElectricService().initData!.electricClient; //ref.read(electricClientProvider);
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
} */

class _TodosLoaded extends StatelessWidget {
  _TodosLoaded({required this.todos});

  final List<Todo> todos;
  final TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
                    await ElectricService().todosDb?.insertTodo(
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

class TodoTile extends StatelessWidget {
  final Todo todo;
  const TodoTile({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconButton(
        onPressed: () async {
          await ElectricService().todosDb?.updateTodo(todo.copyWith(completed: !todo.completed));
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
          await ElectricService().todosDb?.removeTodo(todo.id);
        },
        icon: const Icon(Icons.delete),
      ),
    );
  }
}
