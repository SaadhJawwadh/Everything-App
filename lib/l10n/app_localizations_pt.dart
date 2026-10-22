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

  @override
  String get preferencesAndWorkspaces => 'Preferências e espaços';

  @override
  String get notesAndEditorWorkspace => 'Notas e editor';

  @override
  String get financesAndHealthModules => 'Finanças e saúde';

  @override
  String get privacyAndSecurity => 'Privacidade e segurança';

  @override
  String get syncAndBackups => 'Sincronização e cópias de segurança';

  @override
  String get aboutAndDeviceAi => 'Sobre e IA';

  @override
  String get startFromTemplate => 'Começar com modelo';

  @override
  String get templateMeetingNotes => 'Notas de reunião';

  @override
  String get templateMeetingNotesDesc => 'Pauta, discussão e itens de ação';

  @override
  String get templateShoppingList => 'Lista de compras';

  @override
  String get templateShoppingListDesc => 'Lista de verificação para marcar';

  @override
  String get templateJournal => 'Diário';

  @override
  String get templateJournalDesc => 'Perguntas de reflexão diária';

  @override
  String get themeAndColorSystem => 'Tema e sistema de cores';

  @override
  String get appThemeMode => 'Modo do tema';

  @override
  String get dynamicWallpaperTheme => 'Papel de parede dinâmico';

  @override
  String get dynamicWallpaperSubtitle =>
      'Cores combinando com o fundo do dispositivo (Android 12+)';

  @override
  String get interactionAndAccessibility => 'Interação e acessibilidade';

  @override
  String get tactileHaptics => 'Retorno tátil';

  @override
  String get tactileHapticsSubtitle =>
      'Feedback tátil contido para botões e ações';

  @override
  String get textScale => 'Tamanho do texto';

  @override
  String get textScaleSubtitle => 'Escala global da fonte';

  @override
  String get textScaleSmall => 'Pequeno';

  @override
  String get textScaleMedium => 'Médio';

  @override
  String get textScaleLarge => 'Grande';

  @override
  String get appLanguage => 'Idioma do aplicativo';

  @override
  String get selectCurrency => 'Selecionar moeda';

  @override
  String noSettingsFound(String query) {
    return 'Nenhuma configuração encontrada para \"$query\"';
  }

  @override
  String get quickSuggestions => 'Sugestões rápidas:';

  @override
  String get clearSelection => 'Limpar seleção';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get deselectAll => 'Desmarcar tudo';

  @override
  String get closeSearch => 'Fechar pesquisa';

  @override
  String get clearQuery => 'Limpar consulta';

  @override
  String get createNewFolder => 'Criar nova pasta';

  @override
  String get folderName => 'Nome da pasta';

  @override
  String get filterByFolder => 'Filtrar por pasta';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get allNotes => 'Todas as notas';

  @override
  String get checklistsAndTasks => 'Listas e tarefas';

  @override
  String get archivedNotes => 'Notas arquivadas';

  @override
  String get trashBin => 'Lixeira';

  @override
  String get sortNotes => 'Ordenar notas';

  @override
  String get sortByLastModified => 'Por última modificação';

  @override
  String get sortByDateCreated => 'Por data de criação';

  @override
  String get sortByTitle => 'Por título';

  @override
  String get sortByColor => 'Por cor';

  @override
  String get importNotes => 'Importar notas';

  @override
  String get switchToGridView => 'Alternar para exibição em grade';

  @override
  String get switchToListView => 'Alternar para exibição em lista';

  @override
  String get selectPeriod => 'Selecionar período';

  @override
  String get thisMonth => 'Este mês';

  @override
  String get lastMonth => 'Mês passado';

  @override
  String get last90Days => 'Últimos 90 dias';

  @override
  String get thisYear => 'Este ano';

  @override
  String get allTime => 'Todo o histórico';

  @override
  String get customDateRange => 'Intervalo personalizado…';

  @override
  String get customDateRangeSubtitle =>
      'Escolha as datas de início e fim no calendário';

  @override
  String allTasksCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Todas as $count tarefas concluídas',
      one: '1 tarefa concluída',
    );
    return '$_temp0';
  }

  @override
  String moreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count itens',
      one: 'mais 1 item',
    );
    return '+$_temp0';
  }

  @override
  String get manageCategories => 'Gerenciar categorias';

  @override
  String get restoreDefaults => 'Restaurar padrões';

  @override
  String get restoreDefaultCategoriesTitle => 'Restaurar categorias padrão?';

  @override
  String get restoreDefaultCategoriesContent =>
      'As categorias personalizadas serão removidas e as integradas redefinidas para as cores e palavras-chave padrão. As transações existentes mantêm seus rótulos.';

  @override
  String get categoriesRestored => 'Categorias restauradas para os padrões';

  @override
  String get newCategory => 'Nova categoria';

  @override
  String get editCategory => 'Editar categoria';

  @override
  String get categoryName => 'Nome da categoria';

  @override
  String get categoryNameRequired => 'Nome da categoria obrigatório';

  @override
  String get categoryNameExists => 'O nome da categoria já existe';

  @override
  String get icon => 'Ícone';

  @override
  String get colour => 'Cor';

  @override
  String get keywords => 'Palavras-chave';

  @override
  String get addKeywordHint => 'Adicionar palavra-chave…';

  @override
  String get noKeywords => 'Sem palavras-chave';

  @override
  String get deleteCategoryTooltip => 'Excluir categoria';

  @override
  String get editCategoryTooltip => 'Editar categoria';

  @override
  String get cannotDeleteOtherCategory =>
      'A categoria padrão «Outros» não pode ser excluída.';

  @override
  String deleteCategoryTitle(String name) {
    return 'Excluir \"$name\"?';
  }

  @override
  String get deleteCategoryContent =>
      'As transações existentes com esta categoria serão reatribuídas a «Outros» para preservar seu histórico.';

  @override
  String get cyclePhaseGuide => 'Guia de fases do ciclo';

  @override
  String get menstrualPhase => 'Fase menstrual';

  @override
  String get menstrualPhaseDays => 'Dias 1–5';

  @override
  String get menstrualPhaseDesc =>
      'Descamação do endométrio. Energia mais baixa; priorize descanso, hidratação e movimentos leves.';

  @override
  String get follicularPhase => 'Fase folicular';

  @override
  String get follicularPhaseDays => 'Dias 6–13';

  @override
  String get follicularPhaseDesc =>
      'O estrogênio aumenta com o amadurecimento dos folículos. Energia, humor e foco criativo atingem o pico.';

  @override
  String get ovulatoryPhase => 'Fase ovulatória';

  @override
  String get ovulatoryPhaseDays => 'Dias 14–16';

  @override
  String get ovulatoryPhaseDesc =>
      'O pico de hormônio luteinizante desencadeia a ovulação. Pico de confiança, energia social e fertilidade.';

  @override
  String get lutealPhase => 'Fase lútea';

  @override
  String get lutealPhaseDays => 'Dias 17–28';

  @override
  String get lutealPhaseDesc =>
      'A progesterona sobe. A energia se volta para dentro; sintomas de TPM podem ocorrer. Priorize desacelerar.';

  @override
  String get symptomCramps => 'Cólicas';

  @override
  String get symptomBloating => 'Inchaço';

  @override
  String get symptomHeadache => 'Dor de cabeça';

  @override
  String get symptomFatigue => 'Fadiga';

  @override
  String get symptomAcne => 'Acne';

  @override
  String get symptomMoodSwings => 'Oscilações de humor';

  @override
  String get symptomNausea => 'Náusea';

  @override
  String get symptomBackache => 'Dor nas costas';

  @override
  String get intensityLight => 'Leve';

  @override
  String get intensityMedium => 'Média';

  @override
  String get intensityHeavy => 'Intensa';

  @override
  String get startDateAfterEndDate =>
      'A data de início não pode ser posterior à data de término';

  @override
  String get overlapDetectedTitle => 'Sobreposição detectada';

  @override
  String get overlapDetectedMessage =>
      'As datas selecionadas se sobrepõem a um período já registrado. Ajuste as datas.';
}
