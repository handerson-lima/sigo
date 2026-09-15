import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'src/sync/operation_queue.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const bool.fromEnvironment('SIGO_EMULATORS')
        ? const FirebaseOptions(
            apiKey: 'demo-key',
            appId: '1:123:web:demo',
            messagingSenderId: '123',
            projectId: 'demo-sigo',
            authDomain: 'localhost',
            storageBucket: 'demo-sigo.appspot.com',
          )
        : DefaultFirebaseOptions.currentPlatform,
  );

  if (const bool.fromEnvironment('SIGO_EMULATORS')) {
    const host = String.fromEnvironment(
      'SIGO_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }
  OperationQueue.instance.start();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SIGO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: goRouter,
    );
  }
}
