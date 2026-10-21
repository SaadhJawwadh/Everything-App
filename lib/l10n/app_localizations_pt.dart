// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => 'Notas';

  @override
  String get navFinances => 'Finanças';

  @override
  String get navTracker => 'Ciclo';

  @override
  String get navSplitBills => 'Dividir Contas';

  @override
  String get greetingMorning => 'Bom dia!';

  @override
  String get greetingAfternoon => 'Já almoçou?';

  @override
  String get greetingEvening => 'Boa noite!';

  @override
  String get greetingNight => 'Hora de dormir!';

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
  String get searchNotes => 'Pesquisar notas...';

  @override
  String get searchFinances => 'Pesquisar transações...';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get newNote => 'Nova Nota';

  @override
  String get newTransaction => 'Nova Transação';

  @override
  String get search => 'Pesquisar';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get edit => 'Editar';

  @override
  String get done => 'Concluído';

  @override
  String get close => 'Fechar';

  @override
  String get filter => 'Filtrar';

  @override
  String get sort => 'Ordenar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get back => 'Voltar';

  @override
  String get copy => 'Copiar';

  @override
  String get share => 'Compartilhar';

  @override
  String get clear => 'Limpar';

  @override
  String get apply => 'Aplicar';

  @override
  String get discard => 'Descartar';

  @override
  String get undo => 'Desfazer';

  @override
  String get all => 'Todos';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get pinnedNotes => 'Notas Fixadas';

  @override
  String get otherNotes => 'Outras Notas';

  @override
  String get emptyNotesTitle => 'Nenhuma nota ainda';

  @override
  String get emptyNotesSubtitle => 'Toque em + para registrar seus pensamentos';

  @override
  String get archive => 'Arquivo';

  @override
  String get trash => 'Lixeira';

  @override
  String get restore => 'Restaurar';

  @override
  String get deletePermanently => 'Excluir Definitivamente';

  @override
  String get lockedNote => 'Nota bloqueada';

  @override
  String get appLocked => 'Aplicativo Bloqueado';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get noteTitlePlaceholder => 'Título';

  @override
  String get noteBodyPlaceholder => 'Comece a digitar...';

  @override
  String get manageTags => 'Gerenciar Tags';

  @override
  String get income => 'Receita';

  @override
  String get expense => 'Despesa';

  @override
  String get balance => 'Saldo';

  @override
  String get netBalance => 'Saldo Líquido';

  @override
  String get monthlySpending => 'Gastos Mensais';

  @override
  String get dailySafeToSpend => 'Disponível para Gastar Hoje';

  @override
  String get ledger => 'Livro-razão';

  @override
  String get breakdown => 'Divisão';

  @override
  String get budgets => 'Orçamentos';

  @override
  String get savings => 'Economias';

  @override
  String get savingsGoals => 'Metas de Poupança';

  @override
  String get deposit => 'Depositar';

  @override
  String get dailyAccount => 'Conta Diária';

  @override
  String get savingsVault => 'Cofre de Poupança';

  @override
  String get targetAmount => 'Valor Alvo';

  @override
  String get currentAmount => 'Valor Atual';

  @override
  String get noTransactionsYet => 'Nenhum dado financeiro ainda';

  @override
  String get categories => 'Categorias';

  @override
  String get splitBillsTitle => 'Dividir Contas';

  @override
  String get settleUp => 'Acertar Contas';

  @override
  String get equalSplit => 'Divisão Igual';

  @override
  String get customSplit => 'Divisão Personalizada';

  @override
  String get paidBy => 'Pago por';

  @override
  String get sendReminder => 'Enviar Lembrete';

  @override
  String cycleDay(int day) {
    return 'Dia do Ciclo $day';
  }

  @override
  String get periodLog => 'Registro de Menstruação';

  @override
  String get symptoms => 'Sintomas';

  @override
  String get periodStart => 'Menstruação Iniciada';

  @override
  String get periodEnd => 'Menstruação Encerrada';

  @override
  String get regular => 'Regular';

  @override
  String get irregular => 'Irregular';

  @override
  String get appearance => 'Aparência e Interface';

  @override
  String get theme => 'Tema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeSystem => 'Padrão do Sistema';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Padrão do Sistema';

  @override
  String get currency => 'Moeda';

  @override
  String get security => 'Segurança e Privacidade';

  @override
  String get backupRestore => 'Backup e Restauração';

  @override
  String get about => 'Sobre';

  @override
  String get onDeviceAi => 'IA no Dispositivo';
}
