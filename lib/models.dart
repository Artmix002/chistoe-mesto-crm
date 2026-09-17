class Client {
  Client({
    required this.id,
    required this.name,
    this.phone = '',
    this.car = '',
    this.source = '',
    this.note = '',
    this.lastContact = '',
    this.status = 'Новый лид',
    this.responsible = '',
    this.telegramChatId = '',
    this.vkPeerId = '',
    List<String>? phones,
    List<String>? cars,
    Map<String, String>? vehicleIds,
  }) : phones = List<String>.from(phones ?? const []),
       cars = List<String>.from(cars ?? const []),
       vehicleIds = Map<String, String>.from(vehicleIds ?? const {}) {
    if (phone.trim().isNotEmpty && !this.phones.contains(phone.trim())) {
      this.phones.add(phone.trim());
    }
    if (car.trim().isNotEmpty && !this.cars.contains(car.trim())) {
      this.cars.add(car.trim());
    }
    _syncVehicleIds();
  }
  final String id;
  String name;
  String phone;
  String car;
  String source;
  String note;
  String lastContact;
  String status;
  String responsible;
  String telegramChatId;
  String vkPeerId;
  final List<String> phones;
  final List<String> cars;
  final Map<String, String> vehicleIds;
  final List<String> carHistory = [];
  final List<String> interactionHistory = [];
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'car': car,
    'source': source,
    'note': note,
    'lastContact': lastContact,
    'status': status,
    'responsible': responsible,
    'telegramChatId': telegramChatId,
    'vkPeerId': vkPeerId,
    'phones': phones,
    'cars': cars,
    'vehicleIds': vehicleIds,
    'carHistory': carHistory,
    'interactionHistory': interactionHistory,
  };
  factory Client.fromJson(Map<String, dynamic> j) =>
      Client(
          id: '${j['id']}',
          name: '${j['name'] ?? ''}',
          phone: '${j['phone'] ?? ''}',
          car: '${j['car'] ?? ''}',
          source: '${j['source'] ?? ''}',
          note: '${j['note'] ?? ''}',
          lastContact: '${j['lastContact'] ?? ''}',
          status: '${j['status'] ?? 'Новый лид'}',
          responsible: '${j['responsible'] ?? ''}',
          telegramChatId: '${j['telegramChatId'] ?? ''}',
          vkPeerId: '${j['vkPeerId'] ?? ''}',
          phones: (j['phones'] as List? ?? [])
              .map((x) => x.toString())
              .toList(),
          cars: (j['cars'] as List? ?? []).map((x) => x.toString()).toList(),
          vehicleIds: j['vehicleIds'] is Map
              ? (j['vehicleIds'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : null,
        )
        ..carHistory.addAll(
          (j['carHistory'] as List? ?? []).map((x) => x.toString()),
        )
        ..interactionHistory.addAll(
          (j['interactionHistory'] as List? ?? []).map((x) => x.toString()),
        );

  void syncVehicleIds() => _syncVehicleIds();

  String? vehicleIdFor(String carName) => vehicleIds[carName.trim()];

  void _syncVehicleIds() {
    final activeCars = cars
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    vehicleIds.removeWhere((carName, _) => !activeCars.contains(carName));
    for (final carName in activeCars) {
      vehicleIds.putIfAbsent(
        carName,
        () => 'vehicle-$id-${Uri.encodeComponent(carName.toLowerCase())}',
      );
    }
  }
}

class StockItem {
  StockItem({
    required this.id,
    required this.name,
    this.unit = 'шт.',
    this.quantity = 0,
    this.minQuantity = 0,
    this.purchasePrice = 0,
    this.supplier = '',
    this.category = 'Без категории',
  });
  final String id;
  String name;
  String unit;
  double quantity;
  double minQuantity;
  double purchasePrice;
  String supplier;
  String category;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'quantity': quantity,
    'minQuantity': minQuantity,
    'purchasePrice': purchasePrice,
    'supplier': supplier,
    'category': category,
  };
  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    unit: '${j['unit'] ?? 'шт.'}',
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    minQuantity: (j['minQuantity'] as num?)?.toDouble() ?? 0,
    purchasePrice: (j['purchasePrice'] as num?)?.toDouble() ?? 0,
    supplier: '${j['supplier'] ?? ''}',
    category: '${j['category'] ?? 'Без категории'}',
  );
}

class StockMovement {
  StockMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.date,
    this.note = '',
    this.dealId = '',
    this.service = '',
    this.unitPrice = 0,
  });
  final String id;
  final String itemId;
  final String type;
  final double quantity;
  final String date;
  final String note;
  final String dealId;
  final String service;
  final double unitPrice;
  double costAt(double unitPrice) => quantity * unitPrice;
  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'type': type,
    'quantity': quantity,
    'date': date,
    'note': note,
    'dealId': dealId,
    'service': service,
    'unitPrice': unitPrice,
  };
  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
    id: '${j['id']}',
    itemId: '${j['itemId']}',
    type: '${j['type']}',
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    date: '${j['date'] ?? ''}',
    note: '${j['note'] ?? ''}',
    dealId: '${j['dealId'] ?? ''}',
    service: '${j['service'] ?? ''}',
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
  );
}

