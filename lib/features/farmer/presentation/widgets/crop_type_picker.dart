import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_parser.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../application/farms.dart';

/// Picks a crop type from the list the API accepts (`GET /api/crop-types`), grouped and drawn
/// with the website's icons. It opens a searchable list, which is easier on a phone than a
/// dropdown of about forty crops. Shows a retry if the list can't be loaded.
class CropTypePicker extends ConsumerWidget {
  const CropTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.serverError,
  });

  /// The crop name as the API spells it ("Green Gram").
  final String? value;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final String? serverError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final types = ref.watch(cropTypesProvider);

    return FormField<String>(
      initialValue: value,
      validator: validator,
      forceErrorText: serverError,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        Future<void> open() async {
          final list = types.value;
          if (list == null) {
            ref.invalidate(cropTypesProvider);
            return;
          }
          final picked = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _CropTypeSheet(cropTypes: list, selected: field.value),
          );
          if (picked != null) {
            field.didChange(picked);
            onChanged(picked);
          }
        }

        final String? helper;
        final Widget suffix;
        if (types.isLoading) {
          helper = l10n.commonActionsLoading;
          suffix = const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        } else if (types.hasError) {
          helper = describeError(types.error!, l10n);
          suffix = IconButton(
            tooltip: l10n.commonActionsRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(cropTypesProvider),
          );
        } else {
          helper = null;
          suffix = const Icon(Icons.arrow_drop_down);
        }

        final selected = field.value;
        return Semantics(
          button: true,
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.farmsFormCropType,
                hintText: l10n.farmsFormSelectCropType,
                helperText: helper,
                helperMaxLines: 3,
                errorText: field.errorText,
                prefixIcon: selected == null
                    ? null
                    : Padding(padding: const EdgeInsets.all(12), child: CropIcon(selected)),
                suffixIcon: suffix,
              ),
              isEmpty: selected == null,
              child: Text(selected == null ? '' : cropLabel(l10n, selected)),
            ),
          ),
        );
      },
    );
  }
}

class _CropTypeSheet extends StatefulWidget {
  const _CropTypeSheet({required this.cropTypes, required this.selected});

  final List<String> cropTypes;
  final String? selected;

  @override
  State<_CropTypeSheet> createState() => _CropTypeSheetState();
}

class _CropTypeSheetState extends State<_CropTypeSheet> {
  String _query = '';

  /// The rows to show: a heading for each group, then its crops, in the website's order.
  List<Object> _rows(AppLocalizations l10n) {
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final type in widget.cropTypes)
        if (query.isEmpty ||
            type.toLowerCase().contains(query) ||
            cropLabel(l10n, type).toLowerCase().contains(query))
          type,
    ]..sort((a, b) => cropCatalogOrder(a).compareTo(cropCatalogOrder(b)));

    final rows = <Object>[];
    CropGroup? group;
    for (final type in matches) {
      final typeGroup = cropCatalogEntry(type).group;
      if (typeGroup != group) {
        group = typeGroup;
        rows.add(typeGroup);
      }
      rows.add(type);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = _rows(l10n);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('crop-type-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.commonActionsSearch,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is CropGroup) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Semantics(
                      header: true,
                      child: Text(
                        cropGroupLabel(l10n, row),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  );
                }
                final type = row as String;
                final selected = type == widget.selected;
                return ListTile(
                  key: Key('crop-type-$type'),
                  leading: CropIcon(type),
                  title: Text(cropLabel(l10n, type)),
                  selected: selected,
                  trailing: selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
