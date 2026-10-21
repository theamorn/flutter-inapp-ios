import 'dart:ui';

/// Decides whether the badge game should be running.
///
/// Two independent reasons to stop: the host scrolled the tile off screen,
/// or the app (or this tab) left the foreground. The game runs only when
/// neither applies, and [onChanged] fires only when that answer flips. One
/// owner for the decision matters because Flame's own background handling
/// resumes a game on return even when the tile is still off screen.
class PromoRunGate {
  PromoRunGate({required this.onChanged});

  final void Function(bool running) onChanged;

  bool _hostVisible = true;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  bool get hostVisible => _hostVisible;
  set hostVisible(bool value) => _update(() => _hostVisible = value);

  AppLifecycleState get lifecycle => _lifecycle;
  set lifecycle(AppLifecycleState value) => _update(() => _lifecycle = value);

  bool get shouldRun =>
      _hostVisible &&
      (_lifecycle == AppLifecycleState.resumed ||
          _lifecycle == AppLifecycleState.inactive);

  void _update(void Function() change) {
    final wasRunning = shouldRun;
    change();
    if (shouldRun != wasRunning) onChanged(shouldRun);
  }
}
