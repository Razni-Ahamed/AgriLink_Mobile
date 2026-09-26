import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/data/districts.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../application/listing_rules.dart';
import '../../application/marketplace_providers.dart';

/// Everything the browse screen filters by. Crop and district go to the server; the price range
/// is applied on the phone.
class HarvestFilters {
  const HarvestFilters({this.cropType, this.district, this.minPrice = '', this.maxPrice = ''});

  static const none = HarvestFilters();

  final String? cropType;
  final String? district;

  /// The price fields as typed, so reopening the sheet shows them as they were.
  final String minPrice;
  final String maxPrice;

  BrowseFilters get server => (cropType: cropType, district: district);
  PriceRange get priceRange => PriceRange.parse(minPrice, maxPrice);

  /// How many filters are on, for the badge on the filter button.
  int get count =>
      (cropType == null ? 0 : 1) +
      (district == null ? 0 : 1) +
      (priceRange.min == null ? 0 : 1) +
      (priceRange.max == null ? 0 : 1);
}

/// Opens the filters. Returns the new filters, or null if the user closed the sheet.
Future<HarvestFilters?> showHarvestFilterSheet(BuildContext context, HarvestFilters current) =>
    showModalBottomSheet<HarvestFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(initial: current),
    );

/// A sentinel for the "All …" choice, since a dropdown value can't be null and selected.
const _all = '';

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final HarvestFilters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String _cropType = widget.initial.cropType ?? _all;
  late String _district = widget.initial.district ?? _all;
  late final _min = TextEditingController(text: widget.initial.minPrice);
  late final _max = TextEditingController(text: widget.initial.maxPrice);

  /// Changes when the filters are cleared, so the dropdowns show "All" again.
  int _generation = 0;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _cropType = _all;
    _district = _all;
    _min.clear();
    _max.clear();
    _generation++;
  });

  void _apply() => Navigator.of(context).pop(
    HarvestFilters(
      cropType: _cropType == _all ? null : _cropType,
      district: _district == _all ? null : _district,
      minPrice: _min.text.trim(),
      maxPrice: _max.text.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final districts = ref.watch(districtsProvider).value ?? const <String>[];
    final crops = [...cropCatalog]
      ..sort((a, b) => cropCatalogOrder(a.value) - cropCatalogOrder(b.value));
    final priceFormatter = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.md),
        child: Column(
          key: ValueKey(_generation),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.marketplaceFiltersTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gaps.md),
            AppDropdownField<String>(
              key: const Key('filter-crop'),
              label: l10n.marketplaceFiltersCropType,
              value: _cropType,
              items: {
                _all: l10n.marketplaceFiltersAllCropTypes,
                for (final crop in crops) crop.value: cropLabel(l10n, crop.value),
              },
              onChanged: (value) => setState(() => _cropType = value ?? _all),
            ),
            const SizedBox(height: Gaps.md),
            AppDropdownField<String>(
              key: const Key('filter-district'),
              label: l10n.marketplaceFiltersDistrict,
              // A district the list doesn't have yet (still loading) would break the dropdown.
              value: districts.contains(_district) ? _district : _all,
              items: {
                _all: l10n.marketplaceFiltersAllDistricts,
                for (final district in districts) district: district,
              },
              onChanged: (value) => setState(() => _district = value ?? _all),
            ),
            const SizedBox(height: Gaps.md),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    fieldKey: const Key('filter-min-price'),
                    controller: _min,
                    label: l10n.marketplaceFiltersMinPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: priceFormatter,
                  ),
                ),
                const SizedBox(width: Gaps.sm + 4),
                Expanded(
                  child: AppTextField(
                    fieldKey: const Key('filter-max-price'),
                    controller: _max,
                    label: l10n.marketplaceFiltersMaxPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: priceFormatter,
                    onFieldSubmitted: (_) => _apply(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gaps.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('filter-clear'),
                    onPressed: _clear,
                    icon: const Icon(Icons.close),
                    label: Text(l10n.marketplaceFiltersClear),
                  ),
                ),
                const SizedBox(width: Gaps.sm + 4),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('filter-apply'),
                    onPressed: _apply,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.commonActionsSearch),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
