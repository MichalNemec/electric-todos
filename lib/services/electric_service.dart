import 'package:electricsql/util.dart';
import 'package:electricsql_flutter/drivers/drift.dart';
import 'package:electricsql_flutter/electricsql_flutter.dart';
import 'package:todos_electrified/auth.dart';
import 'package:todos_electrified/database/database.dart';
import 'package:todos_electrified/database/drift/connection/connection.dart' as impl;
import 'package:todos_electrified/database/drift/database.dart';
import 'package:todos_electrified/generated/electric/migrations.dart';

typedef InitData = ({
  TodosDatabase todosDb,
  ElectricClient electricClient,
  ConnectivityStateController connectivityStateController,
});

class ElectricService {
  static final ElectricService _singleton = ElectricService._internal();
  factory ElectricService() {
    return _singleton;
  }
  ElectricService._internal();

  InitData? initData;
  TodosDatabase? get todosDb => initData?.todosDb;
  ElectricClient? get client => initData?.electricClient;

  Future<DriftElectricClient<AppDatabase>> startElectricDrift(
    String dbName,
    AppDatabase db,
  ) async {
    final client = await electrify<AppDatabase>(
      dbName: dbName,
      db: db,
      migrations: kElectricMigrations,
      config: ElectricConfig(
        logger: LoggerConfig(
          level: Level.debug,
        ),
        // url: '<ELECTRIC_SERVICE_URL>',
      ),
    );

    await client.connect(authToken());

    return client;
  }

  init() async {
    final db = AppDatabase(impl.connect());
    await db.customSelect("SELECT 1").get();
    try {
      const dbName = "todos_db";

      final DriftElectricClient<AppDatabase> electricClient;
      electricClient = await startElectricDrift(dbName, db);
      electricClient.syncTables(["todo", "todolist"]);

      final todosDb = TodosDatabase(db);
      final connectivityStateController = ConnectivityStateController(electricClient)..init();
      //TODO based on that disconnect/connect
      print(connectivityStateController.connectivityState.status);

      final init = (
        todosDb: todosDb,
        electricClient: electricClient,
        connectivityStateController: connectivityStateController,
      );
      initData = init;
    } on SatelliteException catch (e) {
      if (e.code == SatelliteErrorCode.unknownSchemaVersion) {
        print("unknownSchemaVersion");
        // Ask to delete the database
        /* final shouldDeleteLocal = await launchConfirmationDialog(
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
        } */
      }
      rethrow;
    }
  }

  void dispose() {
    // Cleanup resources on app unmount
    if (initData != null) {
      initData!.electricClient.close();
      initData!.todosDb.close();
      print("Everything closed");
    }
  }
}
