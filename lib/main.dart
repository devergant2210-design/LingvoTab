import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'), // anon key is public by design; RLS protects data
  );
  runApp(const LingvoTab());
}

class LingvoTab extends StatelessWidget {
  const LingvoTab({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'LingvoTab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
        home: Supabase.instance.client.auth.currentSession == null ? const LoginScreen() : const PickerScreen(),
      );
}
