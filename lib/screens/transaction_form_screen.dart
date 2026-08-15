import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_helper.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_colors.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? initialDescricao;
  final double? initialValor;
  final List<String>? shoppingListItemIds;
  final bool forceDespesa;

  const TransactionFormScreen({
    super.key, 
    this.transactionId,
    this.initialDescricao,
    this.initialValor,
    this.initialCategoria,
    this.shoppingListItemIds,
    this.forceDespesa = false,
  });

  final String? initialCategoria;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _tipo = 'Despesa';
  bool _isParcelado = false;
  int _parcelas = 2;
  int _parcelaInicial = 1;
  bool _isPaga = true;

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _categoriasAll = [];
  List<Map<String, dynamic>> _categoriasAtivas = [];
  List<Map<String, dynamic>> _contas = [];
  List<Map<String, dynamic>> _metodosAll = [];
  List<Map<String, dynamic>> _metodosAtuais = [];

  String? _selectedUsuario;
  String? _selectedCategoria;
  String? _selectedConta;
  String? _selectedMetodo;

  bool _isLoading = true;

  double _getParsedValor() {
    final numericOnly = _valorController.text.replaceAll(RegExp('[^0-9]'), '');
    return numericOnly.isEmpty ? 0.0 : double.parse(numericOnly) / 100;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoria != null) {
      _selectedCategoria = widget.initialCategoria;
    }
    _valorController.addListener(() {
      if (_isParcelado && mounted) setState(() {});
    });
    _loadFormData();
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final db = await SupabaseHelper.instance.database;
      final users = await db.query(SupabaseHelper.tableUsuarios, orderBy: 'Ordem ASC');
      final cats = await db.query(SupabaseHelper.tableCategorias, orderBy: 'Ordem ASC');
      final metodos = await db.query(SupabaseHelper.tableMetodosPagamento, orderBy: 'Ordem ASC');

      Map<String, dynamic>? transactionToEdit;
      if (widget.transactionId != null) {
        final tRes = await db.query(SupabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [widget.transactionId]);
        if (tRes.isNotEmpty) {
          transactionToEdit = tRes.first;
        }
      }

      if (mounted) {
        setState(() {
          _usuarios = users;
          _categoriasAll = cats;
          _metodosAll = metodos;

          if (transactionToEdit != null) {
            _tipo = transactionToEdit['tipo'] ?? transactionToEdit['Tipo'] ?? 'Despesa';
            _descricaoController.text = transactionToEdit['descricao'] ?? transactionToEdit['Descricao'] ?? '';
            
            double val = ((transactionToEdit['valor'] ?? transactionToEdit['Valor'] ?? 0) as num).toDouble();
            _valorController.text = CurrencyFormatter.format(val);

            if (transactionToEdit['data'] != null || transactionToEdit['Data'] != null) {
              _selectedDate = DateTime.tryParse(transactionToEdit['data'] ?? transactionToEdit['Data']) ?? DateTime.now();
            }
            _selectedUsuario = transactionToEdit['usuario_id'] ?? transactionToEdit['Usuario_ID'];
            _selectedConta = transactionToEdit['conta_id'] ?? transactionToEdit['Conta_ID'];
            _selectedMetodo = transactionToEdit['metodo_id'] ?? transactionToEdit['Metodo_ID'];
            _selectedCategoria = transactionToEdit['categoria_id'] ?? transactionToEdit['Categoria_ID'];
            _isPaga = (transactionToEdit['paga'] ?? transactionToEdit['Paga']) == 1;
          } else {
            if (widget.forceDespesa) _tipo = 'Despesa';
            if (_usuarios.isNotEmpty) {
              final currentUserAuthId = Supabase.instance.client.auth.currentUser?.id;
              final currentUserName = Supabase.instance.client.auth.currentUser?.userMetadata?['nome']?.toString().toLowerCase();
              
              final match = _usuarios.where((u) {
                final uAuth = u['auth_id'] ?? u['Auth_ID'];
                final uNome = (u['nome'] ?? u['Nome'] ?? '').toString().toLowerCase();
                return uAuth == currentUserAuthId || 
                       (currentUserName != null && uNome == currentUserName);
              }).toList();
              _selectedUsuario = match.isNotEmpty ? (match.first['id'] ?? match.first['ID']) : (_usuarios.first['id'] ?? _usuarios.first['ID']);
            }
            
            if (widget.initialDescricao != null) {
              _descricaoController.text = widget.initialDescricao!;
            }
            if (widget.initialValor != null) {
              _valorController.text = CurrencyFormatter.format(widget.initialValor!);
            }
          }

          _updateCategoriasAtivas();
        });
      }
      
      await _updateContasParaUsuario(maintainSelection: transactionToEdit != null);
    } catch (e) {
      debugPrint('Erro _loadFormData: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateContasParaUsuario({bool maintainSelection = false}) async {
    if (_selectedUsuario == null) return;
    final db = await SupabaseHelper.instance.database;
    var result = await db.query(
      SupabaseHelper.tableContasBancarias,
      where: 'Usuario_ID = ?',
      whereArgs: [_selectedUsuario],
      orderBy: 'Ordem ASC'
    );

    if (result.isEmpty) {
      result = await db.query(
        SupabaseHelper.tableContasBancarias,
        orderBy: 'Ordem ASC'
      );
    }
    
    setState(() {
      _contas = result;
      if (!maintainSelection || _selectedConta == null) {
        if (_contas.isNotEmpty) {
          _selectedConta = (_contas.first['id'] ?? _contas.first['ID'])?.toString();
        } else {
          _selectedConta = null;
        }
      } else {
        final stillValid = _contas.any((c) => (c['id'] ?? c['ID'])?.toString() == _selectedConta?.toString());
        if (!stillValid) _selectedConta = _contas.isNotEmpty ? (_contas.first['id'] ?? _contas.first['ID'])?.toString() : null;
      }
      _updateMetodosParaContaSelecionada(maintainSelection: maintainSelection);
    });
  }

  void _updateCategoriasAtivas() {
    List<Map<String, dynamic>> structuredList = [];
    
    // Deduplica _categoriasAll por nome (case-insensitive) e parent_id
    final Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var c in _categoriasAll) {
      final name = (c['nome'] ?? c['Nome'] ?? '').toString().trim();
      final pId = (c['parent_id'] ?? c['Parent_ID'] ?? 'root').toString();
      final key = '${name.toLowerCase()}_$pId';
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = c;
      }
    }
    final cleanAll = uniqueMap.values.toList();

    // Pega apenas as categorias principais (sem parent_id)
    final parents = cleanAll.where((c) => c['parent_id'] == null || c['parent_id'] == 'null').toList();
    
    for (var p in parents) {
      final tipoCatP = (p['tipo']?.toString() ?? 'Ambas').trim();
      // Mostra a categoria pai se for do tipo certo (ou Ambas)
      if (tipoCatP == 'Ambas' || tipoCatP == _tipo) {
        structuredList.add(p);
        
        // Busca as subcategorias desse pai
        final children = cleanAll.where((c) => c['parent_id'] == p['id']).toList();
        for (var child in children) {
          final tipoCatC = (child['tipo']?.toString() ?? 'Ambas').trim();
          if (tipoCatC == 'Ambas' || tipoCatC == _tipo) {
            structuredList.add(child);
          }
        }
      }
    }

    _categoriasAtivas = structuredList;

    // Reset selection if current category is no longer valid
    if (_selectedCategoria != null) {
      final stillValid = _categoriasAtivas.any((c) => c['id'] == _selectedCategoria);
      if (!stillValid) _selectedCategoria = null;
    }
    
    if (_selectedCategoria == null && _categoriasAtivas.isNotEmpty) {
      _selectedCategoria = _categoriasAtivas.first['id'];
    }
  }

  void _updateMetodosParaContaSelecionada({bool maintainSelection = false}) {
    if (_selectedConta == null) {
      _metodosAtuais = List.from(_metodosAll);
      if (_metodosAtuais.isNotEmpty) {
        _selectedMetodo = (_metodosAtuais.first['id'] ?? _metodosAtuais.first['ID'])?.toString();
      } else {
        _selectedMetodo = null;
      }
      return;
    }

    final filtered = _metodosAll.where((m) {
      final cId = (m['conta_id'] ?? m['Conta_ID'])?.toString();
      return cId == null || cId == _selectedConta.toString();
    }).toList();

    _metodosAtuais = filtered.isNotEmpty ? filtered : List.from(_metodosAll);
    
    if (!maintainSelection || _selectedMetodo == null) {
      if (_metodosAtuais.isNotEmpty) {
        _selectedMetodo = (_metodosAtuais.first['id'] ?? _metodosAtuais.first['ID'])?.toString();
      } else {
        _selectedMetodo = null;
      }
    } else {
      final stillValid = _metodosAtuais.any((m) => (m['id'] ?? m['ID'])?.toString() == _selectedMetodo?.toString());
      if (!stillValid) {
        _selectedMetodo = _metodosAtuais.isNotEmpty ? (_metodosAtuais.first['id'] ?? _metodosAtuais.first['ID'])?.toString() : null;
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMetodo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um Método de Pagamento válido.')));
      return;
    }
    if (_selectedCategoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma Categoria.')));
      return;
    }
    try {
      final db = await SupabaseHelper.instance.database;
      
      // Converter de volta pra double
      final numericOnly = _valorController.text.replaceAll(RegExp('[^0-9]'), '');
      final valor = numericOnly.isEmpty ? 0.0 : double.parse(numericOnly) / 100;
      
      if (valor <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor deve ser maior que zero.')));
        return;
      }

      // Avoid runtime type error caused by firstWhere returning Map<String,dynamic> for a List<CaseInsensitiveMap>
      final selectedMetodoList = _metodosAll.where((m) => m['id'] == _selectedMetodo).toList();
      final selectedMetodoData = selectedMetodoList.isNotEmpty ? selectedMetodoList.first : {};
      
      final isCredit = selectedMetodoData['tipo'] == 'Crédito';
      final int finalPaga = isCredit ? 0 : (_isPaga ? 1 : 0);
      
      DateTime dataTransacao = _selectedDate;
      DateTime? dataFatura;

      if (isCredit) {
        final diaFechamento = int.tryParse(selectedMetodoData['dia_fechamento']?.toString() ?? '') ?? 1;
        final diaVencimento = int.tryParse(selectedMetodoData['dia_vencimento']?.toString() ?? '') ?? 10;
        
        int mesFatura = dataTransacao.month;
        int anoFatura = dataTransacao.year;
        
        if (dataTransacao.day >= diaFechamento) {
          mesFatura++;
        }
        
        if (diaVencimento < diaFechamento) {
          mesFatura++;
        }

        if (mesFatura > 12) {
          anoFatura += (mesFatura - 1) ~/ 12;
          mesFatura = (mesFatura - 1) % 12 + 1;
        }

        dataFatura = DateTime(anoFatura, mesFatura, diaVencimento);
      } else {
        dataFatura = dataTransacao;
      }
      
      final dataStr = dataTransacao.toIso8601String();
      final dataFaturaStr = dataFatura.toIso8601String();
      String? insertedId;
      final String groupId = DateTime.now().millisecondsSinceEpoch.toString();

      if (widget.transactionId != null) {
        // EDIT MODE
        await db.update(SupabaseHelper.tableTransacoes, {
          'Data': dataStr,
          'Data_Fatura': dataFaturaStr,
          'Descricao': _descricaoController.text,
          'Valor': valor,
          'Tipo': _tipo,
          'Usuario_ID': _selectedUsuario,
          'Categoria_ID': _selectedCategoria,
          'Conta_ID': _selectedConta,
          'Metodo_ID': _selectedMetodo,
          'Paga': finalPaga,
        }, where: 'ID = ?', whereArgs: [widget.transactionId]);
        insertedId = widget.transactionId;
      } else {
        // NEW MODE
        if (_tipo == 'Despesa' && _isParcelado) {
          final int remainingInstallments = _parcelas - _parcelaInicial + 1;
          final double valorParcela = valor / remainingInstallments;
          
          for (int i = _parcelaInicial; i <= _parcelas; i++) {
            final int offset = i - _parcelaInicial;
            final dataParcela = DateTime(_selectedDate.year, _selectedDate.month + offset, _selectedDate.day);
            
            DateTime faturaParcela;
            if (isCredit && dataFatura != null) {
              int mesP = dataFatura.month + offset;
              int anoP = dataFatura.year;
              if (mesP > 12) {
                anoP += (mesP - 1) ~/ 12;
                mesP = (mesP - 1) % 12 + 1;
              }
              faturaParcela = DateTime(anoP, mesP, dataFatura.day);
            } else {
              faturaParcela = dataParcela;
            }

            final id = await db.insert(SupabaseHelper.tableTransacoes, {
              'Data': dataParcela.toIso8601String(),
              'Data_Fatura': faturaParcela.toIso8601String(),
              'Descricao': '${_descricaoController.text} ($i/$_parcelas)',
              'Valor': valorParcela,
              'Tipo': _tipo,
              'Usuario_ID': _selectedUsuario,
              'Categoria_ID': _selectedCategoria,
              'Conta_ID': _selectedConta,
              'Metodo_ID': _selectedMetodo,
              'Parcela_Atual': i,
              'Parcela_Total': _parcelas,
              'Paga': finalPaga,
              'Grupo_Parcela_ID': groupId,
            });
            if (i == _parcelaInicial) insertedId = id; 
          }
        } else {
          insertedId = await db.insert(SupabaseHelper.tableTransacoes, {
            'Data': dataStr,
            'Data_Fatura': dataFaturaStr,
            'Descricao': _descricaoController.text,
            'Valor': valor,
            'Tipo': _tipo,
            'Usuario_ID': _selectedUsuario,
            'Categoria_ID': _selectedCategoria,
            'Conta_ID': _selectedConta,
            'Metodo_ID': _selectedMetodo,
            'Paga': finalPaga,
            'Grupo_Parcela_ID': groupId,
          });
        }
      }

      // Vincular os itens do carrinho a esta transação
      if (insertedId != null && widget.shoppingListItemIds != null && widget.shoppingListItemIds!.isNotEmpty) {
        final placeholders = List.filled(widget.shoppingListItemIds!.length, '?').join(',');
        await db.update(
          SupabaseHelper.tableListaCompras, 
          {'Transacao_ID': insertedId},
          where: 'ID IN ($placeholders)',
          whereArgs: widget.shoppingListItemIds,
        );
      }

      ref.refresh(dashboardDataProvider);

      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('Erro ao salvar transação: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId != null ? 'Editar Transação' : 'Nova Transação'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tipo Selector (Oculto se for forçado a ser Despesa, ex: Lista de Compras)
              if (!widget.forceDespesa) ...[
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Despesa', label: Text('Despesa'), icon: Icon(Icons.remove_circle_outline)),
                    ButtonSegment(value: 'Receita', label: Text('Receita'), icon: Icon(Icons.add_circle_outline)),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _tipo = newSelection.first;
                      _updateCategoriasAtivas();
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],
              
              TextFormField(
                controller: _valorController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Valor',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Informe o valor' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descricaoController,
                decoration: InputDecoration(
                  labelText: 'Descrição (Ex: Mercado Extra)',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v!.isEmpty ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUsuario,
                      decoration: InputDecoration(
                        labelText: _tipo == 'Receita' ? 'Quem Recebeu' : 'Quem Pagou',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: _usuarios.map((u) => DropdownMenuItem<String>(
                        value: u['id'].toString(),
                        child: Text(u['nome']),
                      )).toList(),
                      onChanged: (val) {
                        setState(() => _selectedUsuario = val);
                        _updateContasParaUsuario();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                isExpanded: true,
                menuMaxHeight: 280,
                value: _selectedCategoria,
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: _categoriasAtivas.map((c) {
                  final colorHex = c['cor_hexadecimal'].toString().replaceAll('#', '0xFF');
                  final isChild = c['parent_id'] != null;
                  
                  return DropdownMenuItem<String>(
                    value: c['id'].toString(),
                    child: Row(
                      children: [
                        if (isChild) const SizedBox(width: 16),
                        if (isChild) Icon(Icons.subdirectory_arrow_right, size: 16, color: AppColors.iconMuted(context)),
                        if (isChild) const SizedBox(width: 8),
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: Color(int.parse(colorHex)), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c['nome'], 
                            maxLines: 3, 
                            style: TextStyle(
                              fontWeight: isChild ? FontWeight.normal : FontWeight.bold,
                              color: isChild ? Colors.white70 : Colors.white,
                              fontSize: 14,
                            ),
                          )
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoria = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                menuMaxHeight: 280,
                value: _selectedConta,
                decoration: InputDecoration(
                  labelText: 'Conta Bancária',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: _contas.map((c) => DropdownMenuItem<String>(
                  value: (c['id'] ?? c['ID'])?.toString(),
                  child: Text((c['nome'] ?? c['Nome'] ?? 'Sem Conta').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedConta = val;
                    _updateMetodosParaContaSelecionada();
                  });
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedConta),
                isExpanded: true,
                menuMaxHeight: 280,
                value: _selectedMetodo,
                decoration: InputDecoration(
                  labelText: 'Método de Pagamento vinculado',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: _metodosAtuais.map((m) => DropdownMenuItem<String>(
                  value: (m['id'] ?? m['ID'])?.toString(),
                  child: Text((m['nome'] ?? m['Nome'] ?? 'Sem Método').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: _metodosAtuais.isEmpty ? null : (val) => setState(() => _selectedMetodo = val),
              ),

              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Transação Paga?'),
                subtitle: const Text('Desmarque se estiver pendente'),
                value: _isPaga,
                onChanged: (val) => setState(() => _isPaga = val),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              
              const SizedBox(height: 16),

              if (_tipo == 'Despesa' && widget.transactionId == null) ...[
                const SizedBox(height: 16),
                const Text('Forma de Pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('À Vista')),
                    ButtonSegment(value: true, label: Text('Parcelado')),
                  ],
                  selected: {_isParcelado},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() => _isParcelado = newSelection.first);
                  },
                ),
                if (_isParcelado) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Configuração de Parcelas', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const SizedBox(width: 80, child: Text('Total: ')),
                            Expanded(
                              child: Slider(
                                value: _parcelas.toDouble(),
                                min: 2,
                                max: 36,
                                divisions: 34,
                                label: '$_parcelas parcelas',
                                onChanged: (val) {
                                  setState(() {
                                    _parcelas = val.toInt();
                                    if (_parcelaInicial > _parcelas) _parcelaInicial = _parcelas;
                                  });
                                },
                              ),
                            ),
                            Text('$_parcelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 80, child: Text('Iniciando na: ')),
                            Expanded(
                              child: Slider(
                                value: _parcelaInicial.toDouble(),
                                min: 1,
                                max: _parcelas.toDouble(),
                                divisions: _parcelas > 1 ? _parcelas - 1 : 1,
                                label: 'Parcela $_parcelaInicial',
                                onChanged: (val) => setState(() => _parcelaInicial = val.toInt()),
                              ),
                            ),
                            Text('$_parcelaInicial', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final double totalValue = _getParsedValor();
                            final int numInstallments = _parcelas - _parcelaInicial + 1;
                            final double portion = totalValue / numInstallments;
                            return Text(
                              'O valor de ${CurrencyFormatter.format(totalValue)} será dividido em $numInstallments parcelas de ${CurrencyFormatter.format(portion)}.',
                              style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context)),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('SALVAR LANÇAMENTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
