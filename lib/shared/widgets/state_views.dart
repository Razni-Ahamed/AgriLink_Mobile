import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/api/api_error_parser.dart';
import '../../core/api/api_exception.dart';
import '../../l10n/l10n.dart';

/// A centred spinner with an optional message ("Loading your profile…").
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failed load with a "Try again" button. Connectivity problems get the friendly
/// "Can't reach the server" message and a cloud icon.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.message});

  final Object error;
  final VoidCallback? onRetry;

  /// Overrides the message worked out from [error].
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offline =
        error is ApiException && (error as ApiException).isConnectivity;
    return _CenteredMessage(
      icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
      iconColor: context.colors.danger,
      title: message ?? describeError(error, l10n),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonActionsRetry),
            ),
    );
  }
}

/// Nothing to show yet, with an optional explanation and action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String? title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: icon,
      iconColor: context.colors.textSecondary,
      title: title ?? context.l10n.commonEmptyTitle,
      message: message,
      action: action,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Scrollable so a large system font size never overflows a short screen.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: iconColor),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 20), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows an [AsyncValue] with the standard loading and error views:
///
/// ```dart
/// AsyncValueView(
///   value: ref.watch(farmsProvider),
///   onRetry: () => ref.invalidate(farmsProvider),
///   data: (farms) => FarmList(farms),
/// )
/// ```
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => ErrorView(error: error, onRetry: onRetry),
      _ => LoadingView(message: loadingMessage),
    };
  }
}
