// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Everything App';

  @override
  String get navNotes => '笔记';

  @override
  String get navFinances => '财务';

  @override
  String get navTracker => '周期';

  @override
  String get navSplitBills => '分摊账单';

  @override
  String get greetingMorning => '早上好，阳光明媚！';

  @override
  String get greetingAfternoon => '吃午饭了吗？';

  @override
  String get greetingEvening => '晚上好！';

  @override
  String get greetingNight => '该睡觉了！';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条笔记',
      one: '1 条笔记',
    );
    return '$_temp0';
  }

  @override
  String get searchNotes => '搜索笔记...';

  @override
  String get searchFinances => '搜索交易...';

  @override
  String get settingsTitle => '设置';

  @override
  String get newNote => '新建笔记';

  @override
  String get newTransaction => '新建交易';

  @override
  String get search => '搜索';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get done => '完成';

  @override
  String get close => '关闭';

  @override
  String get filter => '筛选';

  @override
  String get sort => '排序';

  @override
  String get confirm => '确认';

  @override
  String get back => '返回';

  @override
  String get copy => '复制';

  @override
  String get share => '分享';

  @override
  String get clear => '清除';

  @override
  String get apply => '应用';

  @override
  String get discard => '放弃';

  @override
  String get undo => '撤销';

  @override
  String get all => '全部';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get pinnedNotes => '置顶笔记';

  @override
  String get otherNotes => '其他笔记';

  @override
  String get emptyNotesTitle => '暂无笔记';

  @override
  String get emptyNotesSubtitle => '点击 + 记录您的想法';

  @override
  String get archive => '归档';

  @override
  String get trash => '废纸篓';

  @override
  String get restore => '恢复';

  @override
  String get deletePermanently => '永久删除';

  @override
  String get lockedNote => '锁定笔记';

  @override
  String get appLocked => '应用已锁定';

  @override
  String get unlock => '解锁';

  @override
  String get noteTitlePlaceholder => '标题';

  @override
  String get noteBodyPlaceholder => '开始输入...';

  @override
  String get manageTags => '管理标签';

  @override
  String get income => '收入';

  @override
  String get expense => '支出';

  @override
  String get balance => '余额';

  @override
  String get netBalance => '净余额';

  @override
  String get monthlySpending => '本月支出';

  @override
  String get dailySafeToSpend => '今日预算';

  @override
  String get ledger => '账本';

  @override
  String get breakdown => '明细';

  @override
  String get budgets => '预算';

  @override
  String get savings => '储蓄';

  @override
  String get savingsGoals => '储蓄目标';

  @override
  String get deposit => '存入';

  @override
  String get dailyAccount => '日常账户';

  @override
  String get savingsVault => '储蓄金库';

  @override
  String get targetAmount => '目标金额';

  @override
  String get currentAmount => '当前金额';

  @override
  String get noTransactionsYet => '暂无财务数据';

  @override
  String get categories => '类别';

  @override
  String get splitBillsTitle => '分摊账单';

  @override
  String get settleUp => '结算';

  @override
  String get equalSplit => '平分';

  @override
  String get customSplit => '自定义分摊';

  @override
  String get paidBy => '支付人';

  @override
  String get sendReminder => '发送提醒';

  @override
  String cycleDay(int day) {
    return '周期第 $day 天';
  }

  @override
  String get periodLog => '经期记录';

  @override
  String get symptoms => '症状';

  @override
  String get periodStart => '经期开始';

  @override
  String get periodEnd => '经期结束';

  @override
  String get regular => '规律';

  @override
  String get irregular => '不规律';

  @override
  String get appearance => '外观与界面';

  @override
  String get theme => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '系统默认';

  @override
  String get currency => '货币';

  @override
  String get security => '安全与隐私';

  @override
  String get backupRestore => '备份与恢复';

  @override
  String get about => '关于';

  @override
  String get onDeviceAi => '设备端 AI';

  @override
  String get preferencesAndWorkspaces => '偏好与工作区';

  @override
  String get notesAndEditorWorkspace => '笔记与编辑器';

  @override
  String get financesAndHealthModules => '财务与健康';

  @override
  String get privacyAndSecurity => '隐私与安全';

  @override
  String get syncAndBackups => '同步与备份';

  @override
  String get aboutAndDeviceAi => '关于与端侧AI';

  @override
  String get startFromTemplate => '从模板开始';

  @override
  String get templateMeetingNotes => '会议记录';

  @override
  String get templateMeetingNotesDesc => '议程、讨论与待办事项';

  @override
  String get templateShoppingList => '购物清单';

  @override
  String get templateShoppingListDesc => '随时可勾选的清单';

  @override
  String get templateJournal => '日记';

  @override
  String get templateJournalDesc => '每日反思提示';

  @override
  String get themeAndColorSystem => '主题与配色';

  @override
  String get appThemeMode => '应用主题模式';

  @override
  String get dynamicWallpaperTheme => '动态壁纸取色';

  @override
  String get dynamicWallpaperSubtitle => '随设备壁纸调整应用色彩 (Android 12+)';

  @override
  String get interactionAndAccessibility => '交互与无障碍';

  @override
  String get tactileHaptics => '触感震动反馈';

  @override
  String get tactileHapticsSubtitle => '滑块、长按与动作的轻微触感反馈';

  @override
  String get textScale => '字体大小';

  @override
  String get textScaleSubtitle => '全局字号缩放';

  @override
  String get textScaleSmall => '小';

  @override
  String get textScaleMedium => '中';

  @override
  String get textScaleLarge => '大';

  @override
  String get appLanguage => '应用语言';

  @override
  String get selectCurrency => '选择货币';

  @override
  String noSettingsFound(String query) {
    return '未找到与 \"$query\" 相关的设置';
  }

  @override
  String get quickSuggestions => '快捷搜索建议:';

  @override
  String get clearSelection => '清除选择';

  @override
  String selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get clearQuery => '清空搜索词';

  @override
  String get createNewFolder => '创建新文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get filterByFolder => '按文件夹过滤';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get allNotes => '全部笔记';

  @override
  String get checklistsAndTasks => '清单与任务';

  @override
  String get archivedNotes => '归档笔记';

  @override
  String get trashBin => '回收站';

  @override
  String get sortNotes => '排序笔记';

  @override
  String get sortByLastModified => '按修改时间排序';

  @override
  String get sortByDateCreated => '按创建时间排序';

  @override
  String get sortByTitle => '按标题排序';

  @override
  String get sortByColor => '按颜色排序';

  @override
  String get importNotes => '导入笔记';

  @override
  String get switchToGridView => '切换为网格视图';

  @override
  String get switchToListView => '切换为列表视图';

  @override
  String get selectPeriod => '选择时间段';

  @override
  String get thisMonth => '本月';

  @override
  String get lastMonth => '上个月';

  @override
  String get last90Days => '近90天';

  @override
  String get thisYear => '今年';

  @override
  String get allTime => '全部历史记录';

  @override
  String get customDateRange => '自定义日期范围…';

  @override
  String get customDateRangeSubtitle => '在日历中选择起始与结束日期';

  @override
  String allTasksCompleted(int count) {
    return '全部 $count 项任务已完成';
  }

  @override
  String moreItems(int count) {
    return '+还有 $count 项';
  }

  @override
  String get manageCategories => '管理分类';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get restoreDefaultCategoriesTitle => '恢复默认分类？';

  @override
  String get restoreDefaultCategoriesContent =>
      '自定义分类将被移除，内置分类将重置为默认颜色和关键字。现有交易将保留其分类标签。';

  @override
  String get categoriesRestored => '分类已恢复为默认值';

  @override
  String get newCategory => '新建分类';

  @override
  String get editCategory => '编辑分类';

  @override
  String get categoryName => '分类名称';

  @override
  String get categoryNameRequired => '分类名称必填';

  @override
  String get categoryNameExists => '分类名称已存在';

  @override
  String get icon => '图标';

  @override
  String get colour => '颜色';

  @override
  String get keywords => '关键字';

  @override
  String get addKeywordHint => '添加关键字…';

  @override
  String get noKeywords => '无关键字';

  @override
  String get deleteCategoryTooltip => '删除分类';

  @override
  String get editCategoryTooltip => '编辑分类';

  @override
  String get cannotDeleteOtherCategory => '无法删除“其他”默认分类。';

  @override
  String deleteCategoryTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get deleteCategoryContent => '包含该分类的现有交易将重新分配至“其他”，以确保记录完整。';

  @override
  String get cyclePhaseGuide => '周期阶段指南';

  @override
  String get menstrualPhase => '月经期';

  @override
  String get menstrualPhaseDays => '第 1–5 天';

  @override
  String get menstrualPhaseDesc => '子宫内膜脱落。精力偏低；建议充分休息、保持水分并适度进行温和活动。';

  @override
  String get follicularPhase => '卵泡期';

  @override
  String get follicularPhaseDays => '第 6–13 天';

  @override
  String get follicularPhaseDesc => '卵泡发育成熟，雌激素上升。精力充沛，情绪积极，专注力与创造力达到高峰。';

  @override
  String get ovulatoryPhase => '排卵期';

  @override
  String get ovulatoryPhaseDays => '第 14–16 天';

  @override
  String get ovulatoryPhaseDesc => '黄体生成素激增引发排卵。自信心、社交活力与受孕率达到顶峰。';

  @override
  String get lutealPhase => '黄体期';

  @override
  String get lutealPhaseDays => '第 17–28 天';

  @override
  String get lutealPhaseDesc => '孕酮升高。精力内敛；可能出现经前期综合征（PMS）症状。建议放松身心、减缓节奏。';

  @override
  String get symptomCramps => '腹痛抽筋';

  @override
  String get symptomBloating => '腹胀';

  @override
  String get symptomHeadache => '头痛';

  @override
  String get symptomFatigue => '疲劳';

  @override
  String get symptomAcne => '痘痘/痤疮';

  @override
  String get symptomMoodSwings => '情绪波动';

  @override
  String get symptomNausea => '恶心';

  @override
  String get symptomBackache => '腰背酸痛';

  @override
  String get intensityLight => '轻度';

  @override
  String get intensityMedium => '中度';

  @override
  String get intensityHeavy => '重度';

  @override
  String get startDateAfterEndDate => '开始日期不能晚于结束日期';

  @override
  String get overlapDetectedTitle => '检测到日期重叠';

  @override
  String get overlapDetectedMessage => '所选日期与现有记录重叠，请调整日期。';
}
