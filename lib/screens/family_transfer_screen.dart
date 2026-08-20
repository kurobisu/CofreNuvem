import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_helper.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_colors.dart';
import '../utils/tutorial_keys.dart';
import '../utils/tutorial_content.dart';
import '../widgets/tutorial_button.dart';

class FamilyTransferScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String? sourceUserId;
  final double? initialValor;
  final String? initialContaOrigem;
  final String? initialContaDestino;

  const FamilyTransferScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.sourceUserId,
    this.initialValor,
    this.initialContaOrigem,
    this.initialContaDestino,
  });

  @override
  ConsumerState<FamilyTransferScreen> createState() => _FamilyTransferScreenState();
}

class _FamilyTransferScreenState extends ConsumerState<FamilyTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? _usuarioOrigem; 
  Map<String, dynamic>? _usuarioDestino;

  List<Map<String, dynamic>> _contasOrigem = [];
  List<Map<String, dynamic>> _contasDestino = [];
  List<Map<String, dynamic>> _metodosOrigem = [];

  String? _selectedContaOrigem;
  String? _selectedMetodoOrigem;
  String? _selectedContaDestino;

  @override
  void initState() {
    super.initState();
    _descricaoController.text = widget.initialValor != null ? 'Devolução de Transferência' : 'Transferência Familiar';
    _loadData();
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  double _getParsedValor() {
    final numericOnly = _valorController.text.replaceAll(RegExp('[^0-9]'), '');
    return numericOnly.isEmpty ? 0.0 : double.parse(numericOnly) / 100;
  }

  Future<void> _loadData() async {
    try {
      final db = await SupabaseHelper.instance.database;
      final supabase = SupabaseHelper.instance.client;
      final currentUserAuthId = supabase.auth.currentUser?.id;

      final allUsers = await db.query(SupabaseHelper.tableUsuarios);
      
      // Destinatário
      final matchDestino = allUsers.where((u) => (u['id'] ?? u['ID'])?.toString() == widget.targetUserId).toList();
      if (matchDestino.isNotEmpty) {
        _usuarioDestino = matchDestino.first;
      } else {
        _usuarioDestino = {
          'id': widget.targetUserId,
          'nome': widget.targetUserName,
        };
      }

      // Remetente / Origem
      if (widget.sourceUserId != null) {
        final matchSource = allUsers.where((u) => (u['id'] ?? u['ID'])?.toString() == widget.sourceUserId).toList();
        if (matchSource.isNotEmpty) {
          _usuarioOrigem = matchSource.first;
        }
      }

      if (_usuarioOrigem == null) {
        final currentUserName = supabase.auth.currentUser?.userMetadata?['nome']?.toString().toLowerCase();
        final match = allUsers.where((u) {
          final uAuth = u['auth_id'] ?? u['Auth_ID'];
          final uNome = (u['nome'] ?? u['Nome'] ?? '').toString().toLowerCase();
          return uAuth == currentUserAuthId || 
                 (currentUserName != null && uNome == currentUserName);
        }).toList();

        if (match.isEmpty && allUsers.isNotEmpty) {
          _usuarioOrigem = allUsers.first;
        } else if (match.isNotEmpty) {
          _usuarioOrigem = match.first;
        }
      }

      if (_usuarioOrigem == null) {
        throw Exception('Usuário de origem não encontrado no sistema.');
      }

      await _loadContasEMetodos();

      if (mounted) {
        setState(() {
          if (widget.initialValor != null) {
            _valorController.text = CurrencyFormatter.format(widget.initialValor!);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados de transferência: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadContasEMetodos() async {
    final db = await SupabaseHelper.instance.database;
    final origemId = _usuarioOrigem!['id'] ?? _usuarioOrigem!['ID'];
    final destinoId = _usuarioDestino!['id'] ?? _usuarioDestino!['ID'];

    // 1. Carregar contas de origem
    _contasOrigem = await db.query(
      SupabaseHelper.tableContasBancarias,
      where: 'usuario_id = ?',
      whereArgs: [origemId],
      orderBy: 'ordem ASC'
    );

    // 2. Carregar contas de destino
    _contasDestino = await db.query(
      SupabaseHelper.tableContasBancarias,
      where: 'usuario_id = ?',
      whereArgs: [destinoId],
      orderBy: 'ordem ASC'
    );

    // 3. Carregar métodos de pagamento globais
    _metodosOrigem = await db.query(
      SupabaseHelper.tableMetodosPagamento,
      orderBy: 'ordem ASC'
    );

    if (_contasOrigem.isNotEmpty) {
      _selectedContaOrigem = (_contasOrigem.first['id'] ?? _contasOrigem.first['ID'])?.toString();
      _updateMetodosParaContaOrigem();
    } else {
      _selectedContaOrigem = null;
      _selectedMetodoOrigem = null;
    }

    if (_contasDestino.isNotEmpty) {
      _selectedContaDestino = (_contasDestino.first['id'] ?? _contasDestino.first['ID'])?.toString();
    } else {
      _selectedContaDestino = null;
    }
  }

  void _swapUsers() async {
    if (_usuarioOrigem == null || _usuarioDestino == null) return;
    setState(() => _isLoading = true);

    final temp = _usuarioOrigem;
    _usuarioOrigem = _usuarioDestino;
    _usuarioDestino = temp;

    await _loadContasEMetodos();

    if (mounted) {
      setState(() => _isLoading = false);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invertido: ${_usuarioOrigem!['nome'] ?? _usuarioOrigem!['Nome']} agora transfere para ${_usuarioDestino!['nome'] ?? _usuarioDestino!['Nome']}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateMetodosParaContaOrigem() {
    if (_selectedContaOrigem == null) return;
    
    final cId = _selectedContaOrigem!.toLowerCase();
    
    final match = _metodosOrigem.where((m) {
      final contaId = (m['conta_id'] ?? m['Conta_ID'])?.toString().toLowerCase();
      final nome = (m['nome'] ?? m['Nome'] ?? '').toString().toLowerCase();
      return contaId == cId || nome.contains('pix');
    }).toList();

    setState(() {
      if (match.isNotEmpty) {
        _selectedMetodoOrigem = (match.first['id'] ?? match.first['ID'])?.toString();
      } else if (_metodosOrigem.isNotEmpty) {
        _selectedMetodoOrigem = (_metodosOrigem.first['id'] ?? _metodosOrigem.first['ID'])?.toString();
      } else {
        _selectedMetodoOrigem = null;
      }
    });
  }

  Future<void> _confirmTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    final valor = _getParsedValor();
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O valor da transferência deve ser maior que zero.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedContaOrigem == null || _selectedContaDestino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione as contas de origem e destino.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await SupabaseHelper.instance.database;

      // 1. Buscar ou criar categoria "Transferência"
      final cats = await db.query(SupabaseHelper.tableCategorias);
      String? categoriaId;
      
      final matchCat = cats.where((c) {
        final nome = (c['nome'] ?? c['Nome'] ?? '').toString().toLowerCase();
        return nome == 'transferência' || nome == 'transferencia' || nome == 'transferência familiar';
      }).toList();

      if (matchCat.isNotEmpty) {
        categoriaId = (matchCat.first['id'] ?? matchCat.first['ID']).toString();
      } else {
        categoriaId = await db.insert(SupabaseHelper.tableCategorias, {
          'Nome': 'Transferência',
          'Cor_Hexadecimal': '#9E9E9E',
          'Tipo': 'Ambas',
          'Oculta': 0,
          'Ordem': 99,
        });
      }

      final String transferUuid = const Uuid().v4();
      final dateStr = _selectedDate.toIso8601String();
      final origemId = (_usuarioOrigem!['id'] ?? _usuarioOrigem!['ID']).toString();
      final destinoId = (_usuarioDestino!['id'] ?? _usuarioDestino!['ID']).toString();
      final origemNome = _usuarioOrigem!['nome'] ?? _usuarioOrigem!['Nome'] ?? 'Remetente';
      final destinoNome = _usuarioDestino!['nome'] ?? _usuarioDestino!['Nome'] ?? 'Destinatário';

      final List<Map<String, dynamic>> users = await db.query(SupabaseHelper.tableUsuarios);
      final origemUser = users.firstWhere((u) => (u['id'] ?? u['ID']).toString() == origemId, orElse: () => _usuarioOrigem!);
      final destinoUser = users.firstWhere((u) => (u['id'] ?? u['ID']).toString() == destinoId, orElse: () => _usuarioDestino!);
      final String? authIdOrigem = (origemUser['auth_id'] ?? origemUser['Auth_ID'])?.toString();
      final String? authIdDestino = (destinoUser['auth_id'] ?? destinoUser['Auth_ID'])?.toString();

      // 3. Criar a Despesa (Saída)
      final despesaFuture = db.insert(SupabaseHelper.tableTransacoes, {
        'Data': dateStr,
        'Descricao': '${_descricaoController.text} para $destinoNome',
        'Valor': valor,
        'Tipo': 'Despesa',
        'Usuario_ID': origemId,
        'Conta_ID': _selectedContaOrigem!,
        'Metodo_ID': _selectedMetodoOrigem,
        'Categoria_ID': categoriaId,
        'Paga': 1,
        'transferencia_id': transferUuid,
        'auth_id': authIdOrigem,
      });

      // 4. Buscar método de pagamento Pix do destinatário para a receita
      String? metodoDestinoId;
      try {
        final metodosDest = await db.query(
          SupabaseHelper.tableMetodosPagamento,
          where: 'conta_id = ?',
          whereArgs: [_selectedContaDestino],
        );
        final matchMet = metodosDest.where((m) {
          final nome = (m['nome'] ?? m['Nome'] ?? '').toString().toLowerCase();
          return nome.contains('pix');
        }).toList();
        if (matchMet.isNotEmpty) {
          metodoDestinoId = (matchMet.first['id'] ?? matchMet.first['ID'])?.toString();
        } else if (metodosDest.isNotEmpty) {
          metodoDestinoId = (metodosDest.first['id'] ?? metodosDest.first['ID'])?.toString();
        }
      } catch (err) {
        debugPrint('Erro ao buscar método de pagamento do destinatário: $err');
      }

      // 5. Criar a Receita (Entrada)
      final receitaFuture = db.insert(SupabaseHelper.tableTransacoes, {
        'Data': dateStr,
        'Descricao': '${_descricaoController.text} de $origemNome',
        'Valor': valor,
        'Tipo': 'Receita',
        'Usuario_ID': destinoId,
        'Conta_ID': _selectedContaDestino!,
        'Metodo_ID': metodoDestinoId,
        'Categoria_ID': categoriaId,
        'Paga': 1,
        'transferencia_id': transferUuid,
        'auth_id': authIdDestino,
      });

      await Future.wait([despesaFuture, receitaFuture]);
      ref.refresh(dashboardDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transferência realizada com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Erro ao realizar transferência: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao transferir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildUserAvatarCard({
    required String title,
    required String name,
    required Color color,
    required bool isSender,
  }) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Draggable<String>(
      data: isSender ? 'SENDER' : 'RECEIVER',
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(backgroundColor: Colors.white, radius: 14, child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildAvatarColumn(title, initial, name, color),
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => (details.data == 'SENDER' && !isSender) || (details.data == 'RECEIVER' && isSender),
        onAcceptWithDetails: (details) => _swapUsers(),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: isHovering ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isHovering ? color : Colors.transparent, width: 2),
            ),
            child: _buildAvatarColumn(title, initial, name, color),
          );
        },
      ),
    );
  }

  Widget _buildAvatarColumn(String title, String initial, String name, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.2),
          child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transferir Valor entre Contas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final origemNome = _usuarioOrigem!['nome'] ?? _usuarioOrigem!['Nome'] ?? 'Remetente';
    final destinoNome = _usuarioDestino!['nome'] ?? _usuarioDestino!['Nome'] ?? 'Destinatário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferir Valor entre Contas'),
        actions: const [TutorialButton(screen: TutorialScreens.familyTransfer)],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cards de Origem <-> Destino com Drag and Drop e Botão Swap
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildUserAvatarCard(
                              title: 'REMETENTE',
                              name: origemNome,
                              color: Colors.blueAccent,
                              isSender: true,
                            ),
                          ),
                          // Botão central de inverter com clique ou arrasto
                          InkWell(
                            key: TutorialKeys.familyTransferSwapButton,
                            onTap: _swapUsers,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.swap_horiz_rounded, color: Colors.greenAccent, size: 26),
                            ),
                          ),
                          Expanded(
                            child: _buildUserAvatarCard(
                              title: 'DESTINATÁRIO',
                              name: destinoNome,
                              color: Colors.tealAccent,
                              isSender: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toque ou arraste para inverter',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Valor da Transferência
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Valor da Transferência',
                    labelStyle: TextStyle(fontSize: 15, color: AppColors.secondaryText(context)),
                    prefixText: 'R\$ ',
                    prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Digite o valor';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Conta Origem
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 280,
                  value: _contasOrigem.any((c) => (c['id'] ?? c['ID'])?.toString() == _selectedContaOrigem) 
                      ? _selectedContaOrigem 
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Sair da Conta (Origem)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  items: _contasOrigem.map((c) => DropdownMenuItem<String>(
                    value: (c['id'] ?? c['ID'])?.toString(),
                    child: Text((c['nome'] ?? c['Nome'] ?? 'Sem Conta').toString()),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedContaOrigem = val;
                      _updateMetodosParaContaOrigem();
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Método Origem
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedContaOrigem),
                  isExpanded: true,
                  menuMaxHeight: 280,
                  value: _metodosOrigem.where((m) {
                    final contaId = (m['conta_id'] ?? m['Conta_ID'])?.toString().toLowerCase();
                    final nome = (m['nome'] ?? m['Nome'] ?? '').toString().toLowerCase();
                    return _selectedContaOrigem == null || 
                           contaId == _selectedContaOrigem!.toLowerCase() || 
                           nome.contains('pix');
                  }).any((m) => (m['id'] ?? m['ID'])?.toString() == _selectedMetodoOrigem) 
                      ? _selectedMetodoOrigem 
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Método Utilizado',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  items: _metodosOrigem.where((m) {
                    final contaId = (m['conta_id'] ?? m['Conta_ID'])?.toString().toLowerCase();
                    final nome = (m['nome'] ?? m['Nome'] ?? '').toString().toLowerCase();
                    return _selectedContaOrigem == null || 
                           contaId == _selectedContaOrigem!.toLowerCase() || 
                           nome.contains('pix');
                  }).map((m) => DropdownMenuItem<String>(
                    value: (m['id'] ?? m['ID'])?.toString(),
                    child: Text((m['nome'] ?? m['Nome'] ?? 'N/A').toString()),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedMetodoOrigem = val),
                ),
                const SizedBox(height: 20),

                // Conta Destino
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 280,
                  value: _contasDestino.any((c) => (c['id'] ?? c['ID'])?.toString() == _selectedContaDestino) 
                      ? _selectedContaDestino 
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Entrar na Conta (Destino)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  items: _contasDestino.map((c) => DropdownMenuItem<String>(
                    value: (c['id'] ?? c['ID'])?.toString(),
                    child: Text((c['nome'] ?? c['Nome'] ?? 'Sem Conta').toString()),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedContaDestino = val),
                ),
                const SizedBox(height: 20),

                // Descrição
                TextFormField(
                  controller: _descricaoController,
                  decoration: InputDecoration(
                    labelText: 'Observação (Opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 32),

                // Confirmar
                ElevatedButton(
                  onPressed: _isSaving ? null : _confirmTransfer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirmar Transferência', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
