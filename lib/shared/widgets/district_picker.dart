import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_parser.dart';
import '../../l10n/l10n.dart';
import '../data/districts.dart';

/// Picks one of the 25 districts, loaded from the API. Opens a searchable list, which is easier
/// on a phone than a 25-item dropdown. Shows a retry if the list can't be loaded.
class DistrictPicker extends ConsumerWidget {
  const DistrictPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.serverError,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final String? serverError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final districts = ref.watch(districtsProvider);

    return FormField<String>(
      initialValue: value,
      validator: validator,
      forceErrorText: serverError,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        Future<void> open() async {
          final list = districts.value;
          if (list == null) {
            ref.invalidate(districtsProvider);
            return;
          }
          final picked = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) =>
                _DistrictSheet(districts: list, selected: field.value),
          );
          if (picked != null) {
            field.didChange(picked);
            onChanged(picked);
          }
        }

        final String? helper;
        final Widget suffix;
        if (districts.isLoading) {
          helper = l10n.commonActionsLoading;
          suffix = const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else if (districts.hasError) {
          helper = describeError(districts.error!, l10n);
          suffix = IconButton(
            tooltip: l10n.commonActionsRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(districtsProvider),
          );
        } else {
          helper = null;
          suffix = const Icon(Icons.arrow_drop_down);
        }

        return Semantics(
          button: true,
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.commonFieldsDistrict,
                hintText: l10n.commonFieldsSelectDistrict,
                helperText: helper,
                helperMaxLines: 3,
                errorText: field.errorText,
                suffixIcon: suffix,
              ),
              isEmpty: field.value == null,
              child: Text(field.value ?? ''),
            ),
          ),
        );
      },
    );
  }
}

class _DistrictSheet extends StatefulWidget {
  const _DistrictSheet({required this.districts, required this.selected});

  final List<String> districts;
  final String? selected;

  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final matches = widget.districts
        .where((d) => d.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
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
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final district = matches[index];
                final selected = district == widget.selected;
                return ListTile(
                  title: Text(district),
                  selected: selected,
                  trailing: selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(district),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
