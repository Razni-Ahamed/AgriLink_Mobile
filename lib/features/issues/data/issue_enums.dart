/// The API sends these as plain strings (`"AwaitingReview"`). Each enum keeps that string in
/// [apiName], which is also what `statusLabel` and `StatusBadge.status` take.
///
/// An unknown value is a [FormatException]: it means the API changed, and a clear error is
/// better than quietly showing the wrong status.
T _parse<T>(Object? raw, List<T> values, String Function(T value) nameOf, String what) {
  for (final value in values) {
    if (nameOf(value) == raw) {
      return value;
    }
  }
  throw FormatException('Unknown $what: "$raw"');
}

/// How serious the farmer says the problem is. Also the shape of the AI's [RiskLevel].
enum IssueSeverity {
  low('Low'),
  medium('Medium'),
  high('High');

  const IssueSeverity(this.apiName);

  factory IssueSeverity.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'issue severity');

  final String apiName;
}

/// The AI's assessment of how risky the problem is.
enum RiskLevel {
  low('Low'),
  medium('Medium'),
  high('High');

  const RiskLevel(this.apiName);

  factory RiskLevel.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'risk level');

  final String apiName;
}

/// Where a reported issue is in its life.
enum IssueStatus {
  pending('Pending'),
  awaitingReview('AwaitingReview'),
  resolved('Resolved'),
  rejected('Rejected');

  const IssueStatus(this.apiName);

  factory IssueStatus.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'issue status');

  final String apiName;
}

/// The state of an advisory.
///
/// - [draft]: not released. The API answers 404 to the farmer for a draft.
/// - [preliminary]: released early from a confident photo diagnosis; an officer hasn't
///   confirmed it yet.
/// - [approved] and [rejected]: an officer has decided.
enum AdvisoryStatus {
  draft('Draft'),
  preliminary('Preliminary'),
  approved('Approved'),
  rejected('Rejected');

  const AdvisoryStatus(this.apiName);

  factory AdvisoryStatus.fromApi(Object? raw) =>
      _parse(raw, values, (value) => value.apiName, 'advisory status');

  final String apiName;

  /// Advice the farmer may see: everything except a draft.
  bool get isReleased => this != draft;

  /// An officer has made the final decision.
  bool get isDecided => this == approved || this == rejected;
}
