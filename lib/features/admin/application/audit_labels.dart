import '../../../l10n/l10n.dart';

/// The record types the backend writes to the audit log, in the order the filter offers them.
/// The API filters by these exact names.
const auditEntityNames = [
  'User',
  'Department',
  'ProfileChangeRequest',
  'AIAdvisory',
  'HarvestListing',
  'Order',
  'PurchaseRequest',
];

/// "UserCreated" → "User created". The API's action names are English identifiers, which the
/// website shows as they are; this only makes them read as words.
String humanizeAuditAction(String action) {
  final words = action
      .replaceAllMapped(RegExp('(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return action;
  }
  return [words.first, ...words.skip(1).map((word) => word.toLowerCase())].join(' ');
}

/// The translated name of a record type. One the app doesn't know is shown as it is.
String auditEntityLabel(AppLocalizations l10n, String entityName) => switch (entityName) {
  'User' => l10n.adminAuditEntityUser,
  'Department' => l10n.adminAuditEntityDepartment,
  'ProfileChangeRequest' => l10n.adminAuditEntityProfileChangeRequest,
  'AIAdvisory' => l10n.adminAuditEntityAIAdvisory,
  'HarvestListing' => l10n.adminAuditEntityHarvestListing,
  'Order' => l10n.adminAuditEntityOrder,
  'PurchaseRequest' => l10n.adminAuditEntityPurchaseRequest,
  _ => entityName,
};
