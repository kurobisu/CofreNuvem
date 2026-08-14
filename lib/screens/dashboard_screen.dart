import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/bancos_brasil.dart';
import '../theme/app_theme.dart';
import '../database/supabase_helper.dart';
import 'invoices_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transaction_form_screen.dart';
import 'family_transfer_screen.dart';
import '../utils/transaction_helper.dart';
import '../utils/app_version.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsyncValue = ref.watch(dashboardDataProvider);
    final isBalanceHidden = ref.watch(hideBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral $appVersion', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(isBalanceHidden ? Icons.visibility_off : Icons.visibility),
            tooltip: isBalanceHidden ? 'Mostrar Saldos' : 'Ocultar Saldos',
            onPressed: () => ref.read(hideBalanceProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Relatórios Avançados',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dashboardAsyncValue.when(
        data: (data) {
          final totalBalance = data['totalBalance'] as double;
          final userBalances = data['userBalances'] as List<Map<String, dynamic>>;
          final categoryExpenses = data['categoryExpenses'] as List<Map<String, dynamic>>;
          final recentTransactions = data['recentTransactions'] as List<Map<String, dynamic>>;
          final creditCards = (data['creditCards'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.refresh(dashboardDataProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Supabase.instance.client.auth.currentUser != null && Supabase.instance.client.auth.currentUser!.emailConfirmedAt == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Por segurança, verifique seu e-mail clicando no link que enviamos para você.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildTotalBalanceCard(context, totalBalance, isBalanceHidden),
                  const SizedBox(height: 24),
                  _buildUserBalancesList(userBalances, isBalanceHidden),
                  const SizedBox(height: 24),
                  if (creditCards.isNotEmpty) ...[
                    _buildCreditCardsRow(context, creditCards),
                    const SizedBox(height: 24),
                  ],
                  _buildRecentTransactions(context, ref, recentTransactions),
                  const SizedBox(height: 120), // padding for FAB/BottomNav
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar dados: $err')),
      ),
    );
  }

  Widget _buildTotalBalanceCard(BuildContext context, double totalBalance, bool isHidden) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Familiar Total',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            isHidden ? 'R\$ ••••••' : CurrencyFormatter.format(totalBalance),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBalancesList(List<Map<String, dynamic>> userBalances, bool isHidden) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userBalances.length,
      itemBuilder: (context, index) {
        final ub = userBalances[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: () => _showUserReportModal(context, ub['id'].toString(), ub['nome'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.accent.withOpacity(0.2),
                    child: Text(
                      ub['nome'].toString().substring(0, 1),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ub['nome'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'R\$ ••••••' : CurrencyFormatter.format(ub['saldo']),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreditCardsRow(BuildContext context, List<Map<String, dynamic>> creditCards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cartões & Faturas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: creditCards.length,
            itemBuilder: (context, index) {
              final card = creditCards[index];
              final double pct = (card['Porcentagem_Uso'] as num?)?.toDouble() ?? 0.0;
              final double totalUsado = (card['Total_Usado'] as num?)?.toDouble() ?? 0.0;
              final double? limite = (card['Limite_Credito'] as num?)?.toDouble();

              // Cor do progresso baseado no nível de uso
              Color progressColor = Colors.tealAccent.withOpacity(0.35);
              if (pct > 0.8) {
                progressColor = Colors.redAccent.withOpacity(0.45);
              } else if (pct > 0.5) {
                progressColor = Colors.orangeAccent.withOpacity(0.4);
              }

              return Container(
                width: 155,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoicesScreen(metodo: card))),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: pct > 0.8 ? Colors.redAccent.withOpacity(0.5) : AppTheme.accent.withOpacity(0.3),
                        width: pct > 0.8 ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Barra/Preenchimento de fundo proporcional ao uso do limite
                        if (limite != null && limite > 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 155 * pct,
                            child: Container(
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.horizontal(
                                  left: const Radius.circular(14),
                                  right: pct >= 0.98 ? const Radius.circular(14) : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.credit_card, 
                                    color: pct > 0.8 ? Colors.redAccent : AppTheme.accent, 
                                    size: 18
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      (card['BancoNome'] ?? card['bancoNome'] ?? 'Banco').toString(), 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                  ),
                                  if (limite != null && limite > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (pct > 0.8 ? Colors.redAccent : Colors.tealAccent).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${(pct * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: pct > 0.8 ? Colors.redAccent : Colors.tealAccent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                (card['Nome'] ?? card['nome'] ?? 'Cartão').toString(), 
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis
                              ),
                              const SizedBox(height: 2),
                              if (limite != null && limite > 0) ...[
                                Text(
                                  '${CurrencyFormatter.format(totalUsado)} / ${CurrencyFormatter.format(limite)}',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w700,
                                    color: pct > 0.8 ? Colors.redAccent : (pct > 0.5 ? Colors.orangeAccent : Colors.white),
                                    shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${card['UsuarioNome'] ?? ''} • Fecha dia ${card['Dia_Fechamento'] ?? card['dia_fechamento'] ?? 'N/A'}', 
                                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade300, fontWeight: FontWeight.w500), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ] else
                                Text(
                                  '${card['UsuarioNome'] ?? ''} • Fecha dia ${card['Dia_Fechamento'] ?? card['dia_fechamento'] ?? 'N/A'}', 
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade300, fontWeight: FontWeight.w500), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref, String id) async {
    await TransactionHelper.deleteTransactionWithConfirmation(context, id, ref, () {
      ref.refresh(dashboardDataProvider);
    });
  }

  Future<void> _showReceiptModal(BuildContext context, String transacaoId, String transacaoTitle) async {
    final db = await SupabaseHelper.instance.database;
    final items = await db.query(SupabaseHelper.tableListaCompras, where: 'Transacao_ID = ?', whereArgs: [transacaoId]);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.receipt_long, size: 48, color: Colors.green),
                const SizedBox(height: 8),
                Text('Cupom Fiscal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(transacaoTitle, style: const TextStyle(color: Colors.grey)),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final preco = (item['Preco'] ?? item['preco'] ?? 0) as num;
                      final qtde = (item['Quantidade'] ?? item['quantidade'] ?? 1) as num;
                      final total = preco * qtde;
                      return ListTile(
                        title: Text(item['Nome'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${qtde.toString().replaceAll('.0', '')}x de ${CurrencyFormatter.format(preco.toDouble())}'),
                        trailing: Text(CurrencyFormatter.format(total.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransactionOptions(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetContext) {
        final transferId = t['transferencia_id'] ?? t['Transferencia_ID'];
        final isTransfer = transferId != null && transferId.toString().isNotEmpty && transferId.toString() != 'null';

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(t['Descricao'] ?? t['descricao'] ?? 'Sem Descrição', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Opções da Transação', style: TextStyle(color: Colors.grey)),
              const Divider(),
              if ((t['HasItems'] ?? 0) > 0)
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: const Text('Ver Cupom Fiscal (Itens da Compra)'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showReceiptModal(context, t['id'] ?? t['ID'], t['Descricao'] ?? t['descricao'] ?? '');
                  },
                ),
              if (isTransfer)
                ListTile(
                  leading: Icon((t['tipo'] ?? t['Tipo']) == 'Receita' ? Icons.undo : Icons.redo, color: Colors.orange),
                  title: Text((t['tipo'] ?? t['Tipo']) == 'Receita' ? 'Devolver Valor' : 'Recuperar Valor'),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    // Mostra um loading rápido enquanto busca a outra ponta
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    try {
                      final db = await SupabaseHelper.instance.database;
                      // Buscar a transação irmã com o mesmo transferencia_id diretamente pelo Supabase Client
                      final supabase = Supabase.instance.client;
                      final response = await supabase
                          .from('transacoes')
                          .select()
                          .eq('transferencia_id', transferId)
                          .filter('deleted_at', 'is', null);
                      
                      final irmaos = List<Map<String, dynamic>>.from(response as List);
                      
                      if (!context.mounted) return;
                      Navigator.pop(context); // Remove o loading dialog
                      
                      if (irmaos.length >= 2) {
                        // Identificar quem enviou (Despesa) e quem recebeu (Receita) na transação original
                        final despesaOrig = irmaos.firstWhere((x) => (x['tipo'] ?? x['Tipo']) == 'Despesa');
                        final receitaOrig = irmaos.firstWhere((x) => (x['tipo'] ?? x['Tipo']) == 'Receita');
                        
                        final novoDestinatarioId = despesaOrig['usuario_id'] ?? despesaOrig['Usuario_ID'];
                        final novoRemetenteId = receitaOrig['usuario_id'] ?? receitaOrig['Usuario_ID'];
                        
                        final contaOrigemDevolucao = receitaOrig['conta_id'] ?? receitaOrig['Conta_ID'];
                        final contaDestinoDevolucao = despesaOrig['conta_id'] ?? despesaOrig['Conta_ID'];
                        final valorDevolucao = ((despesaOrig['valor'] ?? despesaOrig['Valor'] ?? 0) as num).toDouble();
                        
                        // Buscar o nome do novo destinatário
                        final destUserList = await db.query(SupabaseHelper.tableUsuarios, where: 'id = ?', whereArgs: [novoDestinatarioId]);
                        final destUserName = destUserList.isNotEmpty ? (destUserList.first['nome'] ?? destUserList.first['Nome'] ?? 'Usuário') : 'Usuário';

                        if (!context.mounted) return;
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FamilyTransferScreen(
                              sourceUserId: novoRemetenteId.toString(),
                              targetUserId: novoDestinatarioId.toString(),
                              targetUserName: destUserName.toString(),
                              initialValor: valorDevolucao,
                              initialContaOrigem: contaOrigemDevolucao?.toString(),
                              initialContaDestino: contaDestinoDevolucao?.toString(),
                            ),
                          ),
                        ).then((_) => ref.refresh(dashboardDataProvider));
                      } else {
                        // Heurística de Fallback caso RLS bloqueie a leitura da outra ponta ou o banco não retorne
                        final singleTx = irmaos.isNotEmpty ? irmaos.first : t;
                        final tipoTx = singleTx['tipo'] ?? singleTx['Tipo'];
                        final desc = (singleTx['descricao'] ?? singleTx['Descricao'] ?? '').toString();
                        final valorDevolucao = ((singleTx['valor'] ?? singleTx['Valor'] ?? 0) as num).toDouble();
                        
                        String targetName = '';
                        if (tipoTx == 'Despesa') {
                          // Descrição: "Transferência Familiar para Maria" -> extrair "Maria"
                          if (desc.contains('para ')) {
                            targetName = desc.split('para ').last.trim();
                          }
                        } else {
                          // Descrição: "Transferência Familiar de Clovis" -> extrair "Clovis"
                          if (desc.contains('de ')) {
                            targetName = desc.split('de ').last.trim();
                          }
                        }
                        
                        // Buscar o usuário pelo nome extraído
                        final db = await SupabaseHelper.instance.database;
                        final matchUsers = await db.query(
                          SupabaseHelper.tableUsuarios,
                          where: 'nome = ?',
                          whereArgs: [targetName],
                        );
                        
                        if (matchUsers.isEmpty) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erro: Não foi possível localizar o usuário de destino no banco.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        
                        final targetUser = matchUsers.first;
                        final targetUserId = targetUser['id'] ?? targetUser['ID'];
                        final targetUserName = targetUser['nome'] ?? targetUser['Nome'];
                        
                        final String logadoId = (singleTx['usuario_id'] ?? singleTx['Usuario_ID']).toString();
                        
                        String? sourceUserId;
                        String actualTargetUserId = '';
                        String actualTargetUserName = '';
                        String? initialContaOrigem;
                        String? initialContaDestino;

                        if (tipoTx == 'Despesa') {
                          // Remetente do estorno: Maria
                          sourceUserId = targetUserId.toString();
                          // Destinatário do estorno: Clovis (logado)
                          actualTargetUserId = logadoId;
                          actualTargetUserName = 'Usuário'; // Será resolvido na inicialização da tela
                          initialContaDestino = (singleTx['conta_id'] ?? singleTx['Conta_ID'])?.toString();
                        } else {
                          // Remetente do estorno: Maria (logada)
                          sourceUserId = logadoId;
                          // Destinatário do estorno: Clovis
                          actualTargetUserId = targetUserId.toString();
                          actualTargetUserName = targetUserName.toString();
                          initialContaOrigem = (singleTx['conta_id'] ?? singleTx['Conta_ID'])?.toString();
                        }
                        
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FamilyTransferScreen(
                              sourceUserId: sourceUserId,
                              targetUserId: actualTargetUserId,
                              targetUserName: actualTargetUserName,
                              initialValor: valorDevolucao,
                              initialContaOrigem: initialContaOrigem,
                              initialContaDestino: initialContaDestino,
                            ),
                          ),
                        ).then((_) => ref.refresh(dashboardDataProvider));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Garante fechar o loading em caso de erro
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao buscar dados: $e')),
                        );
                      }
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Editar Transação'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionFormScreen(transactionId: t['id'] ?? t['ID']),
                      ),
                    ).then((_) => ref.refresh(dashboardDataProvider));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Excluir Transação'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Excluir Transação?'),
                      content: const Text('Esta ação não pode ser desfeita.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteTransaction(context, ref, (t['id'] ?? t['ID']).toString());
                          },
                          child: const Text('Excluir'),
                        )
                      ],
                    )
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Últimas Transações', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/history'), 
              child: const Text('Ver tudo')
            ),
          ],
        ),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhuma transação registrada')),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isReceita = t['Tipo'] == 'Receita';
              final isPaga = t['Paga'] == 1;
              
              final bancoCode = t['Codigo_Banco']?.toString() ?? '999';
              final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
              final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: isPaga ? null : BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 12, spreadRadius: 1),
                  ],
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isPaga ? BorderSide.none : const BorderSide(color: Colors.orange, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showTransactionOptions(context, ref, t),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: bancoColor, borderRadius: BorderRadius.circular(12)),
                            child: Icon(banco.iconData ?? Icons.account_balance, color: Colors.white, size: 24),
                          ),
                          if (!isPaga)
                            Positioned(
                              right: -2, top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.warning, color: Colors.orange, size: 14),
                              ),
                            )
                        ],
                      ),
                      title: Text(t['Descricao'] ?? t['descricao'] ?? 'Sem Descrição', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${t['CategoriaNome'] ?? 'Sem Categoria'} • ${banco.nome} (${t['MetodoNome'] ?? ''})'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isReceita ? '+' : '-'} ${CurrencyFormatter.format(t['Valor'])}',
                            style: TextStyle(
                              color: isReceita ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (!isPaga)
                            const Text('Pendente', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showUserReportModal(BuildContext context, String userId, String userName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchUserReport(userId),
          builder: (context, snapshot) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Relatório • $userName', 
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Fechar a modal atual de relatório
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FamilyTransferScreen(
                                  targetUserId: userId,
                                  targetUserName: userName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.swap_horiz, color: Colors.greenAccent, size: 20),
                          label: const Text('Transferir', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.15),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                            ? Center(child: Text('Erro: ${snapshot.error}'))
                            : _buildReportContent(context, snapshot.data ?? []),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserReport(String userId) async {
    try {
      final supabase = SupabaseHelper.instance.client;
      final transacoes = await supabase
          .from('transacoes')
          .select('valor, tipo, contas_bancarias(nome, codigo_banco), metodos_pagamento(nome)')
          .eq('usuario_id', userId)
          .eq('paga', 1)
          .filter('deleted_at', 'is', null);

      Map<String, Map<String, dynamic>> groups = {};
      for (var t in transacoes) {
        String cNome = t['contas_bancarias']?['nome'] ?? 'Sem Conta';
        String cCod = t['contas_bancarias']?['codigo_banco'] ?? '';
        String mNome = t['metodos_pagamento']?['nome'] ?? 'Sem Método';
        String tipo = t['tipo'] ?? '';
        double val = (t['valor'] as num?)?.toDouble() ?? 0.0;
        
        String key = '$cNome-$mNome-$tipo';
        if (!groups.containsKey(key)) {
          groups[key] = {
            'ContaNome': cNome,
            'Codigo_Banco': cCod,
            'MetodoNome': mNome,
            'Tipo': tipo,
            'Total': 0.0,
          };
        }
        groups[key]!['Total'] += val;
      }

      final result = groups.values.toList();
      result.sort((a, b) {
        int c1 = a['ContaNome'].compareTo(b['ContaNome']);
        if (c1 != 0) return c1;
        int c2 = a['MetodoNome'].compareTo(b['MetodoNome']);
        if (c2 != 0) return c2;
        return a['Tipo'].compareTo(b['Tipo']);
      });
      
      return result;
    } catch (e) {
      debugPrint('Erro ao buscar relatorio de usuario: $e');
      return [];
    }
  }

  Widget _buildReportContent(BuildContext context, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const Center(child: Text('Nenhuma movimentação encontrada.'));

    Map<String, List<Map<String, dynamic>>> groupedByAccount = {};
    double totalDespesas = 0.0;
    Map<String, double> metodosTotals = {};

    for (var row in data) {
      String account = row['ContaNome'];
      if (!groupedByAccount.containsKey(account)) {
        groupedByAccount[account] = [];
      }
      groupedByAccount[account]!.add(row);

      if (row['Tipo'] == 'Despesa') {
        totalDespesas += row['Total'];
        String met = row['MetodoNome'];
        metodosTotals[met] = (metodosTotals[met] ?? 0.0) + row['Total'];
      }
    }

    final List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    int colorIdx = 0;

    return CustomScrollView(
      slivers: [
        if (totalDespesas > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 0,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Consumo por Método', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: metodosTotals.entries.map((e) {
                              final double pct = (e.value / totalDespesas) * 100;
                              final c = colors[colorIdx++ % colors.length];
                              return PieChartSectionData(
                                color: c,
                                value: e.value,
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 45,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: () {
                          int i = 0;
                          return metodosTotals.entries.map((e) {
                            final c = colors[i++ % colors.length];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(e.key, style: const TextStyle(fontSize: 12)),
                              ],
                            );
                          }).toList();
                        }(),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              String accountName = groupedByAccount.keys.elementAt(index);
              List<Map<String, dynamic>> items = groupedByAccount[accountName]!;
              
              final bancoCode = items.first['Codigo_Banco']?.toString() ?? '999';
              final banco = BancosBrasil.obterBancoPorCodigo(bancoCode);
              final bancoColor = Color(int.parse(banco.colorHex.replaceAll('#', '0xFF')));

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: bancoColor.withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            Icon(banco.iconData ?? Icons.account_balance, color: bancoColor),
                            const SizedBox(width: 8),
                            Text(accountName, style: TextStyle(fontWeight: FontWeight.bold, color: bancoColor, fontSize: 16)),
                          ],
                        ),
                      ),
                      ...items.map((row) {
                        bool isReceita = row['Tipo'] == 'Receita';
                        return ListTile(
                          title: Text(row['MetodoNome'], style: const TextStyle(fontSize: 16)),
                          trailing: Text(
                            (isReceita ? '+ ' : '- ') + CurrencyFormatter.format(row['Total']),
                            style: TextStyle(
                              color: isReceita ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            childCount: groupedByAccount.length,
          ),
        ),
      ],
    );
  }
}
