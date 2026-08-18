import 'package:flutter/material.dart';
import '../providers/listas_compras_provider.dart';

const _sugestoes = ['Atacadão', 'Carrefour', 'Assaí Atacadista', 'Compras', 'Mantimentos', 'Feira'];

/// Bottom sheet de criação de lista. Retorna o id da lista criada, ou
/// null se o usuário cancelou.
Future<String?> showNovaListaSheet(BuildContext context) {
  final now = DateTime.now();
  final placeholder = 'Nova lista - ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
  final controller = TextEditingController();

  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(ctx, null)),
                ],
              ),
              const Icon(Icons.shopping_basket_rounded, size: 96, color: Colors.green),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: placeholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: Text('Sugestões', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _sugestoes.map((s) {
                  return ActionChip(
                    label: Text(s),
                    shape: const StadiumBorder(),
                    onPressed: () => controller.text = s,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final nome = controller.text.trim().isEmpty ? placeholder.replaceFirst('Nova lista - ', 'Lista ') : controller.text.trim();
                    final id = await ListasComprasRepo.criar(nome);
                    if (ctx.mounted) Navigator.pop(ctx, id);
                  },
                  child: const Text('Criar'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}
