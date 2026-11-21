// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'Notas';

  @override
  String get navFinances => 'Finanzas';

  @override
  String get navTracker => 'Ciclo';

  @override
  String get navSplitBills => 'Dividir Gastos';

  @override
  String get greetingMorning => '¡Buenos días!';

  @override
  String get greetingAfternoon => '¿Ya almorzaste?';

  @override
  String get greetingEvening => '¡Buenas tardes!';

  @override
  String get greetingNight => '¡Hora de dormir!';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
    );
    return '$_temp0';
  }

  @override
  String get searchNotes => 'Buscar notas...';

  @override
  String get searchFinances => 'Buscar transacciones...';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get newNote => 'Nueva Nota';

  @override
  String get newTransaction => 'Nueva Transacción';

  @override
  String get search => 'Buscar';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get done => 'Listo';

  @override
  String get close => 'Cerrar';

  @override
  String get filter => 'Filtrar';

  @override
  String get sort => 'Ordenar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get back => 'Atrás';

  @override
  String get copy => 'Copiar';

  @override
  String get share => 'Compartir';

  @override
  String get clear => 'Limpiar';

  @override
  String get apply => 'Aplicar';

  @override
  String get discard => 'Descartar';

  @override
  String get undo => 'Deshacer';

  @override
  String get all => 'Todo';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get pinnedNotes => 'Notas Fijadas';

  @override
  String get otherNotes => 'Otras Notas';

  @override
  String get emptyNotesTitle => 'No hay notas aún';

  @override
  String get emptyNotesSubtitle => 'Toca + para capturar tus pensamientos';

  @override
  String get archive => 'Archivar';

  @override
  String get trash => 'Papelera';

  @override
  String get restore => 'Restablecer';

  @override
  String get deletePermanently => 'Eliminar Definitivamente';

  @override
  String get lockedNote => 'Nota bloqueada';

  @override
  String get appLocked => 'Aplicación Bloqueada';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get noteTitlePlaceholder => 'Título';

  @override
  String get noteBodyPlaceholder => 'Empieza a escribir...';

  @override
  String get manageTags => 'Gestionar Etiquetas';

  @override
  String get income => 'Ingresos';

  @override
  String get expense => 'Gastos';

  @override
  String get balance => 'Saldo';

  @override
  String get netBalance => 'Saldo Neto';

  @override
  String get monthlySpending => 'Gasto Mensual';

  @override
  String get dailySafeToSpend => 'Disponible para Gastar Hoy';

  @override
  String get ledger => 'Libro mayor';

  @override
  String get breakdown => 'Desglose';

  @override
  String get budgets => 'Presupuestos';

  @override
  String get savings => 'Ahorros';

  @override
  String get savingsGoals => 'Metas de Ahorro';

  @override
  String get deposit => 'Depositar';

  @override
  String get dailyAccount => 'Cuenta Diaria';

  @override
  String get savingsVault => 'Bóveda de Ahorros';

  @override
  String get targetAmount => 'Monto Objetivo';

  @override
  String get currentAmount => 'Monto Actual';

  @override
  String get noTransactionsYet => 'Sin datos financieros aún';

  @override
  String get categories => 'Categorías';

  @override
  String get splitBillsTitle => 'Dividir Gastos';

  @override
  String get settleUp => 'Liquidar Cuentas';

  @override
  String get equalSplit => 'División Equitativa';

  @override
  String get customSplit => 'División Personalizada';

  @override
  String get paidBy => 'Pagado por';

  @override
  String get sendReminder => 'Enviar Recordatorio';

  @override
  String cycleDay(int day) {
    return 'Día del Ciclo $day';
  }

  @override
  String get periodLog => 'Registro Menstrual';

  @override
  String get symptoms => 'Síntomas';

  @override
  String get periodStart => 'Inicio del Periodo';

  @override
  String get periodEnd => 'Fin del Periodo';

  @override
  String get regular => 'Regular';

  @override
  String get irregular => 'Irregular';

  @override
  String get appearance => 'Apariencia e Interfaz';

  @override
  String get theme => 'Tema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Predeterminado del Sistema';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del Sistema';

  @override
  String get currency => 'Moneda';

  @override
  String get security => 'Seguridad y Privacidad';

  @override
  String get backupRestore => 'Copia de Seguridad y Restauración';

  @override
  String get about => 'Acerca de';

  @override
  String get onDeviceAi => 'IA en el Dispositivo';

  @override
  String get preferencesAndWorkspaces => 'Preferencias y espacios';

  @override
  String get notesAndEditorWorkspace => 'Notas y editor';

  @override
  String get financesAndHealthModules => 'Finanzas y salud';

  @override
  String get privacyAndSecurity => 'Privacidad y seguridad';

  @override
  String get syncAndBackups => 'Sincronización y respaldos';

  @override
  String get aboutAndDeviceAi => 'Acerca de e IA';

  @override
  String get startFromTemplate => 'Iniciar desde plantilla';

  @override
  String get templateMeetingNotes => 'Notas de reunión';

  @override
  String get templateMeetingNotesDesc => 'Agenda, discusión y puntos de acción';

  @override
  String get templateShoppingList => 'Lista de compras';

  @override
  String get templateShoppingListDesc =>
      'Lista de verificación lista para marcar';

  @override
  String get templateJournal => 'Diario';

  @override
  String get templateJournalDesc => 'Preguntas de reflexión diaria';

  @override
  String get themeAndColorSystem => 'Tema y sistema de color';

  @override
  String get appThemeMode => 'Modo de tema';

  @override
  String get dynamicWallpaperTheme => 'Fondo dinámico';

  @override
  String get dynamicWallpaperSubtitle =>
      'Combinar colores con el fondo de pantalla (Android 12+)';

  @override
  String get interactionAndAccessibility => 'Interacción y accesibilidad';

  @override
  String get tactileHaptics => 'Vibración táctil';

  @override
  String get tactileHapticsSubtitle =>
      'Respuesta háptica para controles y acciones';

  @override
  String get textScale => 'Tamaño del texto';

  @override
  String get textScaleSubtitle => 'Escala global de fuente';

  @override
  String get textScaleSmall => 'Pequeño';

  @override
  String get textScaleMedium => 'Medio';

  @override
  String get textScaleLarge => 'Grande';

  @override
  String get appLanguage => 'Idioma de la app';

  @override
  String get selectCurrency => 'Seleccionar moneda';

  @override
  String noSettingsFound(String query) {
    return 'No se encontraron ajustes para \"$query\"';
  }

  @override
  String get quickSuggestions => 'Sugerencias rápidas:';

  @override
  String get clearSelection => 'Borrar selección';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Deseleccionar todo';

  @override
  String get closeSearch => 'Cerrar búsqueda';

  @override
  String get clearQuery => 'Borrar búsqueda';

  @override
  String get createNewFolder => 'Crear nueva carpeta';

  @override
  String get folderName => 'Nombre de carpeta';

  @override
  String get filterByFolder => 'Filtrar por carpeta';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get allNotes => 'Todas las notas';

  @override
  String get checklistsAndTasks => 'Listas y tareas';

  @override
  String get archivedNotes => 'Notas archivadas';

  @override
  String get trashBin => 'Papelera';

  @override
  String get sortNotes => 'Ordenar notas';

  @override
  String get sortByLastModified => 'Por última modificación';

  @override
  String get sortByDateCreated => 'Por fecha de creación';

  @override
  String get sortByTitle => 'Por título';

  @override
  String get sortByColor => 'Por color';

  @override
  String get importNotes => 'Importar notas';

  @override
  String get switchToGridView => 'Cambiar a vista de cuadrícula';

  @override
  String get switchToListView => 'Cambiar a vista de lista';

  @override
  String get selectPeriod => 'Seleccionar período';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get lastMonth => 'Mes pasado';

  @override
  String get last90Days => 'Últimos 90 días';

  @override
  String get thisYear => 'Este año';

  @override
  String get allTime => 'Todo el historial';

  @override
  String get customDateRange => 'Rango de fechas personalizado…';

  @override
  String get customDateRangeSubtitle =>
      'Elige fechas exactas de inicio y fin en el calendario';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Todas las $count tareas completadas',
      one: '1 tarea completada',
    );
    return '$_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos más',
      one: '1 elemento más',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'Administrar categorías';

  @override
  String get restoreDefaults => 'Restablecer valores predeterminados';

  @override
  String get restoreDefaultCategoriesTitle =>
      '¿Restablecer categorías predeterminadas?';

  @override
  String get restoreDefaultCategoriesContent =>
      'Se eliminarán las categorías personalizadas y las integradas se restablecerán a sus colores y palabras clave predeterminados. Las transacciones existentes conservarán sus etiquetas.';

  @override
  String get categoriesRestored =>
      'Categorías restablecidas a los valores predeterminados';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get editCategory => 'Editar categoría';

  @override
  String get categoryName => 'Nombre de la categoría';

  @override
  String get categoryNameRequired => 'Nombre de categoría requerido';

  @override
  String get categoryNameExists => 'El nombre de la categoría ya existe';

  @override
  String get icon => 'Ícono';

  @override
  String get colour => 'Color';

  @override
  String get keywords => 'Palabras clave';

  @override
  String get addKeywordHint => 'Agregar palabra clave…';

  @override
  String get noKeywords => 'Sin palabras clave';

  @override
  String get deleteCategoryTooltip => 'Eliminar categoría';

  @override
  String get editCategoryTooltip => 'Editar categoría';

  @override
  String get cannotDeleteOtherCategory =>
      'La categoría predeterminada «Otros» no se puede eliminar.';

  @override
  String deleteCategoryTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get deleteCategoryContent =>
      'Las transacciones existentes con esta categoría se reasignarán a «Otros» para preservar el historial.';

  @override
  String get cyclePhaseGuide => 'Guía de fases del ciclo';

  @override
  String get menstrualPhase => 'Fase menstrual';

  @override
  String get menstrualPhaseDays => 'Días 1–5';

  @override
  String get menstrualPhaseDesc =>
      'Desprendimiento del endometrio. Menor nivel de energía; prioriza el descanso, hidratación y movimiento suave.';

  @override
  String get follicularPhase => 'Fase folicular';

  @override
  String get follicularPhaseDays => 'Días 6–13';

  @override
  String get follicularPhaseDesc =>
      'El estrógeno aumenta a medida que maduran los folículos. La energía, el ánimo y el enfoque creativo alcanzan su punto máximo.';

  @override
  String get ovulatoryPhase => 'Fase ovulatoria';

  @override
  String get ovulatoryPhaseDays => 'Días 14–16';

  @override
  String get ovulatoryPhaseDesc =>
      'El pico de hormona luteinizante desencadena la ovulación. Máxima confianza, energía social y fertilidad.';

  @override
  String get lutealPhase => 'Fase lútea';

  @override
  String get lutealPhaseDays => 'Días 17–28';

  @override
  String get lutealPhaseDesc =>
      'Aumenta la progesterona. La energía se interioriza; pueden aparecer síntomas de SPM. Prioriza relajarte.';

  @override
  String get symptomCramps => 'Cólicos';

  @override
  String get symptomBloating => 'Hinchazón';

  @override
  String get symptomHeadache => 'Dolor de cabeza';

  @override
  String get symptomFatigue => 'Fatiga';

  @override
  String get symptomAcne => 'Acné';

  @override
  String get symptomMoodSwings => 'Cambios de humor';

  @override
  String get symptomNausea => 'Náuseas';

  @override
  String get symptomBackache => 'Dolor de espalda';

  @override
  String get intensityLight => 'Leve';

  @override
  String get intensityMedium => 'Moderada';

  @override
  String get intensityHeavy => 'Intensa';

  @override
  String get startDateAfterEndDate =>
      'La fecha de inicio no puede ser posterior a la de finalización';

  @override
  String get overlapDetectedTitle => 'Superposición detectada';

  @override
  String get overlapDetectedMessage =>
      'Las fechas seleccionadas se superponen con un período ya registrado. Ajusta las fechas.';

  @override
  String notesMovedToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas movidas a la papelera',
      one: 'Nota movida a la papelera',
    );
    return '$_temp0';
  }

  @override
  String get lockedNoteDescription =>
      'Esta nota está protegida con contraseña o biometría.';

  @override
  String get unlockNote => 'Desbloquear nota';

  @override
  String get timeJustNow => 'Justo ahora';

  @override
  String timeMinutesAgo(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'hace $hours h';
  }

  @override
  String get appLockSubtitle =>
      'Se requiere autenticación para acceder al contenido';

  @override
  String get appLockAuthReason => 'Autentícate para acceder a la app';

  @override
  String get appLockNoCredentials =>
      'No hay bloqueo de pantalla ni biometría configurados en este dispositivo.';

  @override
  String get appLockAuthFailed => 'Error de autenticación. Inténtalo de nuevo.';

  @override
  String get disableAppLock => 'Desactivar bloqueo de la app';

  @override
  String get autoLockTimeoutTitle => 'Tiempo de bloqueo automático';

  @override
  String get timeoutImmediately => 'Inmediatamente';

  @override
  String timeoutSeconds(int seconds) {
    return '$seconds segundos';
  }

  @override
  String timeoutMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get peerToPeerSync => 'Sincronización P2P';

  @override
  String get p2pDeviceSync => 'Sincronización P2P entre dispositivos';

  @override
  String get p2pDeviceSyncSubtitle =>
      'Sincronización Wi-Fi sin nube para notas y finanzas';

  @override
  String get encryptedJsonBackups => 'Copias de seguridad JSON cifradas';

  @override
  String get exportBackup => 'Exportar copia';

  @override
  String get exportBackupSubtitle =>
      'Guarda notas y registros en un archivo cifrado';

  @override
  String get importBackup => 'Importar copia';

  @override
  String get importBackupSubtitle => 'Restaurar desde una copia JSON cifrada';

  @override
  String get snapshotsAndRecovery => 'Instantáneas y recuperación';

  @override
  String get snapshotsAndRecoverySubtitle =>
      'Inspeccionar o restaurar instantáneas automáticas de la base de datos';

  @override
  String get automatedBackgroundBackups =>
      'Copias automáticas en segundo plano';

  @override
  String get automaticBackups => 'Copias automáticas';

  @override
  String get automaticBackupsSubtitle =>
      'Programa copias locales cifradas periódicas';

  @override
  String get backupFrequency => 'Frecuencia de copia';

  @override
  String get backupFrequencySubtitle => 'Frecuencia de las copias automáticas';

  @override
  String get backupLocation => 'Ubicación de copias';

  @override
  String get secureAppStorage => 'Almacenamiento seguro de la app';

  @override
  String get lastAutoBackup => 'Última copia automática';

  @override
  String get lastAutoBackupSubtitle => 'Copia exitosa más reciente';

  @override
  String get runAutoBackupNow => 'Ejecutar copia ahora';

  @override
  String get runAutoBackupNowSubtitle =>
      'Inicia y verifica la copia en segundo plano al instante';

  @override
  String get masterP2pDeviceSync => 'Sincronización P2P principal';

  @override
  String get crossNetworkRelaySettings => 'Ajustes de relé entre redes';

  @override
  String get syncAuditAndActivity => 'Auditoría y actividad de sync';

  @override
  String get biDirectionalP2pSync => 'Sincronización P2P bidireccional';

  @override
  String get syncingStatus => 'Sincronizando...';

  @override
  String get errorStatus => 'Error';

  @override
  String get unlinkedStatus => 'Sin vincular';

  @override
  String get readyStatus => 'Listo';

  @override
  String get p2pUnlinkedSubtitle =>
      'Vincula un teléfono o tableta cercana para fusionar notas, finanzas y ajustes sin conexión';

  @override
  String get p2pReadySubtitle =>
      'Fusiona notas, finanzas y ajustes sin sobrescribir datos';

  @override
  String get pairDevice => 'Vincular dispositivo';

  @override
  String get pairAgain => 'Vincular de nuevo';

  @override
  String get myQr => 'Mi QR';

  @override
  String get syncAndMergeNow => 'Sincronizar y fusionar';

  @override
  String get syncCompletedSuccess => 'Sincronización completada correctamente';

  @override
  String get syncFailed => 'Error al sincronizar';

  @override
  String get retry => 'Reintentar';

  @override
  String get recentSyncEvents => 'Eventos de sincronización recientes';

  @override
  String get noSyncActivityYet => 'Aún no hay actividad registrada';

  @override
  String get noSyncActivitySubtitle =>
      'Los eventos aparecerán aquí cuando dos dispositivos intercambien datos.';

  @override
  String get searchingWifiSubnet => 'Buscando subred Wi-Fi local...';

  @override
  String get syncAllPairedDevicesNow =>
      'Sincronizar todos los dispositivos ahora';

  @override
  String get testPing => 'Ping de prueba';

  @override
  String get thisDeviceHostingInfo => 'Info de este dispositivo';

  @override
  String get modularEcosystem => 'Ecosistema modular';

  @override
  String get financialManager => 'Gestor financiero';

  @override
  String get financialManagerSubtitle =>
      'Control de gastos, SMS bancarios y presupuestos';

  @override
  String get periodTracker => 'Registro menstrual';

  @override
  String get periodTrackerSubtitle =>
      'Seguimiento opcional del ciclo y predicciones';

  @override
  String get ledgerAndBankAutomation => 'Automatización bancaria y de libro';

  @override
  String get currencySubtitle => 'Símbolo de moneda base';

  @override
  String get smsBankImport => 'Importación bancaria por SMS';

  @override
  String get smsBankImportSubtitle =>
      'Importa y analiza transacciones desde SMS bancarios automáticamente';

  @override
  String get smsAutomationRules => 'Reglas de SMS y bancos';

  @override
  String get smsAutomationRulesSubtitle =>
      'Auto-sync, reglas de importación, bloqueos y pruebas';

  @override
  String get budgetsAndGoals => 'Presupuestos y metas';

  @override
  String get budgetsAndGoalsSubtitle =>
      'Límites mensuales, gráficos analíticos y objetivos';

  @override
  String get categoriesAndBudgets => 'Categorías y presupuestos';

  @override
  String get categoriesAndBudgetsSubtitle =>
      'Personaliza palabras clave, límites y colores';

  @override
  String get onDeviceSmartAi => 'IA inteligente en el dispositivo';

  @override
  String get onDeviceSmartAiSubtitle =>
      'Limpieza de comercios y categorización automática';

  @override
  String get accountsVaultsAndSplits => 'Cuentas, bóveda y divisiones';

  @override
  String get recurringRulesTitle => 'Suscripciones y reglas recurrentes';

  @override
  String get recurringRulesSubtitle =>
      'Controla facturas repetidas, ingresos y recordatorios';

  @override
  String get manageSubscriptions => 'Gestionar suscripciones';

  @override
  String get manageSubscriptionsSubtitle =>
      'Administra facturas periódicas, salarios y reglas';

  @override
  String get savingsVaultDualAccounts => 'Bóveda de ahorro y cuentas duales';

  @override
  String get savingsVaultDualAccountsSubtitle =>
      'Separa el flujo diario de los ahorros a largo plazo';

  @override
  String get accountNamesAndRouting => 'Nombres de cuenta y enrutamiento';

  @override
  String get splitBillsAndSharedDebts => 'Dividir cuentas y deudas';

  @override
  String get splitBillsAndSharedDebtsSubtitle =>
      'Gastos grupales, saldos con amigos y escáner de recibos';

  @override
  String get defaultPaymentDetails => 'Datos de pago predeterminados';

  @override
  String get healthAndPeriodTracker => 'Salud y registro menstrual';

  @override
  String get discreetPrivacyMode => 'Modo de privacidad discreta';

  @override
  String get discreetPrivacyModeSubtitle =>
      'Oculta días y fases del ciclo en el panel hasta tocar';

  @override
  String get discreetNotificationText => 'Texto de notificación discreta';

  @override
  String get discreetNotificationTextSubtitle =>
      'Texto mostrado en alertas de predicción del ciclo';

  @override
  String get autoBackupRecoveryKey =>
      'Clave de recuperación de copia automática';

  @override
  String get autoBackupRecoveryKeySubtitle =>
      'Copia o importa la clave para restaurar copias cifradas';

  @override
  String get perModulePrivacyLocks => 'Bloqueos por módulo y protección';

  @override
  String get lockFinances => 'Bloquear pestaña Finanzas';

  @override
  String get lockFinancesSubtitle =>
      'Requiere autenticación para abrir Finanzas';

  @override
  String get lockHealth => 'Bloquear pestaña Salud';

  @override
  String get lockHealthSubtitle => 'Requiere autenticación para abrir Salud';

  @override
  String get screenshotShield => 'Escudo contra capturas';

  @override
  String get screenshotShieldSubtitle =>
      'Bloquea capturas y grabación de pantalla en Android';

  @override
  String get lockAppNow => 'Bloquear app ahora';
}
