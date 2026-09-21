import 'package:flutter/material.dart';

enum CrmHealthState { connected, pending, offline, error, notConfigured }

class CrmSyncStatus {
  const CrmSyncStatus({
    required this.serverConnected,
    required this.sheetsOffline,
    required this.syncing,
    required this.pendingChanges,
    required this.lastSuccessfulSync,
    this.error,
  });

  final bool serverConnected;
  final bool sheetsOffline;
  final bool syncing;
  final int pendingChanges;
  final DateTime? lastSuccessfulSync;
  final String? error;

  CrmHealthState get state {
    if (!serverConnected) return CrmHealthState.notConfigured;
    if (error != null && error!.isNotEmpty) return CrmHealthState.error;
    if (syncing || pendingChanges > 0) return CrmHealthState.pending;
    if (sheetsOffline) return CrmHealthState.offline;
    return CrmHealthState.connected;
  }
}

class IntegrationHealth {
  const IntegrationHealth({
    required this.name,
    required this.state,
    required this.detail,
  });

  final String name;
  final CrmHealthState state;
  final String detail;

  IconData get icon => switch (state) {
    CrmHealthState.connected => Icons.check_circle_outline,
    CrmHealthState.pending => Icons.sync,
    CrmHealthState.offline => Icons.cloud_off_outlined,
    CrmHealthState.error => Icons.error_outline,
    CrmHealthState.notConfigured => Icons.remove_circle_outline,
  };

  Color color(BuildContext context) => switch (state) {
    CrmHealthState.connected => Colors.green,
    CrmHealthState.pending => Colors.orange,
    CrmHealthState.offline || CrmHealthState.error => Colors.red,
    CrmHealthState.notConfigured => Theme.of(context).disabledColor,
  };
}
