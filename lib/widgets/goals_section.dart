import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/supabase_helper.dart';
import '../providers/goals_provider.dart';
import '../providers/dashboard_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/goal_projection.dart';
import '../utils/app_colors.dart';
import 'help_icon_button.dart';

const _goalIcons = <String, IconData>{
  'flag': Icons.flag,
  'directions_car': Icons.directions_car,
  'home': Icons.home,
  'flight': Icons.flight,
  'school': Icons.school,
  'favorite': Icons.favorite,
  'phone_iphone': Icons.phone_iphone,
  'celebration': Icons.celebration,
};

const _goalColors = [
  '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5', '#2196F3', '#03A9F4',
  '#00BCD4', '#009688', '#4CAF50', '#8BC34A', '#CDDC39', '#FFC107', '#FF9800',
  '#FF5722', '#795548', '#607D8B',
];

double _parseCurrency(String text) {
  final str = text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
  return double.tryParse(str) ?? 0;
}

String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class GoalsSection extends ConsumerWidget {
  const GoalsSection({super.key, this.addButtonKey});

  /// Key do botão "Nova Meta" no cabeçalho -- usada pelo tutorial da tela de
  /// Investimentos pra destacá-lo (GoalsSection não tem AppBar própria, então
  /// não pode montar seu próprio TutorialButton).
  final Key? addButtonKey;

  Future<void> _showGoalDialog(BuildContext context, WidgetRef ref, [Map<String, dynamic>? goal]) async {
    final nomeController = TextEditingController(text: goal?['nome']?.toString() ?? '');
    final valorAlvoController = TextEditingController(
      text: goal != null ? CurrencyFormatter.format(((goal['valor_alvo'] ?? 0) as num).toDouble()) : '',
    );
    final aporteController = TextEditingController(
      text: goal?['aporte_mensal_planejado'] != null
          ? CurrencyFormatter.format((goal!['aporte_mensal_planejado'] as num).toDouble())
          : '',
    );
    String selectedIcon = goal?['icone']?.toString() ?? 'flag';
    String selectedColor = goal?['cor_hexadecimal']?.toString() ?? '#4CAF50';
    DateTime? selectedDate = goal?['data_alvo'] != null ? DateTime.tryParse(goal!['data_alvo'].toString()) : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal == null ? 'Nova Meta' : 'Editar Meta', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome da Meta (ex: Comprar um Carro)'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Text('Ícone', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(ctx))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _goalIcons.entries.map((e) {
                        final isSelected = selectedIcon == e.key;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = e.key),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(ctx).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                              border: Border.all(color: isSelected ? Theme.of(ctx).colorScheme.primary : AppColors.divider(ctx)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(e.value, color: isSelected ? Theme.of(ctx).colorScheme.primary : AppColors.iconMuted(ctx)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Cor', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(ctx))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _goalColors.map((hex) {
                        final isSelected = selectedColor == hex;
                        final c = Color(int.parse(hex.replaceAll('#', '0xFF')));
                        return InkWell(
                          onTap: () => setDialogState(() => selectedColor = hex),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Theme.of(ctx).colorScheme.onSurface, width: 2) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valorAlvoController,
                      decoration: const InputDecoration(labelText: 'Valor da Meta'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Plano de Contribuição (opcional)', style: TextStyle(fontSize: 12, color: AppColors.secondaryText(ctx))),
                        HelpIconButton(
                          title: 'Plano de Contribuição',
                          explanation:
                              'Preencha um dos dois -- não precisa dos dois. Se informar o '
                              'aporte mensal, o app calcula quantos meses faltam nesse ritmo. '
                              'Se informar só a data alvo, ele calcula quanto guardar por mês '
                              'pra chegar lá. Se preencher os dois, o aporte mensal manda.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: aporteController,
                      decoration: const InputDecoration(
                        labelText: 'Aporte mensal planejado',
                        helperText: 'Quanto pretende guardar/investir por mês para esta meta',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data alvo (alternativa ao aporte mensal)',
                          suffixIcon: const Icon(Icons.calendar_today, size: 18),
                          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                        child: Text(selectedDate != null ? _formatDate(selectedDate!) : 'Nenhuma data definida'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (goal != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final db = await SupabaseHelper.instance.database;
                                await db.delete(SupabaseHelper.tableMetas, where: 'id = ?', whereArgs: [goal['id'] ?? goal['ID']]);
                                if (ctx.mounted) Navigator.pop(ctx);
                                ref.invalidate(goalsProvider);
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Excluir'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final nome = nomeController.text.trim();
                              final valorAlvo = _parseCurrency(valorAlvoController.text);
                              if (nome.isEmpty || valorAlvo <= 0) return;
                              final aporte = aporteController.text.trim().isEmpty ? null : _parseCurrency(aporteController.text);

                              final db = await SupabaseHelper.instance.database;
                              final data = {
                                'nome': nome,
                                'valor_alvo': valorAlvo,
                                'aporte_mensal_planejado': aporte,
                                'data_alvo': selectedDate?.toIso8601String().substring(0, 10),
                                'icone': selectedIcon,
                                'cor_hexadecimal': selectedColor,
                              };

                              if (goal == null) {
                                await db.insert(SupabaseHelper.tableMetas, data);
                              } else {
                                await db.update(SupabaseHelper.tableMetas, data, where: 'id = ?', whereArgs: [goal['id'] ?? goal['ID']]);
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              ref.invalidate(goalsProvider);
                            },
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: const Text('Salvar Meta'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _buildProjectionText(double progress, double netWorth, double valorAlvo, double? aporte, DateTime? dataAlvo, bool isBalanceHidden) {
    if (progress >= 1.0) return 'Meta atingida! 🎉';

    if (aporte != null && aporte > 0) {
      final months = GoalProjection.monthsToReach(netWorth, valorAlvo, aporte);
      if (months == null) return null;
      final years = months ~/ 12;
      final rem = months % 12;
      final partes = <String>[];
      if (years > 0) partes.add('$years ${years > 1 ? 'anos' : 'ano'}');
      if (rem > 0 || years == 0) partes.add('$rem ${rem == 1 ? 'mês' : 'meses'}');
      return 'Faltam ${partes.join(' e ')} nesse ritmo';
    }

    if (dataAlvo != null) {
      final required = GoalProjection.requiredMonthlyContribution(netWorth, valorAlvo, dataAlvo, DateTime.now());
      if (required == null || required <= 0) return null;
      final formatted = isBalanceHidden ? '••••••' : CurrencyFormatter.format(required);
      return 'Guarde $formatted/mês para atingir até ${_formatDate(dataAlvo)}';
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final netWorthAsync = ref.watch(netWorthProvider);
    final isBalanceHidden = ref.watch(hideBalanceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Metas Financeiras', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface(context))),
              IconButton(
                key: addButtonKey,
                icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                tooltip: 'Nova Meta',
                onPressed: () => _showGoalDialog(context, ref),
              ),
            ],
          ),
          goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider(context)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.flag_outlined, size: 36, color: AppColors.iconMuted(context)),
                      const SizedBox(height: 8),
                      Text('Nenhuma meta cadastrada ainda.', style: TextStyle(color: AppColors.secondaryText(context))),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showGoalDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Criar Meta'),
                      ),
                    ],
                  ),
                );
              }

              final netWorth = netWorthAsync.value ?? 0;

              return Column(
                children: goals.map((goal) {
                  final nome = (goal['nome'] ?? '').toString();
                  final valorAlvo = ((goal['valor_alvo'] ?? 0) as num).toDouble();
                  final aporte = goal['aporte_mensal_planejado'] != null ? (goal['aporte_mensal_planejado'] as num).toDouble() : null;
                  final dataAlvoStr = goal['data_alvo']?.toString();
                  final dataAlvo = dataAlvoStr != null ? DateTime.tryParse(dataAlvoStr) : null;
                  final icone = (goal['icone'] ?? 'flag').toString();
                  final corHex = (goal['cor_hexadecimal'] ?? '#4CAF50').toString();
                  final color = Color(int.parse(corHex.replaceAll('#', '0xFF')));
                  final progress = GoalProjection.progress(netWorth, valorAlvo);
                  final projecaoTexto = _buildProjectionText(progress, netWorth, valorAlvo, aporte, dataAlvo, isBalanceHidden);
                  final atingido = netWorth.clamp(0.0, valorAlvo).toDouble();

                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider(context)),
                    ),
                    child: InkWell(
                      onTap: () => _showGoalDialog(context, ref, goal),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_goalIcons[icone] ?? Icons.flag, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text(
                                      isBalanceHidden
                                          ? 'R\$ •••••• de ${CurrencyFormatter.format(valorAlvo)}'
                                          : '${CurrencyFormatter.format(atingido)} de ${CurrencyFormatter.format(valorAlvo)}',
                                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText(context)),
                                    ),
                                  ],
                                ),
                              ),
                              Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: color.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          if (projecaoTexto != null) ...[
                            const SizedBox(height: 8),
                            Text(projecaoTexto, style: TextStyle(fontSize: 12, color: AppColors.mutedText(context))),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Erro ao carregar metas: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
