import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/currency_formatter.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final int? transactionId;
  final String? initialDescricao;
  final double? initialValor;
  final List<int>? shoppingListItemIds;
  final bool forceDespesa;

  const TransactionFormScreen({
    super.key, 
    this.transactionId,
    this.initialDescricao,
    this.initialValor,
    this.shoppingListItemIds,
    this.forceDespesa = false,
  });

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

  int? _selectedUsuario;
  int? _selectedCategoria;
  int? _selectedConta;
  int? _selectedMetodo;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    final db = await DatabaseHelper.instance.database;
    final users = await db.query(DatabaseHelper.tableUsuarios, orderBy: 'Ordem ASC');
    final cats = await db.query(DatabaseHelper.tableCategorias, orderBy: 'Ordem ASC');
    final accounts = await db.query(DatabaseHelper.tableContasBancarias, orderBy: 'Ordem ASC');
    final metodos = await db.query(DatabaseHelper.tableMetodosPagamento, orderBy: 'Ordem ASC');

    Map<String, dynamic>? transactionToEdit;
    if (widget.transactionId != null) {
      final tRes = await db.query(DatabaseHelper.tableTransacoes, where: 'ID = ?', whereArgs: [widget.transactionId]);
      if (tRes.isNotEmpty) {
        transactionToEdit = tRes.first;
      }
    }

    setState(() {
      _usuarios = users;
      _categoriasAll = cats;
      _contas = accounts;
      _metodosAll = metodos;
      
      if (transactionToEdit != null) {
        _tipo = transactionToEdit['Tipo'];
        _descricaoController.text = transactionToEdit['Descricao'];
        
        // Formatar valor para o controller (assumindo que no banco está como double)
        double val = transactionToEdit['Valor'];
        // O CurrencyInputFormatter espera centavos inteiros se digitado, mas podemos setar a string manual
        _valorController.text = CurrencyFormatter.format(val);

        _selectedDate = DateTime.parse(transactionToEdit['Data']);
        _selectedUsuario = transactionToEdit['Usuario_ID'];
        _selectedConta = transactionToEdit['Conta_ID'];
        _selectedMetodo = transactionToEdit['Metodo_ID'];
        _selectedCategoria = transactionToEdit['Categoria_ID'];
        _isPaga = transactionToEdit['Paga'] == 1;
      } else {
        if (widget.forceDespesa) _tipo = 'Despesa';
        if (_usuarios.isNotEmpty) _selectedUsuario = _usuarios.first['ID'];
        if (_contas.isNotEmpty) _selectedConta = _contas.first['ID'];
        
        if (widget.initialDescricao != null) {
          _descricaoController.text = widget.initialDescricao!;
        }
        if (widget.initialValor != null) {
          _valorController.text = CurrencyFormatter.format(widget.initialValor!);
        }
      }

      _updateCategoriasAtivas();
      
      if (_contas.isNotEmpty) {
        _updateMetodosParaContaSelecionada(maintainSelection: transactionToEdit != null);
      }
      
      _isLoading = false;
    });
  }

  void _updateCategoriasAtivas() {
    _categoriasAtivas = _categoriasAll.where((c) {
      final tipoCat = c['Tipo'] ?? 'Ambas';
      return tipoCat == 'Ambas' || tipoCat == _tipo;
    }).toList();

    // Reset selection if current category is no longer valid
    if (_selectedCategoria != null) {
      final stillValid = _categoriasAtivas.any((c) => c['ID'] == _selectedCategoria);
      if (!stillValid) _selectedCategoria = null;
    }
    
    if (_selectedCategoria == null && _categoriasAtivas.isNotEmpty) {
      _selectedCategoria = _categoriasAtivas.first['ID'];
    }
  }

  void _updateMetodosParaContaSelecionada({bool maintainSelection = false}) {
    if (_selectedConta == null) return;
    _metodosAtuais = _metodosAll.where((m) => m['Conta_ID'] == _selectedConta).toList();
    
    if (!maintainSelection || _selectedMetodo == null) {
      if (_metodosAtuais.isNotEmpty) {
        _selectedMetodo = _metodosAtuais.first['ID'];
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
    
    final db = await DatabaseHelper.instance.database;
    
    // Converter de volta pra double
    final numericOnly = _valorController.text.replaceAll(RegExp('[^0-9]'), '');
    final valor = numericOnly.isEmpty ? 0.0 : double.parse(numericOnly) / 100;
    
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor deve ser maior que zero.')));
      return;
    }

    final dataStr = _selectedDate.toIso8601String();

    int? insertedId;

    if (widget.transactionId != null) {
      // EDIT MODE (Parcelamento não permitido em edição por simplificação)
      await db.update(DatabaseHelper.tableTransacoes, {
        'Data': dataStr,
        'Descricao': _descricaoController.text,
        'Valor': valor,
        'Tipo': _tipo,
        'Usuario_ID': _selectedUsuario,
        'Categoria_ID': _selectedCategoria,
        'Conta_ID': _selectedConta,
        'Metodo_ID': _selectedMetodo,
        'Paga': _isPaga ? 1 : 0,
      }, where: 'ID = ?', whereArgs: [widget.transactionId]);
      insertedId = widget.transactionId;
    } else {
      // NEW MODE
      if (_tipo == 'Despesa' && _isParcelado) {
        final valorParcela = valor / _parcelas;
        for (int i = 1; i <= _parcelas; i++) {
          final dataParcela = DateTime(_selectedDate.year, _selectedDate.month + (i - 1), _selectedDate.day).toIso8601String();
          final id = await db.insert(DatabaseHelper.tableTransacoes, {
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
            'Paga': i == 1 ? (_isPaga ? 1 : 0) : 0,
          });
          if (i == 1) insertedId = id; // Vincula os itens do carrinho à primeira parcela
        }
      } else {
        insertedId = await db.insert(DatabaseHelper.tableTransacoes, {
          'Data': dataStr,
          'Descricao': _descricaoController.text,
          'Valor': valor,
          'Tipo': _tipo,
          'Usuario_ID': _selectedUsuario,
          'Categoria_ID': _selectedCategoria,
          'Conta_ID': _selectedConta,
          'Metodo_ID': _selectedMetodo,
          'Paga': _isPaga ? 1 : 0,
        });
      }
    }

    // Vincular os itens do carrinho a esta transação
    if (insertedId != null && widget.shoppingListItemIds != null && widget.shoppingListItemIds!.isNotEmpty) {
      final placeholders = List.filled(widget.shoppingListItemIds!.length, '?').join(',');
      await db.update(
        DatabaseHelper.tableListaCompras, 
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
                    child: DropdownButtonFormField<int>(
                      value: _selectedUsuario,
                      decoration: InputDecoration(
                        labelText: _tipo == 'Receita' ? 'Quem Recebeu' : 'Quem Pagou',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: _usuarios.map((u) => DropdownMenuItem<int>(
                        value: u['ID'],
                        child: Text(u['Nome']),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedUsuario = val),
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
                    child: DropdownButtonFormField<int>(
                      value: _selectedCategoria,
                      decoration: InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: _categoriasAtivas.map((c) {
                        final colorHex = c['Cor_Hexadecimal'].toString().replaceAll('#', '0xFF');
                        return DropdownMenuItem<int>(
                          value: c['ID'],
                          child: Row(
                            children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: Color(int.parse(colorHex)), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(c['Nome']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoria = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedConta,
                      decoration: InputDecoration(
                        labelText: 'Conta Bancária',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: _contas.map((c) => DropdownMenuItem<int>(
                        value: c['ID'],
                        child: Text(c['Nome']),
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
              
              DropdownButtonFormField<int>(
                key: ValueKey(_selectedConta),
                value: _selectedMetodo,
                decoration: InputDecoration(
                  labelText: 'Método de Pagamento vinculado',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: _metodosAtuais.map((m) => DropdownMenuItem<int>(
                  value: m['ID'],
                  child: Text(m['Nome']),
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
