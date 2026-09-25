import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/marketplace_errors.dart';
import '../../application/marketplace_providers.dart';
import '../../data/harvest_listing.dart';
import '../../data/marketplace_api.dart';
import '../../data/marketplace_enums.dart';

/// Edits a listing's status, price, location and harvest date, like the website's
/// EditHarvestForm. The owner uses it on their own listing and an admin on anyone's; the server
/// checks which is allowed. [asAdmin] adds a note that the change is audited.
Future<void> showEditListingSheet(
  BuildContext context,
  HarvestListing listing, {
  bool asAdmin = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _EditListingSheet(listing: listing, asAdmin: asAdmin),
);

class _EditListingSheet extends ConsumerStatefulWidget {
  const _EditListingSheet({required this.listing, required this.asAdmin});

  final HarvestListing listing;
  final bool asAdmin;

  @override
  ConsumerState<_EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends ConsumerState<_EditListingSheet> {
  final _form = GlobalKey<FormState>();
  late HarvestStatus _status = widget.listing.status;
  late final _price = TextEditingController(text: plainNumber(widget.listing.pricePerUnit));
  late final _location = TextEditingController(text: widget.listing.location);
  late DateTime _harvestDate = widget.listing.harvestDate;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};
  List<String> _generalErrors = const [];

  @override
  void dispose() {
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _fieldErrors = const {};
      _generalErrors = const [];
    });
    if (!_form.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    // Taking a listing off the market closes its pending requests, so ask first.
    final closing = _status != widget.listing.status && _status != HarvestStatus.active;
    if (closing) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.marketplaceEditFormConfirmStatusTitle(
          statusLabel(l10n, StatusKind.harvest, _status.apiName),
        ),
        message: l10n.marketplaceEditFormConfirmStatusBody,
        destructive: true,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(marketplaceApiProvider)
          .updateListing(
            widget.listing.id,
            UpdateHarvestListingRequest(
              status: _status,
              pricePerUnit: parsePositiveNumber(_price.text),
              location: _location.text.trim(),
              harvestDate: _harvestDate,
            ),
          );
      if (!mounted) {
        return;
      }
      refreshTrade(ref);
      showToast(context, l10n.marketplaceEditFormSaved, tone: ToastTone.success);
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseMarketplaceError(error, l10n, (l) => l.marketplaceEditFormSaveError);
      setState(() {
        _fieldErrors = parsed.fieldErrors;
        _generalErrors = parsed.generalErrors;
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.lg),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.marketplaceEditFormEditListing,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Gaps.md),
              if (widget.asAdmin) ...[
                InfoBanner(message: l10n.marketplaceEditFormAdminNote),
                const SizedBox(height: Gaps.md),
              ],
              ErrorBanner(messages: _generalErrors),
              if (_generalErrors.isNotEmpty) const SizedBox(height: Gaps.md),
              AppDropdownField<HarvestStatus>(
                key: const Key('edit-status'),
                label: l10n.commonFieldsStatus,
                value: _status,
                items: {
                  for (final status in HarvestStatus.values)
                    status: statusLabel(l10n, StatusKind.harvest, status.apiName),
                },
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: Gaps.md),
              AppTextField(
                fieldKey: const Key('edit-price'),
                controller: _price,
                label: l10n.marketplaceListingFormPricePerUnit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                validator: (text) =>
                    parsePositiveNumber(text ?? '') == null ? l10n.commonValidationPriceMin : null,
                serverError: _fieldErrors['pricePerUnit'],
              ),
              const SizedBox(height: Gaps.md),
              AppTextField(
                fieldKey: const Key('edit-location'),
                controller: _location,
                label: l10n.marketplaceListingFormLocation,
                maxLength: 150,
                textCapitalization: TextCapitalization.words,
                validator: (text) =>
                    (text ?? '').trim().isEmpty ? l10n.commonValidationLocationRequired : null,
                serverError: _fieldErrors['location'],
              ),
              const SizedBox(height: Gaps.sm),
              AppDateField(
                key: const Key('edit-harvest-date'),
                label: l10n.marketplaceListingFormHarvestDate,
                value: _harvestDate,
                onChanged: (date) => setState(() => _harvestDate = date),
                serverError: _fieldErrors['harvestDate'],
              ),
              const SizedBox(height: Gaps.lg),
              LoadingButton(
                key: const Key('edit-save'),
                label: l10n.marketplaceEditFormSave,
                loadingLabel: l10n.marketplaceEditFormSaving,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
