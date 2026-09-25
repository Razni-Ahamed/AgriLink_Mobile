import 'package:flutter/material.dart';

import '../../core/api/api_error_parser.dart';
import '../../core/api/paged.dart';
import '../../l10n/l10n.dart';
import 'state_views.dart';

/// Loads one page (1-based) of a list endpoint.
typedef PageLoader<T> = Future<Paged<T>> Function(int page);

/// The state of an infinitely scrolling list: the items loaded so far, whether more exist,
/// and any error. [PagedListView] draws it; screens call [refresh] and [updateWhere].
///
/// ```dart
/// late final _orders = PagedListController<Order>(
///   loadPage: (page) => ref.read(ordersApiProvider).mine(page: page),
/// )..loadFirstPage();
///
/// @override
/// void dispose() { _orders.dispose(); super.dispose(); }
/// ```
class PagedListController<T> extends ChangeNotifier {
  PagedListController({required this.loadPage});

  final PageLoader<T> loadPage;

  List<T> _items = const [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  /// The request that failed, so [retry] repeats exactly that one.
  int _failedPage = 1;
  bool _failedReplace = false;

  /// Bumped on refresh so a slow response for an older list is thrown away.
  int _generation = 0;
  bool _disposed = false;

  List<T> get items => _items;
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  Object? get error => _error;

  /// Nothing loaded yet and loading or failed: show a full-screen state.
  bool get isFirstLoad => _page == 0;
  bool get isEmpty => _page > 0 && _items.isEmpty;

  /// Loads page 1 if nothing has been loaded yet.
  Future<void> loadFirstPage() =>
      _page == 0 && !_loading ? _load(1) : Future.value();

  /// Starts again from page 1, e.g. on pull-to-refresh. The old items stay visible until the
  /// new page arrives.
  Future<void> refresh() {
    _generation++;
    _loading = false;
    return _load(1, replace: true);
  }

  /// Loads the next page, if there is one and nothing else is loading.
  Future<void> loadMore() {
    if (_loading || !_hasMore || _error != null) {
      return Future.value();
    }
    return _load(_page + 1);
  }

  /// After a failure, tries the same page again.
  Future<void> retry() {
    _error = null;
    return _load(_failedPage, replace: _failedReplace);
  }

  /// Changes loaded items in place, e.g. to mark a notification as read.
  void updateWhere(bool Function(T item) test, T Function(T item) update) {
    _items = [for (final item in _items) test(item) ? update(item) : item];
    _notify();
  }

  Future<void> _load(int page, {bool replace = false}) async {
    final generation = _generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final result = await loadPage(page);
      if (generation != _generation || _disposed) {
        return;
      }
      _items = replace || page == 1
          ? result.items
          : [..._items, ...result.items];
      _page = result.page < page ? page : result.page;
      _hasMore = result.hasMore && result.items.isNotEmpty;
    } on Object catch (error) {
      if (generation != _generation || _disposed) {
        return;
      }
      _error = error;
      _failedPage = page;
      _failedReplace = replace;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A list that loads the next page as the user nears the end, with pull-to-refresh, loading,
/// error-with-retry and empty states built in.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.empty,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.separator = const SizedBox(height: 12),
  });

  final PagedListController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Shown when the list has no items. Defaults to [EmptyView].
  final Widget? empty;
  final EdgeInsetsGeometry padding;
  final Widget separator;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  PagedListController<T> get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.loadFirstPage();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 400) {
      _controller.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isFirstLoad) {
          return _controller.error != null
              ? ErrorView(error: _controller.error!, onRetry: _controller.retry)
              : const LoadingView();
        }
        final items = _controller.items;
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: items.isEmpty
              ? (widget.empty ?? const EmptyView())
              : NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: widget.padding,
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => widget.separator,
                    itemBuilder: (context, index) => index < items.length
                        ? widget.itemBuilder(context, items[index], index)
                        : _Footer(controller: _controller),
                  ),
                ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PagedListController<Object?> controller;

  @override
  Widget build(BuildContext context) {
    if (controller.error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: controller.retry,
          icon: const Icon(Icons.refresh),
          label: Text(
            '${describeError(controller.error!, context.l10n)}\n'
            '${context.l10n.commonActionsRetry}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (controller.hasMore) {
      // Covers a first page too short to scroll: ask for more once it is drawn.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.loadMore(),
      );
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox(height: 8);
  }
}
