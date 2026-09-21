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

  CrmUser? get _selectedUser =>
      widget.users.where((user) => user.id == _selectedUserId).firstOrNull;

  Future<void> _submit() async {
    final id = _selectedUserId;
    if (id == null || _submitting || _pin.text.length != 4) return;
    setState(() => _submitting = true);
    try {
      await widget.onLogin(id, _pin.text);
      _pin.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _appendDigit(String digit) {
    if (_submitting || _pin.text.length >= 4) return;
    setState(() => _pin.text += digit);
  }

  void _eraseDigit() {
    if (_submitting || _pin.text.isEmpty) return;
    setState(() => _pin.text = _pin.text.substring(0, _pin.text.length - 1));
  }

  void _selectUser(String id) {
    if (_submitting) return;
    setState(() {
      _selectedUserId = id;
      _pin.clear();
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas = dark ? const Color(0xFF101216) : const Color(0xFFF6F7F9);
    final surface = dark ? const Color(0xFF1C1F25) : Colors.white;
    final main = dark ? Colors.white : const Color(0xFF191B20);
    final muted = dark ? const Color(0xFFADB5C0) : const Color(0xFF69717D);
    final border = dark ? const Color(0xFF343944) : const Color(0xFFE0E4E8);
    const accent = Color(0xFFF28C28);

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 20 : 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(main: main, muted: muted, compact: compact),
                      SizedBox(height: compact ? 26 : 34),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: surface,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: dark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x120B1320),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 20 : 28),
                          child: widget.loading
                              ? _LoadingState(main: main, muted: muted)
                              : widget.users.isEmpty
                              ? _UnavailableState(
                                  error: widget.error,
                                  main: main,
                                  muted: muted,
                                  onRetry: widget.onRetry,
                                  onConfigureServer: widget.onConfigureServer,
                                )
                              : _LoginForm(
                                  users: widget.users,
                                  selectedUser: _selectedUser,
                                  pinLength: _pin.text.length,
                                  submitting: _submitting,
                                  error: widget.error,
                                  main: main,
                                  muted: muted,
                                  border: border,
                                  accent: accent,
                                  onSelectUser: _selectUser,
                                  onDigit: _appendDigit,
                                  onErase: _eraseDigit,
                                  onSubmit: _submit,
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Доступ защищён персональным PIN и сессией CRM',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.main,
    required this.muted,
    required this.compact,
  });

  final Color main;
  final Color muted;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        'assets/logo.png',
        width: compact ? 82 : 92,
        height: compact ? 82 : 92,
      ),
      const SizedBox(height: 16),
      Text(
        'Чистое место CRM',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: main,
          fontSize: compact ? 27 : 32,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'CRM детейлинг-центра',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 14),
      ),
    ],
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.main, required this.muted});

  final Color main;
  final Color muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: Column(
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 18),
        Text(
          'Проверяем доступ',
          style: TextStyle(color: main, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text('Загружаем доступные профили CRM', style: TextStyle(color: muted)),
      ],
    ),
  );
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({
    required this.error,
    required this.main,
    required this.muted,
    required this.onRetry,
    required this.onConfigureServer,
  });

  final String? error;
  final Color main;
  final Color muted;
  final VoidCallback onRetry;
  final VoidCallback onConfigureServer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(Icons.cloud_off_outlined, size: 34, color: muted),
      const SizedBox(height: 14),
      Text(
        'Нет связи с CRM-сервером',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: main,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        error ?? 'Не удалось получить список пользователей.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 22),
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Повторить подключение'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: onConfigureServer,
        child: const Text('Изменить адрес CRM-сервера'),
      ),
    ],
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.users,
    required this.selectedUser,
    required this.pinLength,
    required this.submitting,
    required this.error,
    required this.main,
    required this.muted,
    required this.border,
    required this.accent,
    required this.onSelectUser,
    required this.onDigit,
    required this.onErase,
    required this.onSubmit,
  });

  final List<CrmUser> users;
  final CrmUser? selectedUser;
  final int pinLength;
  final bool submitting;
  final String? error;
  final Color main;
  final Color muted;
  final Color border;
  final Color accent;
  final ValueChanged<String> onSelectUser;
  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final VoidCallback onSubmit;

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  Widget _profileButton(CrmUser user) {
    final selected = user.id == selectedUser?.id;
    return Semantics(
      button: true,
      selected: selected,
      label: '${user.name}, ${user.role}',
      child: InkWell(
        onTap: submitting ? null : () => onSelectUser(user.id),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected
                ? accent.withValues(alpha: .12)
                : Colors.transparent,
            border: Border.all(
              color: selected ? accent : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: selected ? accent : border,
                foregroundColor: selected ? Colors.white : main,
                child: Text(_initials(user.name)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: main,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Вход в аккаунт',
        style: TextStyle(
          color: main,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Выберите профиль, затем введите личный PIN.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 22),
      Text(
        'Профиль',
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          if (compact) {
            return SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) =>
                    SizedBox(width: 168, child: _profileButton(users[index])),
              ),
            );
          }
          return Column(
            children: users
                .map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _profileButton(user),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: 16),
      Text(
        'PIN-код',
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Semantics(
        label: 'Введено цифр PIN: $pinLength из 4',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: index < pinLength ? accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: index < pinLength ? accent : border,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE06C75).withValues(alpha: .12),
            border: Border.all(
              color: const Color(0xFFE06C75).withValues(alpha: .5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFE06C75),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error!,
                  style: TextStyle(color: main, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      _PinPad(disabled: submitting, onDigit: onDigit, onErase: onErase),
      const SizedBox(height: 16),
      SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: pinLength == 4 && !submitting ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_open_outlined),
          label: Text(submitting ? 'Проверяем PIN…' : 'Войти в CRM'),
        ),
      ),
    ],
  );
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.disabled,
    required this.onDigit,
    required this.onErase,
  });

  final bool disabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    const keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '',
      '0',
      'erase',
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 1.85,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        return _PinKey(
          label: key == 'erase' ? null : key,
          icon: key == 'erase' ? Icons.backspace_outlined : null,
          onTap: disabled
              ? null
              : key == 'erase'
              ? onErase
              : () => onDigit(key),
        );
      }).toList(),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label == null ? 'Удалить последнюю цифру' : 'Цифра $label',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Icon(icon),
        ),
      ),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
