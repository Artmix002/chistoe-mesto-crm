import 'package:flutter/material.dart';

const crmPages = <({String title, String subtitle})>[
  (title: 'Дашборд', subtitle: 'Сводка по работе детейлинг-центра'),
  (title: 'CRM', subtitle: 'Клиенты, автомобили и история обращений'),
  (title: 'Сделки', subtitle: 'Заказы и этапы работ'),
  (title: 'Записи', subtitle: 'Календарь и запись клиентов'),
  (title: 'Бухгалтерия', subtitle: 'Финансы и отчётность'),
  (title: 'Склад', subtitle: 'Остатки и товары'),
  (title: 'Настройки', subtitle: 'Настройки системы'),
  (title: 'Сообщения', subtitle: 'Интеграции и диалоги с клиентами'),
  (
    title: 'Тест-бот',
    subtitle: 'База знаний и безопасное тестирование ответов',
  ),
];

const crmPageIcons = <IconData>[
  Icons.dashboard_outlined,
  Icons.people_outline,
  Icons.assignment_outlined,
  Icons.calendar_month_outlined,
  Icons.account_balance_outlined,
  Icons.inventory_2_outlined,
  Icons.settings_outlined,
  Icons.chat_bubble_outline,
  Icons.smart_toy_outlined,
];
