import 'package:flutter/foundation.dart';

/// Bottom-navigation branch index currently on screen.
///
/// The shell keeps every branch alive (that is what preserves the maps), so a
/// page's `initState` runs once and its data goes stale. Pages listen here and
/// reload when their branch becomes visible again.
///
/// Mirrors the `authRedirectNotifier` pattern in `app_router.dart`: a plain
/// [ValueNotifier] the shell writes and the pages read, with no rebuild of the
/// widget tree.
final ValueNotifier<int> activeBranchNotifier = ValueNotifier<int>(0);

/// Branch shown by the middle tab: ride history for a passenger, earnings for
/// a driver. Both live in branch 1 of the shell.
const int middleBranchIndex = 1;
