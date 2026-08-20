import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'transaction_form_screen.dart';
import 'listas_screen.dart';
import 'investments_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import '../database/supabase_helper.dart';
import '../providers/navigation_provider.dart';
import '../utils/profile_guard.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkOnboarding();
    });
  }

  Future<void> _checkOnboarding() async {
    final userId = SupabaseHelper.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Já confirmamos antes (nesta sessão ou numa anterior) que este usuário
    // tem perfil -- nunca mais precisa checar por rede, então uma falha de
    // rede logo após abrir o app (comum após atualizar de versão) não pode
    // mais mandar um usuário existente pro onboarding.
    if (await ProfileGuard.knownToHaveProfile(userId)) return;

    final hasProfile = await ProfileGuard.hasProfileRemote();
    if (hasProfile == null) {
      // Falha de rede/transiente: nunca assume "usuário novo" nesse caso.
      debugPrint('Erro ao verificar perfil existente -- tentando de novo mais tarde');
      return;
    }
    if (hasProfile) {
      await ProfileGuard.markHasProfile(userId);
      return;
    }

    // Consulta rodou com sucesso e confirmou 0 linhas: agora sim é seguro
    // considerar que este usuário nunca fez o onboarding.
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
  }

  final List<Widget> _pages = const [
    DashboardScreen(),
    ListasScreen(),
    InvestmentsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabProvider);

    return Scaffold(
      body: _pages[currentIndex],
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TransactionFormScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Compras',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Investimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
