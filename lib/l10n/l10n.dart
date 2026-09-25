import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';
export 'web_keys.g.dart';

extension L10nContext on BuildContext {
  /// The current language's strings: `context.l10n.authLoginSubmit`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
