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
}
