import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/manage_categories_screen.dart';
import 'screens/manage_accounts_screen.dart';
import 'screens/manage_users_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
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
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/manage_categories': (context) => const ManageCategoriesScreen(),
        '/manage_accounts': (context) => const ManageAccountsScreen(),
        '/manage_users': (context) => const ManageUsersScreen(),
        '/history': (context) => const TransactionHistoryScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
