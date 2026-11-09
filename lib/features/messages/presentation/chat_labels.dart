import '../../../core/format/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../marketplace/application/unit_format.dart';
import '../../marketplace/data/marketplace_enums.dart';
import '../data/messages_api.dart';

/// "Tomato · 50 kg" for a deal chat; the issue's title for an advice chat. As on the website.
String chatSubject(
  AppLocalizations l10n,
  Formatters format, {
  required ConversationKind kind,
  required String title,
  required String cropType,
  required double? quantity,
  required QuantityUnit unit,
}) {
  if (kind == ConversationKind.advice) {
    return title;
  }
  final crop = cropLabel(l10n, cropType);
  return quantity == null
      ? crop
      : l10n.messagesListDealTitle(crop, format.quantity(l10n, quantity, unit));
}

/// Who the chat is with: a person, or for a farmer's advice chat the district's officers.
String chatCounterpart(AppLocalizations l10n, {required String? name, required String district}) =>
    name ?? l10n.messagesListOfficersOf(district);

String chatRole(AppLocalizations l10n, String role) => switch (role) {
  'Farmer' => l10n.messagesRoleFarmer,
  'Buyer' => l10n.messagesRoleBuyer,
  'Officer' => l10n.messagesRoleOfficer,
  _ => role,
};
