import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../../../shared/widgets/dialogs.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/marketplace_errors.dart';
import '../../application/marketplace_providers.dart';
import '../../data/farmer_crop.dart';
import '../../data/harvest_listing.dart';
import '../../data/marketplace_api.dart';

/// The farmer's "New Listing" form, like the website's HarvestListingForm: pick one of their
/// crops, then the quantity, price, harvest date and location.
Future<void> showNewListingSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const _NewListingSheet(),
);

class _NewListingSheet extends ConsumerWidget {
  const _NewListingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: switch (ref.watch(myCropsProvider)) {
        AsyncData(:final value) when value.isEmpty => SizedBox(
          height: 320,
          child: EmptyView(
            icon: Icons.grass_outlined,
            title: l10n.marketplaceListingFormNoCrops,
            action: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.farms);
              },
              child: Text(l10n.marketplaceListingFormGoToFarms),
            ),
          ),
        ),
        AsyncData(:final value) => _NewListingForm(crops: value),
        AsyncError(:final error) => SizedBox(
          height: 320,
          child: ErrorView(error: error, onRetry: () => ref.invalidate(myCropsProvider)),
        ),
        _ => const SizedBox(height: 320, child: LoadingView()),
      },
    );
  }
}

class _NewListingForm extends ConsumerStatefulWidget {
  const _NewListingForm({required this.crops});

  final List<FarmerCrop> crops;

  @override
  ConsumerState<_NewListingForm> createState() => _NewListingFormState();
}

class _NewListingFormState extends ConsumerState<_NewListingForm> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  FarmerCrop? _crop;
  DateTime? _harvestDate;
  bool _publishing = false;
  Map<String, String> _fieldErrors = const {};
  List<String> _generalErrors = const [];

  @override
  void initState() {
    super.initState();
    // The summary under the fields follows what's typed.
    _quantity.addListener(_rebuild);
    _price.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  void _pickCrop(FarmerCrop? crop) => setState(() {
    _crop = crop;
    // Most harvests are sold where the farm is; the farmer can still change it.
    if (crop != null && crop.district.isNotEmpty) {
      _location.text = crop.district;
    }
  });

  Future<void> _publish() async {
    setState(() {
      _fieldErrors = const {};
      _generalErrors = const [];
    });
    if (!_form.currentState!.validate()) {
      return;
    }
    final l10n = context.l10n;
    setState(() => _publishing = true);
    try {
      await ref
          .read(marketplaceApiProvider)
          .createListing(
            CreateHarvestListingRequest(
              cropId: _crop!.id,
              quantity: parsePositiveNumber(_quantity.text)!,
              harvestDate: _harvestDate!,
              pricePerUnit: parsePositiveNumber(_price.text)!,
              location: _location.text.trim(),
            ),
          );
      if (!mounted) {
        return;
      }
      refreshTrade(ref);
      showToast(context, l10n.marketplaceListingsPublished, tone: ToastTone.success);
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final parsed = parseMarketplaceError(error, l10n, (l) => l.marketplaceListingsPublishError);
      setState(() {
        _fieldErrors = parsed.fieldErrors;
        _generalErrors = parsed.generalErrors;
      });
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final numberOnly = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final crops = [...widget.crops]
      ..sort((a, b) => cropCatalogOrder(a.cropType) - cropCatalogOrder(b.cropType));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.lg),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.marketplaceListingsNewListing, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gaps.md),
            ErrorBanner(messages: _generalErrors),
            if (_generalErrors.isNotEmpty) const SizedBox(height: Gaps.md),
            DropdownButtonFormField<FarmerCrop>(
              key: const Key('listing-crop'),
              initialValue: _crop,
              isExpanded: true,
              borderRadius: BorderRadius.circular(kRadius),
              decoration: InputDecoration(labelText: l10n.marketplaceListingFormCrop),
              validator: (crop) => crop == null ? l10n.commonValidationCropRequired : null,
              forceErrorText: _fieldErrors['cropId'],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              // The closed field shows one line; the open list shows where each crop grows.
              selectedItemBuilder: (context) => [
                for (final crop in crops)
                  Text(_cropName(l10n, crop), overflow: TextOverflow.ellipsis),
              ],
              items: [
                for (final crop in crops)
                  DropdownMenuItem(
                    value: crop,
                    child: _CropOption(crop: crop),
                  ),
              ],
              onChanged: _pickCrop,
            ),
            if (_crop != null) ...[
              const SizedBox(height: Gaps.sm + 4),
              _SelectedCrop(crop: _crop!),
            ],
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('listing-quantity'),
              controller: _quantity,
              label: l10n.marketplaceListingFormQuantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numberOnly,
              suffix: const Text('kg'),
              validator: (text) =>
                  parsePositiveNumber(text ?? '') == null ? l10n.commonValidationQuantityMin : null,
              serverError: _fieldErrors['quantity'],
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('listing-price'),
              controller: _price,
              label: l10n.marketplaceListingFormPricePerUnit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numberOnly,
              validator: (text) =>
                  parsePositiveNumber(text ?? '') == null ? l10n.commonValidationPriceMin : null,
              serverError: _fieldErrors['pricePerUnit'],
            ),
            const SizedBox(height: Gaps.md),
            AppDateField(
              key: const Key('listing-harvest-date'),
              label: l10n.marketplaceListingFormHarvestDate,
              value: _harvestDate,
              onChanged: (date) => setState(() => _harvestDate = date),
              validator: (date) => date == null ? l10n.commonValidationHarvestDateRequired : null,
              serverError: _fieldErrors['harvestDate'],
            ),
            const SizedBox(height: Gaps.md),
            AppTextField(
              fieldKey: const Key('listing-location'),
              controller: _location,
              label: l10n.marketplaceListingFormLocation,
              maxLength: 150,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              validator: (text) =>
                  (text ?? '').trim().isEmpty ? l10n.commonValidationLocationRequired : null,
              serverError: _fieldErrors['location'],
            ),
            _Summary(
              quantity: parsePositiveNumber(_quantity.text),
              pricePerUnit: parsePositiveNumber(_price.text),
            ),
            const SizedBox(height: Gaps.md),
            LoadingButton(
              key: const Key('listing-publish'),
              label: l10n.marketplaceListingFormPublish,
              loadingLabel: l10n.marketplaceListingFormPublishing,
              loading: _publishing,
              onPressed: _publish,
            ),
          ],
        ),
      ),
    );
  }
}

