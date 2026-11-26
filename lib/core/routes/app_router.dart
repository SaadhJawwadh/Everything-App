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

  /// Builds a platform-adaptive [MaterialPageRoute] respecting native transitions
  /// (PredictiveBack on Android 14+, Cupertino swipe-to-pop on iOS).
  static Route<T> pageRoute<T>(
    Widget page, {
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return MaterialPageRoute<T>(
      builder: (_) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// Pushes [page] respecting the platform's native page transition theme
  /// (PredictiveBack on Android 14+, Cupertino swipe-to-pop on iOS).
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      pageRoute<T>(
        page,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Pushes named route [routeName] with optional [arguments].
  static Future<T?> pushNamed<T>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// A horizontal shared-axis route builder honoring reduced-motion accessibility.
  static Route<T> sharedAxis<T>(Widget page, {BuildContext? context}) {
    final reduceMotion = context != null && AppLayout.shouldReduceMotion(context);
    return PageRouteBuilder<T>(
      transitionDuration: reduceMotion ? Duration.zero : AppLayout.animDefault,
      reverseTransitionDuration: reduceMotion ? Duration.zero : AppLayout.animDefault,
      pageBuilder: (ctx, animation, secondaryAnimation) => page,
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        if (AppLayout.shouldReduceMotion(ctx)) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }
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
