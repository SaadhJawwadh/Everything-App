import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import '../theme/app_layout.dart';

/// Centralized Navigation Router & Route Names Single Source of Truth
class AppRouter {
  AppRouter._();

  // Named Route Strings
  static const String home = '/';
  static const String noteEditor = '/note-editor';
  static const String filteredNotes = '/filtered-notes';
  static const String manageTags = '/manage-tags';
  static const String financialManager = '/financial-manager';
  static const String transactionEditor = '/transaction-editor';
  static const String categoryManagement = '/category-management';
  static const String periodTracker = '/period-tracker';
  static const String settings = '/settings';
  static const String smsRules = '/sms-rules';
  static const String smsContacts = '/sms-contacts';
  static const String changelog = '/changelog';
  static const String p2pSync = '/p2p-sync';

  /// Pushes [page] respecting the platform's native page transition theme
  /// (PredictiveBack on Android 14+, Cupertino swipe-to-pop on iOS).
  static Future<T?> push<T>(BuildContext context, Widget page, {RouteSettings? settings}) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (_) => page,
        settings: settings,
      ),
    );
  }

  /// Pushes named route [routeName] with optional [arguments].
  static Future<T?> pushNamed<T>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// A horizontal shared-axis route builder.
  static Route<T> sharedAxis<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppLayout.animDefault,
      reverseTransitionDuration: AppLayout.animDefault,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
    );
  }
}
