import 'package:flutter/material.dart';

import '../auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.users,
    required this.loading,
    required this.error,
    required this.onLogin,
    required this.onRetry,
    required this.onConfigureServer,
    this.initialUserId,
  });

  final List<CrmUser> users;
  final bool loading;
  final String? error;
  final String? initialUserId;
  final Future<void> Function(String userId, String pin) onLogin;
  final VoidCallback onRetry;
  final VoidCallback onConfigureServer;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pin = TextEditingController();
  String? _selectedUserId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.initialUserId;
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final exists = widget.users.any((user) => user.id == _selectedUserId);
    if (!exists) {
      _selectedUserId =
          widget.users
              .where((user) => user.id == widget.initialUserId)
              .firstOrNull
              ?.id ??
          (widget.users.isEmpty ? null : widget.users.first.id);
    }
  }

  Future<void> _submit() async {
    final id = _selectedUserId;
    if (id == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onLogin(id, _pin.text);
      _pin.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 390,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', width: 76, height: 76),
                  const SizedBox(height: 18),
                  Text(
                    'Чистое место CRM',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Выберите пользователя и введите личный PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )
                  else if (widget.users.isEmpty)
                    Column(
                      children: [
                        Text(
                          widget.error ?? 'Не удалось получить пользователей.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: widget.onConfigureServer,
                          child: const Text('Настроить сервер CRM'),
                        ),
                      ],
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Пользователь',
                      ),
                      items: widget.users
                          .map(
                            (user) => DropdownMenuItem(
                              value: user.id,
                              child: Text('${user.name} · ${user.role}'),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _selectedUserId = value),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pin,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        hintText: '••••',
                        counterText: '',
                      ),
                    ),
                    if (widget.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? 'Входим…' : 'Войти'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
