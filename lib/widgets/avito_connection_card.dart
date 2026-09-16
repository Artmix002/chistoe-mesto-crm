import 'package:flutter/material.dart';

class AvitoConnectionCard extends StatelessWidget {
  const AvitoConnectionCard({
    super.key,
    required this.accounts,
    required this.activeAccountKey,
    required this.connected,
    required this.loading,
    required this.status,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.onRefresh,
    required this.canConfigure,
    required this.onConfigure,
    required this.onSelectAccount,
  });

  final List<Map<String, dynamic>> accounts;
  final String? activeAccountKey;
  final bool connected;
  final bool loading;
  final String status;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final VoidCallback onRefresh;
  final bool canConfigure;
  final VoidCallback onConfigure;
  final ValueChanged<String> onSelectAccount;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 980),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: connected ? const Color(0xFFF28C28) : borderColor,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (constraints.maxWidth < 640) ...[
            _title(),
            const SizedBox(height: 12),
            _actions(),
          ] else
            Row(
              children: [
                Expanded(child: _title()),
                const SizedBox(width: 12),
                _actions(),
              ],
            ),
          if (_selectableAccounts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Активный аккаунт:',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                DropdownButton<String>(
                  value: _selectedAccountKey,
                  items: _selectableAccounts
                      .map(
                        (account) => DropdownMenuItem<String>(
                          value: account['key']?.toString(),
                          child: Text(_accountTitle(account)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: canConfigure
                      ? (value) {
                          if (value != null) onSelectAccount(value);
                        }
                      : null,
                ),
                Text(
                  'Подключено аккаунтов: ${accounts.length}',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _title() => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF28C28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.storefront_outlined, color: Colors.white),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avito: сообщения и звонки',
              style: TextStyle(
                color: mainTextColor,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                color: connected ? const Color(0xFFF28C28) : mutedTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _actions() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (connected)
        OutlinedButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Обновить'),
        ),
      ElevatedButton.icon(
        onPressed: canConfigure ? onConfigure : null,
        icon: const Icon(Icons.add_link),
        label: Text(accounts.isEmpty ? 'Подключить Avito' : 'Добавить аккаунт'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF28C28),
          foregroundColor: Colors.white,
        ),
      ),
    ],
  );

  List<Map<String, dynamic>> get _selectableAccounts => accounts
      .where((account) => (account['key']?.toString() ?? '').isNotEmpty)
      .toList(growable: false);

  String? get _selectedAccountKey {
    if (_selectableAccounts.isEmpty) return null;
    if (_selectableAccounts.any(
      (account) => account['key']?.toString() == activeAccountKey,
    )) {
      return activeAccountKey;
    }
    return _selectableAccounts.first['key']?.toString();
  }

  String _accountTitle(Map<String, dynamic> account) {
    final name = account['name']?.toString() ?? 'Avito';
    final userId = account['userId']?.toString() ?? '';
    return userId.isEmpty ? name : '$name • $userId';
  }
}
