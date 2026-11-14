import 'package:flutter/foundation.dart';

/// Visible in debug builds for client previews. Release builds require
/// --dart-define=SHOW_SAMPLE_JOBS=true; pass false to hide them in debug.
const bool showSampleJobs = bool.fromEnvironment(
  'SHOW_SAMPLE_JOBS',
  defaultValue: !kReleaseMode,
);
