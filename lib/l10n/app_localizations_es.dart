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
  String get restore => 'Restaurar';

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
}
