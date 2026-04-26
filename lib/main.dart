import 'package:flutter/material.dart';
// Uncomment when Firebase is integrated (google-services.json added):
// import 'package:firebase_core/firebase_core.dart';
import 'app/main_app.dart';
import 'core/di/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase once google-services.json / GoogleService-Info.plist are configured:
  // await Firebase.initializeApp();

  await initDependencies();

  runApp(const ReelApp());
}
