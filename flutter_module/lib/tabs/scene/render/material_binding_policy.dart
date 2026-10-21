/// Bookkeeping for features that dress existing surfaces in a substitute
/// material: which targets wear it, and what each wore before, so every
/// original is handed back exactly once. Pure: the targets and originals are
/// whatever the caller swaps (a scene node and its authored mesh, say).
library;

/// What [MaterialBindingPolicy.reconcile] asks the caller to do.
class BindingChanges<T, O> {
  const BindingChanges(this.release, this.bind);

  /// Targets no longer wanted (the mode left, or a room remount replaced
  /// them), each with the original to put back. Already removed from the
  /// policy, so each is listed once.
  final List<(T, O)> release;

  /// Wanted targets not yet bound. Swap them, then report each with
  /// [MaterialBindingPolicy.bind].
  final List<T> bind;
}

class MaterialBindingPolicy<T extends Object, O> {
  final Map<T, O> _originals = {};

  bool isBound(T target) => _originals.containsKey(target);

  /// Targets currently wearing the substitute.
  Iterable<T> get bound => _originals.keys;

  /// Records that [target] now wears the substitute and wore [original]
  /// before. A target that is already bound keeps its first original: a
  /// second swap must not record the substitute as the thing to restore.
  void bind(T target, O original) => _originals.putIfAbsent(target, () => original);

  /// Matches the bound set to [wanted]. Releases are removed here.
  BindingChanges<T, O> reconcile(Iterable<T> wanted) {
    final want = wanted.toSet();
    final release = <(T, O)>[];
    for (final target in _originals.keys.toList()) {
      if (!want.contains(target)) release.add((target, _originals.remove(target) as O));
    }
    return BindingChanges(release, [
      for (final target in want)
        if (!_originals.containsKey(target)) target,
    ]);
  }

  /// Every bound target with its original; the policy is empty after.
  List<(T, O)> releaseAll() => reconcile(const []).release;
}
