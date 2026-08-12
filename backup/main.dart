import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/manage_categories_screen.dart';
import 'screens/manage_accounts_screen.dart';
import 'screens/manage_users_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  
  try {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? 'COLE_SUA_URL_AQUI',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'COLE_SUA_CHAVE_AQUI',
    );
  } catch (e) {
    debugPrint('Erro ao inicializar Supabase/Dotenv: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CofreNuvem',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
      routes: {
        '/manage_categories': (context) => const ManageCategoriesScreen(),
        '/manage_accounts': (context) => const ManageAccountsScreen(),
        '/manage_users': (context) => const ManageUsersScreen(),
        '/history': (context) => const TransactionHistoryScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Se a sessão já estiver pronta ou se houver um usuário cacheado
        if (Supabase.instance.client.auth.currentUser != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
