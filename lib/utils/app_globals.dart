import 'package:flutter/material.dart';

/// App-level keys so services and popped routes can reach the navigator and
/// snackbars without a local BuildContext (notification taps, post-pop undo).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Semantic tab navigation request triggered by notifications or deep links
/// (`'notes' | 'finances' | 'health'`). Cleared once handled by `HomeScreen`.
final ValueNotifier<String?> appTabNavigationRequest = ValueNotifier<String?>(null);
