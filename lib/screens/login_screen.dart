import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true;
  bool _rememberMe = true;
  
  List<Map<String, String>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> accountsJson = prefs.getStringList('saved_accounts') ?? [];
    
    if (mounted) {
      setState(() {
        _savedAccounts = accountsJson.map((e) {
          final decoded = jsonDecode(e) as Map<String, dynamic>;
          return {
            'email': decoded['email']?.toString() ?? '',
            'password': decoded['password']?.toString() ?? '',
            'name': decoded['name']?.toString() ?? '',
          };
        }).toList();
      });
    }
  }

  Future<void> _saveAccount(String email, String password, String name) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accountsJson = prefs.getStringList('saved_accounts') ?? [];
    
    // Remove if already exists to update password/name and move to front
    accountsJson.removeWhere((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      return decoded['email'] == email;
    });

    final newAccount = jsonEncode({
      'email': email,
      // Convert to base64 just for obfuscation in shared_prefs (not real security, but prevents plain text peeking)
      'password': base64Encode(utf8.encode(password)),
      'name': name.isEmpty ? email.split('@').first : name,
    });
    
    accountsJson.insert(0, newAccount);
    await prefs.setStringList('saved_accounts', accountsJson);
    _loadSavedAccounts();
  }

  Future<void> _removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accountsJson = prefs.getStringList('saved_accounts') ?? [];
    
    accountsJson.removeWhere((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      return decoded['email'] == email;
    });
    
    await prefs.setStringList('saved_accounts', accountsJson);
    _loadSavedAccounts();
  }

  Future<void> _authenticate() async {
    final nome = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && nome.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos')));
      return;
    }

    setState(() => _isLoading = true);

    try {
// Banco local removido
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
        
        if (_rememberMe) {
          await _saveAccount(email, password, nome);
        }
        
        if (mounted && Supabase.instance.client.auth.currentUser != null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
        }
      } else {
        await Supabase.instance.client.auth.signUp(
          email: email, 
          password: password,
          data: {'nome': nome},
        );
        
        // Desloga caso o Supabase tenha feito login automático (para forçar o usuário a digitar a senha como solicitado)
        await Supabase.instance.client.auth.signOut();
// Banco local removido
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text('Conta Criada!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Sua conta foi criada com sucesso e já está pronta para uso.\n\nPor segurança, digite sua senha para fazer o primeiro acesso.',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Fazer Login', style: TextStyle(fontSize: 16)),
                )
              ],
            )
          ).then((_) {
            if (mounted) {
              setState(() {
                _isLogin = true;
                _passwordController.clear();
              });
            }
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro inesperado')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillAndLogin(Map<String, String> account) {
    _emailController.text = account['email']!;
    final pass = utf8.decode(base64Decode(account['password']!));
    _passwordController.text = pass;
    _isLogin = true;
    _authenticate();
  }

  Widget _buildSavedAccounts() {
    if (_savedAccounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contas Salvas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _savedAccounts.length,
            itemBuilder: (context, index) {
              final account = _savedAccounts[index];
              final name = account['name']!.isNotEmpty ? account['name']! : account['email']!.split('@').first;
              
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _fillAndLogin(account),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: Text(
                              name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _removeAccount(account['email']!),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                'CofreNuvem',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              
              if (_isLogin) _buildSavedAccounts(),
              
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Seu Nome',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.password),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              if (_isLogin)
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      activeColor: Colors.blueAccent,
                    ),
                    const Text('Lembrar de mim e salvar conta'),
                  ],
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isLogin ? 'Entrar' : 'Criar Conta', style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? 'Não tem uma conta? Crie aqui' : 'Já tem conta? Entre aqui'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
