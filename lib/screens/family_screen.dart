import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_helper.dart';
import '../utils/app_colors.dart';


class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _membros = [];
  List<dynamic> _pendingInvites = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadPendingInvites();
    await _loadMembros();
  }

  Future<void> _loadPendingInvites() async {
    try {
      final response = await Supabase.instance.client.rpc('get_pending_invites');
      if (mounted) {
        setState(() {
          _pendingInvites = response as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar convites: $e');
    }
  }

  Future<void> _acceptInvite(String id) async {
    setState(() => _isLoading = true);
    try {
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Convite aceito com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao aceitar convite'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectInvite(String id) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc('reject_family_invite', params: {'invite_id': id});
      await _loadAllData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao recusar convite'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMembros() async {
    setState(() => _isLoading = true);
    try {
      final db = await SupabaseHelper.instance.database;
      final usuarios = await db.query(SupabaseHelper.tableUsuarios);
      setState(() {
        _membros = usuarios;
      });
    } catch (e) {
      debugPrint('Erro ao carregar membros: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convidarMembro() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.rpc(
        'invite_user_by_email',
        params: {'guest_email': email},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.toString()),
            backgroundColor: response.toString().toLowerCase().contains('sucesso') 
                ? Colors.green.shade700 
                : Colors.orange.shade800,
          ),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro de conexão. Verifique sua internet.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Compartilhamento Familiar'),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading && _membros.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Premium de Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade800, Colors.blue.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.family_restroom, color: Colors.white, size: 40),
                          const SizedBox(height: 16),
                          const Text(
                            'Sincronização em Tempo Real',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Convide membros da sua família para que as contas e transações de todos fiquem sincronizadas entre os dispositivos.',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sessão de Convites Pendentes
                    if (_pendingInvites.isNotEmpty) ...[
                      const Text(
                        'Convites Recebidos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                      ),
                      const SizedBox(height: 16),
                      ..._pendingInvites.map((invite) => Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.mail, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Você foi convidado para: ${invite['familia_nome']}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface(context)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isLoading ? null : () => _rejectInvite(invite['id'].toString()),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade300,
                                          side: BorderSide(color: Colors.red.shade300),
                                        ),
                                        child: const Text('Recusar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : () => _acceptInvite(invite['id'].toString()),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Aceitar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 32),
                    ],

                    // Sessão de Enviar Convite
                    Text(
                      'Convidar Novo Membro',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface(context)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider(context)),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'E-mail do convidado',
                              hintText: 'exemplo@gmail.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest?.withOpacity(0.5) ?? Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _convidarMembro,
                              icon: _isLoading 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.send),
                              label: const Text('Enviar Convite'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'O convidado precisa ter uma conta no CofreNuvem criada com este e-mail.',
                            style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Lista de Membros (Usuarios locais que subiram no Sync)
                    Text(
                      'Membros Identificados',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface(context)),
                    ),
                    const SizedBox(height: 16),
                    if (_membros.isEmpty)
                      Text('Nenhum membro encontrado.', style: TextStyle(color: AppColors.secondaryText(context)))
                    else
                      ..._membros.map((m) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(m['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(m['id'].toString().split('-').first, style: TextStyle(color: AppColors.mutedText(context), fontSize: 12)),
                          trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ),
                      )).toList(),
                  ],
                ),
              ),
      ),
    );
  }
}
