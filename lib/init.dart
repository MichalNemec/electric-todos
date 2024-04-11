import 'package:flutter/material.dart';

class InitAppLoader extends StatefulWidget {
  const InitAppLoader({super.key});

  @override
  State<InitAppLoader> createState() => _InitAppLoaderState();
}

class _InitAppLoaderState extends State<InitAppLoader> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Initializing the app...",
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
