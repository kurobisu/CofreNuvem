import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/supabase_helper.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/currency_formatter.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoria != null) {
      _selectedCategoria = widget.initialCategoria;
    }
    _loadFormData();
  }

  Future<void> _loadFormData() async {
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

    setState(() {
      _usuarios = users;
      _categoriasAll = cats;
      _metodosAll = metodos;
      
      if (transactionToEdit != null) {
        _tipo = transactionToEdit['tipo'];
        _descricaoController.text = transactionToEdit['descricao'];
        
        // Formatar valor para o controller (assumindo que no banco está como double)
        double val = transactionToEdit['valor'];
        _valorController.text = CurrencyFormatter.format(val);

        _selectedDate = DateTime.parse(transactionToEdit['data']);
        _selectedUsuario = transactionToEdit['usuario_id'];
        _selectedConta = transactionToEdit['conta_id'];
        _selectedMetodo = transactionToEdit['metodo_id'];
        _selectedCategoria = transactionToEdit['categoria_id'];
        _isPaga = transactionToEdit['paga'] == 1;
      } else {
        if (widget.forceDespesa) _tipo = 'Despesa';
        if (_usuarios.isNotEmpty) _selectedUsuario = _usuarios.first['id'];
        
        if (widget.initialDescricao != null) {
          _descricaoController.text = widget.initialDescricao!;
        }
        if (widget.initialValor != null) {
          _valorController.text = CurrencyFormatter.format(widget.initialValor!);
        }
      }

      _updateCategoriasAtivas();
    });
    
    await _updateContasParaUsuario(maintainSelection: transactionToEdit != null);
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateContasParaUsuario({bool maintainSelection = false}) async {
    if (_selectedUsuario == null) return;
    final db = await SupabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT c.* FROM ${SupabaseHelper.tableContasBancarias} c
      WHERE c.Usuario_ID = ?
      UNION
      SELECT c.* FROM ${SupabaseHelper.tableContasBancarias} c
      JOIN ${SupabaseHelper.tableContasCompartilhadas} cc ON c.ID = cc.Conta_ID
      WHERE cc.Usuario_ID = ?
      ORDER BY Ordem ASC
    ''', [_selectedUsuario, _selectedUsuario]);
    
    setState(() {
      _contas = result;
      if (!maintainSelection || _selectedConta == null) {
        if (_contas.isNotEmpty) {
          _selectedConta = _contas.first['id'];
        } else {
          _selectedConta = null;
        }
      } else {
        final stillValid = _contas.any((c) => c['id'] == _selectedConta);
        if (!stillValid) _selectedConta = _contas.isNotEmpty ? _contas.first['id'] : null;
      }
      _updateMetodosParaContaSelecionada(maintainSelection: maintainSelection);
    });
  }

  void _updateCategoriasAtivas() {
    _categoriasAtivas = _categoriasAll.where((c) {
      final tipoCat = c['tipo'] ?? 'Ambas';
      return tipoCat == 'Ambas' || tipoCat == _tipo;
    }).toList();

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
    if (_selectedConta == null) return;
    _metodosAtuais = _metodosAll.where((m) => m['conta_id'] == _selectedConta).toList();
    
    if (!maintainSelection || _selectedMetodo == null) {
      if (_metodosAtuais.isNotEmpty) {
        _selectedMetodo = _metodosAtuais.first['id'];
      } else {
        _selectedMetodo = null;
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
    
    final db = await SupabaseHelper.instance.database;
    
    // Converter de volta pra double
    final numericOnly = _valorController.text.replaceAll(RegExp('[^0-9]'), '');
    final valor = numericOnly.isEmpty ? 0.0 : double.parse(numericOnly) / 100;
    
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor deve ser maior que zero.')));
      return;
    }

    final selectedMetodoData = _metodosAll.firstWhere((m) => m['id'] == _selectedMetodo, orElse: () => {});
    final isCredit = selectedMetodoData['tipo'] == 'Crédito';
    final int finalPaga = isCredit ? 0 : (_isPaga ? 1 : 0);
    
    DateTime dataTransacao = _selectedDate;
    if (isCredit) {
      final diaFechamento = int.tryParse(selectedMetodoData['dia_fechamento']?.toString() ?? '') ?? 1;
      final diaVencimento = int.tryParse(selectedMetodoData['dia_vencimento']?.toString() ?? '') ?? 10;
      
      int mesFatura = dataTransacao.month;
      int anoFatura = dataTransacao.year;
      
      if (dataTransacao.day >= diaFechamento) {
        mesFatura++;
      }
      
      // Caso dia_vencimento < dia_fechamento, geralmente significa que o vencimento cai no mês seguinte fisicamente
      if (diaVencimento < diaFechamento) {
        mesFatura++;
      }

      dataTransacao = DateTime(anoFatura, mesFatura, diaVencimento);
    }
    
    final dataStr = dataTransacao.toIso8601String();
    String? insertedId;
    final String groupId = DateTime.now().millisecondsSinceEpoch.toString();

    if (widget.transactionId != null) {
      // EDIT MODE (Parcelamento não permitido em edição por simplificação)
      await db.update(SupabaseHelper.tableTransacoes, {
        'Data': dataStr,
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
        final valorParcela = valor / _parcelas;
        for (int i = 1; i <= _parcelas; i++) {
          final dataParcela = DateTime(_selectedDate.year, _selectedDate.month + (i - 1), _selectedDate.day).toIso8601String();
          final id = await db.insert(SupabaseHelper.tableTransacoes, {
            'Data': dataParcela,
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
          if (i == 1) insertedId = id; // Vincula os itens do carrinho à primeira parcela
        }
      } else {
        insertedId = await db.insert(SupabaseHelper.tableTransacoes, {
          'Data': dataStr,
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

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedCategoria,
                      decoration: InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: _categoriasAtivas.map((c) {
                        final colorHex = c['cor_hexadecimal'].toString().replaceAll('#', '0xFF');
                        return DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Row(
                            children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: Color(int.parse(colorHex)), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c['nome'], maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoria = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedConta,
                      decoration: InputDecoration(
                        labelText: 'Conta Bancária',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: _contas.map((c) => DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(c['nome'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedConta = val;
                          _updateMetodosParaContaSelecionada();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedConta),
                isExpanded: true,
                value: _selectedMetodo,
                decoration: InputDecoration(
                  labelText: 'Método de Pagamento vinculado',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: _metodosAtuais.map((m) => DropdownMenuItem<String>(
                  value: m['id'].toString(),
                  child: Text(m['nome'], maxLines: 1, overflow: TextOverflow.ellipsis),
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
                CheckboxListTile(
                  title: const Text('Compra Parcelada?'),
                  value: _isParcelado,
                  onChanged: (val) => setState(() => _isParcelado = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                if (_isParcelado)
                  Row(
                    children: [
                      const Text('Número de Parcelas: '),
                      Expanded(
                        child: Slider(
                          value: _parcelas.toDouble(),
                          min: 2,
                          max: 24,
                          divisions: 22,
                          label: _parcelas.toString(),
                          onChanged: (val) => setState(() => _parcelas = val.toInt()),
                        ),
                      ),
                    ],
                  ),
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
