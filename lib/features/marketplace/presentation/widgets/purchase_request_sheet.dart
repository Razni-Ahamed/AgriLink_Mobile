import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/marketplace_errors.dart';
import '../../application/marketplace_providers.dart';
import '../../data/harvest_listing.dart';
import '../../data/marketplace_api.dart';
import '../../data/purchase_request.dart';

/// The buyer's "Request to buy" form for [listing], like the website's PurchaseRequestForm.
Future<void> showPurchaseRequestSheet(BuildContext context, HarvestListing listing) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PurchaseRequestSheet(listing: listing),
    );

class _PurchaseRequestSheet extends ConsumerStatefulWidget {
  const _PurchaseRequestSheet({required this.listing});

  final HarvestListing listing;

  @override
  ConsumerState<_PurchaseRequestSheet> createState() => _PurchaseRequestSheetState();
}

class _PurchaseRequestSheetState extends ConsumerState<_PurchaseRequestSheet> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  Map<String, String> _fieldErrors = const {};
  List<String> _generalErrors = const [];

  @override
  void dispose() {
    _quantity.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _validateQuantity(String? text) {
    final l10n = context.l10n;
    final value = parsePositiveNumber(text ?? '');
    if (value == null) {
      return l10n.commonValidationQuantityMin;
    }
    if (value > widget.listing.availableQuantity) {
      return l10n.commonValidationOnlyAvailable(
        ref.read(formattersProvider).number(widget.listing.availableQuantity),
      );
    }
    return null;
  }

  Future<void> _send() async {
    setState(() {
      _fieldErrors = const {};
      _generalErrors = const [];
    });
    if (!_form.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await ref
          .read(marketplaceApiProvider)
          .sendRequest(
            CreatePurchaseRequestRequest(
              harvestId: widget.listing.id,
              requestedQuantity: parsePositiveNumber(_quantity.text)!,
              message: _message.text,
            ),
          );
      if (!mounted) {
        return;
      }
      refreshTrade(ref);
      setState(() => _sent = true);
      showToast(context, l10n.marketplaceRequestsSent, tone: ToastTone.success);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseMarketplaceError(error, l10n, (l) => l.marketplaceRequestsSendError);
      setState(() {
        _fieldErrors = parsed.fieldErrors;
        _generalErrors = parsed.generalErrors;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.lg),
        child: _sent
            ? Column(
                key: const Key('request-sent'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.marketplaceDetailRequestPurchase, style: text.titleLarge),
                  const SizedBox(height: Gaps.md),
                  InfoBanner(message: l10n.marketplaceDetailRequestSent, success: true),
                  const SizedBox(height: Gaps.lg),
                  FilledButton(
                    key: const Key('view-my-requests'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(AppRoutes.sentRequests);
                    },
                    child: Text(l10n.marketplaceDetailViewMyRequests),
                  ),
                  const SizedBox(height: Gaps.sm),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonActionsClose),
                  ),
                ],
              )
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.marketplaceDetailRequestPurchase, style: text.titleLarge),
                    const SizedBox(height: Gaps.md),
                    ErrorBanner(messages: _generalErrors),
                    if (_generalErrors.isNotEmpty) const SizedBox(height: Gaps.md),
                    AppTextField(
                      fieldKey: const Key('request-quantity'),
                      controller: _quantity,
                      label: l10n.marketplaceRequestFormQuantityLabel(
                        format.kilograms(l10n, widget.listing.availableQuantity),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      validator: _validateQuantity,
                      serverError: _fieldErrors['requestedQuantity'],
                    ),
                    const SizedBox(height: Gaps.md),
                    AppTextField(
                      fieldKey: const Key('request-message'),
                      controller: _message,
                      label: l10n.commonFieldsMessageOptional,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      serverError: _fieldErrors['message'],
                    ),
                    const SizedBox(height: Gaps.md),
                    LoadingButton(
                      key: const Key('request-send'),
                      label: l10n.marketplaceRequestFormSend,
                      loadingLabel: l10n.marketplaceRequestFormSending,
                      loading: _sending,
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
