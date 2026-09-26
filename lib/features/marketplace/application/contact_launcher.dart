import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone app to call a number, or the email app to write to an address. Returns false
/// when no app on the phone can. A provider so tests can record the calls instead.
class ContactLauncher {
  const ContactLauncher();

  Future<bool> call(String phone) =>
      _open(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')));

  Future<bool> email(String address) => _open(Uri(scheme: 'mailto', path: address));

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri);
    } on Object {
      return false;
    }
  }
}

final contactLauncherProvider = Provider<ContactLauncher>((ref) => const ContactLauncher());