String _cropName(AppLocalizations l10n, FarmerCrop crop) => crop.variety.isEmpty
    ? cropLabel(l10n, crop.cropType)
    : '${cropLabel(l10n, crop.cropType)} · ${crop.variety}';

/// One crop in the picker: its icon, name and where it grows.
class _CropOption extends StatelessWidget {
  const _CropOption({required this.crop});

  final FarmerCrop crop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
      child: Row(
        children: [
          CropIcon(crop.cropType),
          const SizedBox(width: Gaps.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_cropName(l10n, crop), overflow: TextOverflow.ellipsis),
                Text(
                  l10n.commonFieldsCropLocation(crop.fieldName, crop.farmName),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The chosen crop, with its field, farm and expected yield, as on the website.
class _SelectedCrop extends ConsumerWidget {
  const _SelectedCrop({required this.crop});

  final FarmerCrop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final format = ref.watch(formattersProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tint(colors.forest),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.sm + 4),
        child: Row(
          children: [
            CropIcon(crop.cropType, size: 28),
            const SizedBox(width: Gaps.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cropName(l10n, crop), style: text.titleSmall),
                  Text(
                    l10n.commonFieldsCropLocation(crop.fieldName, crop.farmName),
                    style: text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  if (crop.expectedQuantity > 0)
                    Text(
                      l10n.marketplaceListingFormExpectedYield(
                        format.number(crop.expectedQuantity),
                      ),
                      style: text.bodySmall!.mono.copyWith(color: colors.forest),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What buyers will see, so the numbers are checked before publishing.
class _Summary extends ConsumerWidget {
  const _Summary({required this.quantity, required this.pricePerUnit});

  final double? quantity;
  final double? pricePerUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = this.quantity;
    final price = pricePerUnit;
    if (quantity == null || price == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final format = ref.watch(formattersProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('listing-summary'),
      padding: const EdgeInsets.all(Gaps.sm + 4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.marketplaceListingFormEstimatedTotal,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          Text(
            format.rupees(l10n, quantity * price),
            style: text.titleMedium!.mono.copyWith(color: colors.forest),
          ),
        ],
      ),
    );
  }
}
