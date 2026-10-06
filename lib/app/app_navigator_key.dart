import 'package:flutter/material.dart';

/// Navigator key reachable from outside the current navigator tree —
/// used by deep-link handler to open [TaskDetailSheet] even when the caller
/// does not have a direct [BuildContext] into the active home screen.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
