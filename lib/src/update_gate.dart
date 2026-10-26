import 'package:flutter/material.dart';

import 'update_controller.dart';
import 'update_screens.dart';

/// How the gate behaves when an update is available.
enum GateBehavior {
  /// Block the whole child tree behind a full-screen update page.
  block,

  /// Render the child normally and show a dismissible card on top.
  banner,
}

/// Widget that listens to a [PrismUpdateController] and renders the right
/// update experience over [child].
///
/// - Forced updates always render [forcedBuilder] (or a default full screen).
/// - Soft updates follow [behavior]: a blocking page or a floating card.
/// - Everything else renders [child] untouched.
class PrismUpdateGate extends StatelessWidget {
  /// Creates an update gate.
  const PrismUpdateGate({
    required this.controller,
    required this.child,
    this.behavior = GateBehavior.block,
    this.forcedBuilder,
    this.softUpdateBuilder,
    this.checkingBuilder,
    this.failureBuilder,
    super.key,
  });

  /// The controller to listen to.
  final PrismUpdateController controller;

  /// The app content.
  final Widget child;

  /// Behavior for soft (optional) updates.
  final GateBehavior behavior;

  /// Builds the blocking UI for forced updates.
  final WidgetBuilder? forcedBuilder;

  /// Builds the UI for soft updates, overriding [behavior].
  final WidgetBuilder? softUpdateBuilder;

  /// Builds UI shown while a check is in flight. Defaults to [child].
  final WidgetBuilder? checkingBuilder;

  /// Builds UI shown when the check fails. Defaults to [child] —
  /// an update check failing should never break the app.
  final WidgetBuilder? failureBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return switch (state) {
          PrismUpdateAvailable(isForced: true) => forcedBuilder != null
              ? forcedBuilder!(context)
              : PrismForceUpdateScreen(state: state),
          PrismUpdateAvailable() => softUpdateBuilder != null
              ? softUpdateBuilder!(context)
              : behavior == GateBehavior.block
                  ? PrismForceUpdateScreen(state: state, canDismiss: true)
                  : _SoftUpdateOverlay(
                      state: state,
                      child: child,
                    ),
          PrismUpdateChecking() => checkingBuilder?.call(context) ?? child,
          PrismUpdateSkipped() => child,
          PrismUpdateFailure() => failureBuilder?.call(context) ?? child,
          _ => child,
        };
      },
    );
  }
}

class _SoftUpdateOverlay extends StatelessWidget {
  const _SoftUpdateOverlay({required this.state, required this.child});

  final PrismUpdateAvailable state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: PrismSoftUpdateCard(state: state),
        ),
      ],
    );
  }
}
