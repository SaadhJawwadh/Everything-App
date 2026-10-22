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

  @override
  String get preferencesAndWorkspaces => 'Настройки и разделы';

  @override
  String get notesAndEditorWorkspace => 'Заметки и редактор';

  @override
  String get financesAndHealthModules => 'Финансы и здоровье';

  @override
  String get privacyAndSecurity => 'Конфиденциальность и защита';

  @override
  String get syncAndBackups => 'Синхронизация и копии';

  @override
  String get aboutAndDeviceAi => 'О приложении и ИИ';

  @override
  String get startFromTemplate => 'Создать по шаблону';

  @override
  String get templateMeetingNotes => 'Заметки со встречи';

  @override
  String get templateMeetingNotesDesc => 'Повестка, обсуждение и задачи';

  @override
  String get templateShoppingList => 'Список покупок';

  @override
  String get templateShoppingListDesc => 'Готовый список с флажками';

  @override
  String get templateJournal => 'Дневник';

  @override
  String get templateJournalDesc => 'Вопросы для ежедневных размышлений';

  @override
  String get themeAndColorSystem => 'Тема и цвета';

  @override
  String get appThemeMode => 'Тема приложения';

  @override
  String get dynamicWallpaperTheme => 'Динамические цвета обоев';

  @override
  String get dynamicWallpaperSubtitle =>
      'Подбирать цвета под обои устройства (Android 12+)';

  @override
  String get interactionAndAccessibility =>
      'Взаимодействие и спец. возможности';

  @override
  String get tactileHaptics => 'Тактильный отклик';

  @override
  String get tactileHapticsSubtitle =>
      'Приятная вибрация для ползунков, удержаний и действий';

  @override
  String get textScale => 'Размер текста';

  @override
  String get textScaleSubtitle => 'Общий масштаб шрифта';

  @override
  String get textScaleSmall => 'Мелкий';

  @override
  String get textScaleMedium => 'Средний';

  @override
  String get textScaleLarge => 'Крупный';

  @override
  String get appLanguage => 'Язык приложения';

  @override
  String get selectCurrency => 'Выбор валюты';

  @override
  String noSettingsFound(String query) {
    return 'Ничего не найдено по запросу \"$query\"';
  }

  @override
  String get quickSuggestions => 'Быстрые варианты:';

  @override
  String get clearSelection => 'Снять выделение';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count',
      many: 'Выбрано $count',
      few: 'Выбрано $count',
      one: 'Выбрана 1',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Выбрать все';

  @override
  String get deselectAll => 'Снять выбор';

  @override
  String get closeSearch => 'Закрыть поиск';

  @override
  String get clearQuery => 'Очистить запрос';

  @override
  String get createNewFolder => 'Создать новую папку';

  @override
  String get folderName => 'Название папки';

  @override
  String get filterByFolder => 'Фильтр по папкам';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get allNotes => 'Все заметки';

  @override
  String get checklistsAndTasks => 'Списки и задачи';

  @override
  String get archivedNotes => 'Архивные заметки';

  @override
  String get trashBin => 'Корзина';

  @override
  String get sortNotes => 'Сортировка заметок';

  @override
  String get sortByLastModified => 'По дате изменения';

  @override
  String get sortByDateCreated => 'По дате создания';

  @override
  String get sortByTitle => 'По названию';

  @override
  String get sortByColor => 'По цвету';

  @override
  String get importNotes => 'Импорт заметок';

  @override
  String get switchToGridView => 'Переключить на сетку';

  @override
  String get switchToListView => 'Переключить на список';

  @override
  String get selectPeriod => 'Выберите период';

  @override
  String get thisMonth => 'Этот месяц';

  @override
  String get lastMonth => 'Прошлый месяц';

  @override
  String get last90Days => 'Последние 90 дней';

  @override
  String get thisYear => 'Этот год';

  @override
  String get allTime => 'За все время';

  @override
  String get customDateRange => 'Свой диапазон дат…';

  @override
  String get customDateRangeSubtitle =>
      'Точные даты начала и конца из календаря';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задач выполнено',
      many: '$count задач выполнено',
      few: '$count задачи выполнены',
      one: '1 задача выполнена',
    );
    return 'Все $_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'еще $count пунктов',
      many: 'еще $count пунктов',
      few: 'еще $count пункта',
      one: 'еще 1 пункт',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'Управление категориями';

  @override
  String get restoreDefaults => 'Сбросить по умолчанию';

  @override
  String get restoreDefaultCategoriesTitle =>
      'Восстановить категории по умолчанию?';

  @override
  String get restoreDefaultCategoriesContent =>
      'Пользовательские категории будут удалены, а встроенные вернутся к исходным цветам и ключевым словам. Существующие транзакции сохранят свои метки категорий.';

  @override
  String get categoriesRestored => 'Категории восстановлены по умолчанию';

  @override
  String get newCategory => 'Новая категория';

  @override
  String get editCategory => 'Редактировать категорию';

  @override
  String get categoryName => 'Название категории';

  @override
  String get categoryNameRequired => 'Введите название категории';

  @override
  String get categoryNameExists => 'Категория с таким названием уже существует';

  @override
  String get icon => 'Иконка';

  @override
  String get colour => 'Цвет';

  @override
  String get keywords => 'Ключевые слова';

  @override
  String get addKeywordHint => 'Добавить ключевое слово…';

  @override
  String get noKeywords => 'Нет ключевых слов';

  @override
  String get deleteCategoryTooltip => 'Удалить категорию';

  @override
  String get editCategoryTooltip => 'Редактировать категорию';

  @override
  String get cannotDeleteOtherCategory =>
      'Категорию по умолчанию «Прочее» нельзя удалить.';

  @override
  String deleteCategoryTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteCategoryContent =>
      'Существующие транзакции с этой категорией будут переведены в «Прочее», чтобы история осталась нетронутой.';

  @override
  String get cyclePhaseGuide => 'Справочник фаз цикла';

  @override
  String get menstrualPhase => 'Менструальная фаза';

  @override
  String get menstrualPhaseDays => '1–5 дни';

  @override
  String get menstrualPhaseDesc =>
      'Отторжение эндометрия. Энергия снижена; отдайте приоритет отдыху, водному балансу и легкой активности.';

  @override
  String get follicularPhase => 'Фолликулярная фаза';

  @override
  String get follicularPhaseDays => '6–13 дни';

  @override
  String get follicularPhaseDesc =>
      'Рост эстрогена по мере созревания фолликулов. Энергия, настроение и творческая концентрация на пике.';

  @override
  String get ovulatoryPhase => 'Овуляторная фаза';

  @override
  String get ovulatoryPhaseDays => '14–16 дни';

  @override
  String get ovulatoryPhaseDesc =>
      'Всплеск лютеинизирующего гормона вызывает выход яйцеклетки. Пик уверенности, социальной энергии и фертильности.';

  @override
  String get lutealPhase => 'Лютеиновая фаза';

  @override
  String get lutealPhaseDays => '17–28 дни';

  @override
  String get lutealPhaseDesc =>
      'Уровень прогестерона растет. Энергия направляется внутрь; возможен ПМС. Рекомендуется замедлиться.';

  @override
  String get symptomCramps => 'Спазмы';

  @override
  String get symptomBloating => 'Вздутие';

  @override
  String get symptomHeadache => 'Головная боль';

  @override
  String get symptomFatigue => 'Усталость';

  @override
  String get symptomAcne => 'Акне';

  @override
  String get symptomMoodSwings => 'Перепады настроения';

  @override
  String get symptomNausea => 'Тошнота';

  @override
  String get symptomBackache => 'Боль в спине';

  @override
  String get intensityLight => 'Слабая';

  @override
  String get intensityMedium => 'Средняя';

  @override
  String get intensityHeavy => 'Сильная';

  @override
  String get startDateAfterEndDate =>
      'Дата начала не может быть позже даты окончания';

  @override
  String get overlapDetectedTitle => 'Обнаружено пересечение';

  @override
  String get overlapDetectedMessage =>
      'Выбранные даты пересекаются с уже записанным периодом. Пожалуйста, скорректируйте даты.';
}