class AuditEntry {
  AuditEntry({
    required this.action,
    required this.entity,
    required this.date,
    this.details = '',
    this.actor = '',
  });
  final String action;
  final String entity;
  final String date;
  final String details;
  final String actor;
  Map<String, dynamic> toJson() => {
    'action': action,
    'entity': entity,
    'date': date,
    'details': details,
    'actor': actor,
  };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    action: '${j['action'] ?? ''}',
    entity: '${j['entity'] ?? ''}',
    date: '${j['date'] ?? ''}',
    details: '${j['details'] ?? ''}',
    actor: '${j['actor'] ?? ''}',
  );
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.active = true,
    Map<String, String>? permissions,
  }) : permissions = Map<String, String>.from(permissions ?? const {});

  final String id;
  String name;
  String role;
  bool active;
  Map<String, String> permissions;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'active': active,
    'permissions': permissions,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    role: '${json['role'] ?? 'Только просмотр'}',
    active: json['active'] != false,
    permissions: json['permissions'] is Map
        ? (json['permissions'] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : null,
  );
}

/// Typed representation of a deal used at module boundaries. The legacy
/// Sheets adapter may still expose rows, but business logic can validate data
/// without indexing arbitrary cells.
class Deal {
  Deal({
    required this.id,
    required this.date,
    required this.clientId,
    required this.clientName,
    this.phone = '',
    this.car = '',
    this.service = '',
    this.performers = '',
    this.status = 'Новый лид',
    this.revenue = 0,
    this.expenses = 0,
    this.workerPayout = 0,
    this.businessReserve = 0,
    this.ownerProfit = 0,
    this.source = '',
    this.comment = '',
  });
  final String id;
  String date;
  String clientId;
  String clientName;
  String phone;
  String car;
  String service;

  /// Исполнитель(и) из строки сделки. Хранятся строкой для совместимости с
  /// импортом из Sheets; аналитика делит общую выплату между именами.
  String performers;
  String status;
  double revenue;
  double expenses;
  double workerPayout;
  double businessReserve;
  double ownerProfit;
  String source;
  String comment;
  double get profit => revenue - expenses;
  List<String> validate() {
    final errors = <String>[];
    if (revenue < 0) errors.add('Выручка не может быть отрицательной');
    if (expenses < 0) errors.add('Расходы не могут быть отрицательными');
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'clientId': clientId,
    'clientName': clientName,
    'phone': phone,
    'car': car,
    'service': service,
    'performers': performers,
    'status': status,
    'revenue': revenue,
    'expenses': expenses,
    'workerPayout': workerPayout,
    'businessReserve': businessReserve,
    'ownerProfit': ownerProfit,
    'source': source,
    'comment': comment,
  };

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
    id: '${j['id'] ?? ''}',
    date: '${j['date'] ?? ''}',
    clientId: '${j['clientId'] ?? ''}',
    clientName: '${j['clientName'] ?? ''}',
    phone: '${j['phone'] ?? ''}',
    car: '${j['car'] ?? ''}',
    service: '${j['service'] ?? ''}',
    performers: '${j['performers'] ?? ''}',
    status: '${j['status'] ?? 'Новый лид'}',
    revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
    expenses: (j['expenses'] as num?)?.toDouble() ?? 0,
    workerPayout: (j['workerPayout'] as num?)?.toDouble() ?? 0,
    businessReserve: (j['businessReserve'] as num?)?.toDouble() ?? 0,
    ownerProfit: (j['ownerProfit'] as num?)?.toDouble() ?? 0,
    source: '${j['source'] ?? ''}',
    comment: '${j['comment'] ?? ''}',
  );

  factory Deal.fromRow(List<String> row, {String? id}) {
    double amount(int index) => index < row.length
        ? double.tryParse(
                row[index].replaceAll(' ', '').replaceAll(',', '.'),
              ) ??
              0
        : 0;
    final persistedId = row.length > 21 ? row[21].trim() : '';
    final stableId =
        id ??
        (persistedId.isNotEmpty
            ? persistedId
            : Uri.encodeComponent(
                '${row.isNotEmpty ? row[0] : ''}|${row.length > 2 ? row[2] : ''}|${row.length > 3 ? row[3] : ''}|${row.length > 17 ? row[17] : ''}',
              ));
    final phone = row.length > 2 ? row[2].trim() : '';
    final name = row.length > 17 && row[17].isNotEmpty
        ? row[17]
        : (row.length > 2 ? row[2] : '');
    final clientId = stableClientId(phone: phone, name: name);
    return Deal(
      id: stableId,
      date: row.isNotEmpty ? row[0] : '',
      clientId: clientId,
      clientName: name,
      phone: phone,
      car: row.length > 1 ? row[1] : '',
      service: row.length > 3 ? row[3] : '',
      performers: row.length > 4 ? row[4] : '',
      status: row.length > 16 ? row[16] : 'Новый лид',
      revenue: amount(5),
      expenses: amount(6),
      workerPayout: amount(9),
      businessReserve: amount(11),
      ownerProfit: amount(12),
      source: row.length > 18 ? row[18] : '',
      comment: row.length > 19 ? row[19] : '',
    );
  }
}

String stableClientId({required String phone, required String name}) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.isNotEmpty) return 'client-phone-$digits';
  return 'client-name-${Uri.encodeComponent(name.trim().toLowerCase())}';
}

/// RFC4180-compatible parser supporting quoted commas and escaped quotes.
List<String> parseCsvLine(String line) {
  final out = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      out.add(cell.toString());
      cell = StringBuffer();
    } else {
      cell.write(c);
    }
  }
  out.add(cell.toString());
  return out;
}

/// Parses a complete RFC4180 CSV document, including quoted line breaks.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(cell.toString());
      cell.clear();
    } else if ((c == '\n' || c == '\r') && !quoted) {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((value) => value.isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
      row.clear();
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
