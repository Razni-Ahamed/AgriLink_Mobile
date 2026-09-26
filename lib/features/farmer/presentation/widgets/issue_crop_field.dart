import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/labels.dart';
import '../../../../shared/widgets/crop_icon.dart';
import '../../data/crop.dart';

/// "Green Gram · MI 5", or just the crop when it has no variety.
String cropTitle(AppLocalizations l10n, FarmerCrop crop) => crop.variety.isEmpty
    ? cropLabel(l10n, crop.cropType)
    : '${cropLabel(l10n, crop.cropType)} · ${crop.variety}';

/// Chooses which of the farmer's crops has the problem. Each is shown with its field and farm
/// ("North Field · Green Acres"), because a farmer with two paddy fields needs to tell them apart.
class IssueCropField extends StatelessWidget {
  const IssueCropField({
    super.key,
    required this.crops,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final List<FarmerCrop> crops;

  /// The chosen crop's id.
  final int? value;
  final ValueChanged<int> onChanged;
  final FormFieldValidator<int>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return FormField<int>(
      initialValue: value,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        Future<void> open() async {
          final picked = await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _CropSheet(crops: crops, selected: field.value),
          );
          if (picked != null) {
            field.didChange(picked);
            onChanged(picked);
          }
        }

        FarmerCrop? selected;
        for (final crop in crops) {
          if (crop.id == field.value) {
            selected = crop;
          }
        }
        return Semantics(
          button: true,
          child: InkWell(
            onTap: enabled ? open : null,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.issuesNewWhichCrop,
                hintText: l10n.issuesNewSelectCrop,
                errorText: field.errorText,
                prefixIcon: selected == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: CropIcon(selected.cropType),
                      ),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              isEmpty: selected == null,
              child: selected == null
                  ? const Text('')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cropTitle(l10n, selected), overflow: TextOverflow.ellipsis),
                        Text(
                          l10n.commonFieldsCropLocation(selected.fieldName, selected.farmName),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _CropSheet extends StatelessWidget {
  const _CropSheet({required this.crops, required this.selected});

  final List<FarmerCrop> crops;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final crop in crops)
          ListTile(
            key: Key('issue-crop-${crop.id}'),
            leading: CropIcon(crop.cropType),
            title: Text(cropTitle(l10n, crop)),
            subtitle: Text(l10n.commonFieldsCropLocation(crop.fieldName, crop.farmName)),
            selected: crop.id == selected,
            trailing: crop.id == selected ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(crop.id),
          ),
      ],
    );
  }
}
