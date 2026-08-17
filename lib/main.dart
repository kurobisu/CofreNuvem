import 'dart:async';
import 'dart:io';
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
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
import 'providers/tutorial_provider.dart';
import 'widgets/tutorial_overlay.dart';
import 'utils/data_refresh.dart';

// Builds de web (ex: deploy no GitHub Pages) passam essas chaves via
// `--dart-define` em tempo de compilação, para não precisar embutir o
// arquivo .env como asset publicamente acessível. Desktop/mobile continuam
// usando o .env normalmente (fallback abaixo) quando o dart-define não é
// informado.
const String _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  try {
    String supabaseUrl = _supabaseUrlDefine;
    String supabaseAnonKey = _supabaseAnonKeyDefine;

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      await dotenv.load(fileName: ".env");
      supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'COLE_SUA_URL_AQUI';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'COLE_SUA_CHAVE_AQUI';
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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
      navigatorKey: tutorialNavigatorKey,
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
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const TutorialOverlay(),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  String? _lastUserId;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _lastUserId = Supabase.instance.client.auth.currentUser?.id;

    // Os providers de dados (dashboard, investimentos, metas...) vivem no
    // ProviderScope raiz e não são .autoDispose, então continuam com o
    // resultado em cache de quem estava logado antes. Sem isso, trocar de
    // conta (logout -> criar conta nova -> login) mostra os dados da conta
    // anterior até alguma tela forçar um refresh manual.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final currentUserId = state.session?.user.id;
      if (currentUserId != _lastUserId) {
        _lastUserId = currentUserId;
        _invalidateUserScopedProviders();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkForUpdates();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    // O auto-update via instalador só existe no Windows (showUpdateDialog já
    // se auto-restringe a isso); evita a chamada de rede à toa nas outras
    // plataformas, como a versão web.
    if (!Platform.isWindows) return;
    final info = await UpdateService().checkForUpdate();
    if (info != null && mounted) {
      await showUpdateDialog(context, info);
    }
  }

  void _invalidateUserScopedProviders() => invalidateAllDataProviders(ref);

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
