import 'l10n.dart';

/// The kinds of status value the API returns as plain strings. Mirrors the website's
/// `useStatusLabel` (frontend/src/lib/useStatusLabel.ts).
enum StatusKind {
  crop('common.status.crop'),
  harvest('common.status.harvest'),
  request('common.status.request'),
  order('common.status.order'),
  issue('common.status.issue'),
  advisory('common.status.advisory'),
  severity('common.severity'),
  risk('common.risk');

  const StatusKind(this.keyPrefix);
  final String keyPrefix;
}

/// The translated label for a status from the API, e.g. `statusLabel(l10n, StatusKind.issue,
/// 'AwaitingReview')`. An unknown value is shown as it is rather than as a missing key.
String statusLabel(AppLocalizations l10n, StatusKind kind, String value) =>
    translateWebKey(l10n, '${kind.keyPrefix}.$value') ?? value;

/// The translated name of a crop type from the API, e.g. "Green Gram". Mirrors the
/// website's `useCropLabel`; an unknown crop is shown as it is.
String cropLabel(AppLocalizations l10n, String cropType) =>
    translateWebKey(l10n, 'common.cropTypes.$cropType') ?? cropType;

/// The translated name of a role: Farmer, Buyer, Officer or Admin.
String roleLabel(AppLocalizations l10n, String role) =>
    translateWebKey(l10n, 'common.roles.$role') ?? role;
