import 'package:flutter/material.dart';
import 'package:my_app/screens/home_screen.dart';
import 'package:my_app/screens/brand_splash_screen.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/catalog_gate.dart';
import 'package:my_app/widgets/activity_messages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(initialization: _initializeApp()));
}

Future<void> _initializeApp() => Future.wait([
  UserProfileService.instance.initialize(),
  UserActivityService.instance.initialize(),
]);

//
// StatelessWidget(無狀態元件），本身不需要管理任何動態資料
class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialization});

  final Future<void>? initialization;
  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) =>
          ActivityMessages(messengerKey: _messengerKey, child: child!),
      debugShowCheckedModeBanner: false,
      title: '膳解人意',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E8D57)),
        scaffoldBackgroundColor: const Color(0xFFF7F9F4),
      ),
      home: BrandLaunchGate(
        initialization: initialization,
        child: CatalogGate(
          onLoaded: UserActivityService.instance.initialize,
          child: const HomeScreen(),
        ),
      ),
    );
  }
}
