import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app/main_app.dart';
import 'core/di/injection_container.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initDependencies();
  runApp(const ReelApp());
}