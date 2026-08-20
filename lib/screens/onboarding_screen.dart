import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_helper.dart';
import '../utils/bancos_brasil.dart';
import '../utils/default_data.dart';
import '../utils/profile_guard.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Segunda camada de proteção contra o bug de perfil duplicado (ver
  // ProfileGuard): mesmo que algo tenha mandado o usuário pra cá por
  // engano, esta tela re-confirma por conta própria antes de deixar
  // alguém criar um perfil/conta/cartão novos. Só mostra o formulário
  // depois que essa checagem termina.
  bool _checkingExistingProfile = true;
  int _currentStep = 0;
  bool _isLoading = false;

  // Passo 1: Perfil
  final _perfilNomeController = TextEditingController();

  // Passo 2: Conta
  final _contaNomeController = TextEditingController();
  String _bancoCodigo = '999'; // Default Outros

  // Passo 3: Métodos
  bool _usaCredito = false;

  final _fechamentoController = TextEditingController();
  final _vencimentoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Tenta carregar o nome do metadata do auth
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (metadata != null && metadata['nome'] != null) {
      _perfilNomeController.text = metadata['nome'];
    }
    _guardAgainstExistingProfile();
  }

  Future<void> _guardAgainstExistingProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final hasProfile = await ProfileGuard.hasProfileRemote();
      if (hasProfile == true) {
        await ProfileGuard.markHasProfile(userId);
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
        }
        return;
      }
    }
    if (mounted) setState(() => _checkingExistingProfile = false);
  }

  void _finishOnboarding() async {
    if (_perfilNomeController.text.trim().isEmpty) return;
    if (_contaNomeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final db = await SupabaseHelper.instance.database;
      
      // Injeta categorias padrao no SQLite
      await DefaultData.seedDefaultCategories();

      // 1. Criar Perfil (Usuario)
      final usuarioId = await db.insert(SupabaseHelper.tableUsuarios, {
        'Nome': _perfilNomeController.text.trim(),
        'PIN_Acesso': null,
      });

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        await ProfileGuard.markHasProfile(currentUserId);
      }

      // 2. Criar Conta Bancaria
      final contaId = await db.insert(SupabaseHelper.tableContasBancarias, {
        'Usuario_ID': usuarioId,
        'Nome': _contaNomeController.text.trim(),
        'Codigo_Banco': _bancoCodigo,
      });

      // 3. Criar Métodos Pagamento
      if (_bancoCodigo != '100') {
        await db.insert(SupabaseHelper.tableMetodosPagamento, {
          'Conta_ID': contaId,
          'Nome': 'PIX',
          'Tipo': 'PIX',
        });
        await db.insert(SupabaseHelper.tableMetodosPagamento, {
          'Conta_ID': contaId,
          'Nome': 'Cartão de Débito',
          'Tipo': 'Débito',
        });
      } else {
        await db.insert(SupabaseHelper.tableMetodosPagamento, {
          'Conta_ID': contaId,
          'Nome': 'Dinheiro',
          'Tipo': 'Dinheiro',
        });
      }

      if (_usaCredito) {
        await db.insert(SupabaseHelper.tableMetodosPagamento, {
          'Conta_ID': contaId,
          'Nome': 'Cartão de Crédito',
          'Tipo': 'Crédito',
          'Dia_Fechamento': _fechamentoController.text.isNotEmpty ? int.tryParse(_fechamentoController.text) : null,
          'Dia_Vencimento': _vencimentoController.text.isNotEmpty ? int.tryParse(_vencimentoController.text) : null,
        });
      }

      // Se a conta principal não for Dinheiro Físico, adiciona a Carteira padrão silenciosamente
      if (_bancoCodigo != '100') {
        final carteiraId = await db.insert(SupabaseHelper.tableContasBancarias, {
          'Usuario_ID': usuarioId,
          'Nome': 'Carteira (Dinheiro Físico)',
          'Codigo_Banco': '100',
        });
        await db.insert(SupabaseHelper.tableMetodosPagamento, {
          'Conta_ID': carteiraId,
          'Nome': 'Dinheiro',
          'Tipo': 'Dinheiro',
        });
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExistingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo ao CofreNuvem!'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
// Banco local removido
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              } catch (e) {
                // ignore
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep == 0 && _perfilNomeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um nome para seu perfil')));
                return;
              }
              if (_currentStep == 1 && _contaNomeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome da conta')));
                return;
              }

              if (_currentStep == 2 && _usaCredito) {
                if (_fechamentoController.text.trim().isEmpty || _vencimentoController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os dias de fechamento e vencimento do cartão')));
                  return;
                }
              }

              if (_currentStep < 2) {
                setState(() => _currentStep += 1);
              } else {
                _finishOnboarding();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 2 ? 'Concluir' : 'Continuar'),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Voltar'),
                      ),
                    ]
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Seu Perfil'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vamos criar seu primeiro perfil financeiro. Este perfil será o dono das despesas que você lançar.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _perfilNomeController,
                      decoration: const InputDecoration(labelText: 'Como quer ser chamado?', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.editing,
              ),
              Step(
                title: const Text('Sua Conta'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agora, informe a sua principal conta de onde o dinheiro sai. Busque pelo nome do seu banco (ex: Nubank, Inter). A sua Carteira de Dinheiro Físico já será criada automaticamente para você.'),
                    const SizedBox(height: 16),
                    Autocomplete<BancoLogo>(
                      initialValue: TextEditingValue(text: _contaNomeController.text),
                      displayStringForOption: (BancoLogo option) => option.nome,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return BancosBrasil.bancos;
                        }
                        // Se o texto for exatamente o nome de um banco, esconde a lista (já foi selecionado)
                        if (BancosBrasil.bancos.any((b) => b.nome.toLowerCase() == textEditingValue.text.toLowerCase())) {
                          return const Iterable<BancoLogo>.empty();
                        }
                        
                        return BancosBrasil.bancos.where((BancoLogo option) {
                          return option.nome.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                 option.codigo.contains(textEditingValue.text);
                        });
                      },
                      onSelected: (BancoLogo selection) {
                        _contaNomeController.text = selection.nome;
                        _bancoCodigo = selection.codigo;
                        
                        if (selection.codigo == '100') {
                          setState(() {
                            // nothing needed
                          });
                        } else {
                          setState(() {
                            // nothing needed
                          });
                        }
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Busque seu Banco ou dê um Apelido', 
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance),
                          ),
                          onChanged: (val) {
                            _contaNomeController.text = val;
                            // Se ele não selecionar da lista, deixamos '999' como Outros.
                            _bancoCodigo = '999';
                          },
                        );
                      },
                    ),
                  ],
                ),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.editing,
              ),
              Step(
                title: const Text('Cartão de Crédito'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sua nova conta virá com PIX e Débito configurados por padrão. Deseja adicionar também um Cartão de Crédito?'),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Sim, adicionar Cartão de Crédito'),
                      value: _usaCredito,
                      onChanged: (val) => setState(() => _usaCredito = val!),
                    ),
                    if (_usaCredito) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _fechamentoController,
                              decoration: const InputDecoration(labelText: 'Dia Fechamento', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _vencimentoController,
                              decoration: const InputDecoration(labelText: 'Dia Vencimento', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
                isActive: _currentStep >= 2,
              ),
            ],
          ),
    );
  }
}
