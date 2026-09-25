import '../../issues/data/advisory.dart';

/// "CropAnalysisAgent" → "Crop Analysis": drops the implied "Agent" and splits the rest into
/// words. The agent names are English identifiers, shown as the website shows them.
String agentDisplayName(String agentName) {
  final withoutSuffix = agentName.endsWith('Agent') && agentName.length > 5
      ? agentName.substring(0, agentName.length - 5)
      : agentName;
  return withoutSuffix.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
}

/// "avgTemperatureC" → "Avg Temperature C". The labels come from whatever keys an agent
/// actually recorded, because each agent's output has its own shape and can change without the
/// app changing.
String humanizeKey(String key) {
  final spaced = key.replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  return spaced.isEmpty ? spaced : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

/// How long a step took, or null while it is still running (or if the times don't make sense).
Duration? stepDuration(AgentStep step) {
  final end = step.completedAt;
  if (end == null) {
    return null;
  }
  final duration = end.difference(step.startedAt);
  return duration.isNegative ? null : duration;
}

/// A number as the trace shows it: whole numbers as they are, others to two decimals.
String formatTraceNumber(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

/// The most a long text is shown in the trace before it is cut, so one agent's long output can't
/// fill the phone's screen.
const int traceTextLimit = 600;

/// [text] cut to [traceTextLimit] characters, with an ellipsis if it was cut.
String clipTraceText(String text) =>
    text.length <= traceTextLimit ? text : '${text.substring(0, traceTextLimit).trimRight()}…';
