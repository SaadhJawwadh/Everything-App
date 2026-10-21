// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'Заметки';

  @override
  String get navFinances => 'Финансы';

  @override
  String get navTracker => 'Цикл';

  @override
  String get navSplitBills => 'Совместные счета';

  @override
  String get greetingMorning => 'Доброе утро!';

  @override
  String get greetingAfternoon => 'Добрый день!';

  @override
  String get greetingEvening => 'Добрый вечер!';

  @override
  String get greetingNight => 'Пора спать!';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заметки',
      many: '$count заметок',
      few: '$count заметки',
      one: '$count заметка',
      zero: 'Нет заметок',
    );
    return '$_temp0';
  }

  @override
  String get searchNotes => 'Поиск заметок...';

  @override
  String get searchFinances => 'Поиск операций...';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get newNote => 'Новая заметка';

  @override
  String get newTransaction => 'Новая операция';

  @override
  String get search => 'Поиск';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Изменить';

  @override
  String get done => 'Готово';

  @override
  String get close => 'Закрыть';

  @override
  String get filter => 'Фильтр';

  @override
  String get sort => 'Сортировка';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get back => 'Назад';

  @override
  String get copy => 'Копировать';

  @override
  String get share => 'Поделиться';

  @override
  String get clear => 'Очистить';

  @override
  String get apply => 'Применить';

  @override
  String get discard => 'Отменить';

  @override
  String get undo => 'Отменить';

  @override
  String get all => 'Все';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get pinnedNotes => 'Закрепленные';

  @override
  String get otherNotes => 'Другие заметки';

  @override
  String get emptyNotesTitle => 'Пока нет заметок';

  @override
  String get emptyNotesSubtitle => 'Нажмите +, чтобы записать мысли';

  @override
  String get archive => 'Архив';

  @override
  String get trash => 'Корзина';

  @override
  String get restore => 'Восстановить';

  @override
  String get deletePermanently => 'Удалить навсегда';

  @override
  String get lockedNote => 'Заблокированная заметка';

  @override
  String get appLocked => 'Приложение заблокировано';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get noteTitlePlaceholder => 'Заголовок';

  @override
  String get noteBodyPlaceholder => 'Начните вводить текст...';

  @override
  String get manageTags => 'Управление тегами';

  @override
  String get income => 'Доход';

  @override
  String get expense => 'Расход';

  @override
  String get balance => 'Баланс';

  @override
  String get netBalance => 'Чистый баланс';

  @override
  String get monthlySpending => 'Расходы за месяц';

  @override
  String get dailySafeToSpend => 'Можно потратить сегодня';

  @override
  String get ledger => 'Журнал';

  @override
  String get breakdown => 'Аналитика';

  @override
  String get budgets => 'Бюджеты';

  @override
  String get savings => 'Накопления';

  @override
  String get savingsGoals => 'Цели накоплений';

  @override
  String get deposit => 'Пополнить';

  @override
  String get dailyAccount => 'Основной счет';

  @override
  String get savingsVault => 'Накопительный счет';

  @override
  String get targetAmount => 'Целевая сумма';

  @override
  String get currentAmount => 'Текущая сумма';

  @override
  String get noTransactionsYet => 'Нет финансовых данных';

  @override
  String get categories => 'Категории';

  @override
  String get splitBillsTitle => 'Совместные счета';

  @override
  String get settleUp => 'Рассчитаться';

  @override
  String get equalSplit => 'Поровну';

  @override
  String get customSplit => 'Другое разделение';

  @override
  String get paidBy => 'Оплатил';

  @override
  String get sendReminder => 'Напомнить';

  @override
  String cycleDay(int day) {
    return 'День цикла $day';
  }

  @override
  String get periodLog => 'Запись цикла';

  @override
  String get symptoms => 'Симптомы';

  @override
  String get periodStart => 'Начало периода';

  @override
  String get periodEnd => 'Конец периода';

  @override
  String get regular => 'Регулярный';

  @override
  String get irregular => 'Нерегулярный';

  @override
  String get appearance => 'Оформление и интерфейс';

  @override
  String get theme => 'Тема';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Темная';

  @override
  String get themeSystem => 'Системная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get currency => 'Валюта';

  @override
  String get security => 'Безопасность';

  @override
  String get backupRestore => 'Резервное копирование';

  @override
  String get about => 'О приложении';

  @override
  String get onDeviceAi => 'Локальный ИИ';
}
