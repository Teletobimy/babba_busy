import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the platform has reduced motion enabled.
///
/// Default is false. Override at app level by reading
/// `MediaQuery.of(context).disableAnimations` and passing it down.
///
/// Usage in widgets:
/// ```dart
/// final reduceMotion = ref.watch(reduceMotionProvider);
/// final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
/// ```
final reduceMotionProvider = StateProvider<bool>((ref) => false);
