# AgriLink Mobile: architecture guide

This is the guide for everyone building on the app after Phase 1. Read it before you write a screen. It explains where code goes, how to call the API, how errors, lists, translations and the theme work, and how to replace your phase's placeholder screens.

The website and backend (`../AgriLink_SriLanka`) are the reference: when you're not sure how something should behave, do what the website does.

---

## Contents

1. [The short version](#1-the-short-version)
2. [Folder structure](#2-folder-structure)
3. [State management (Riverpod)](#3-state-management-riverpod)
4. [Routing, the role shell and placeholders](#4-routing-the-role-shell-and-placeholders)
5. [Calling the API](#5-calling-the-api)
6. [Errors](#6-errors)
7. [Paged lists](#7-paged-lists)
8. [Shared widgets](#8-shared-widgets)
9. [Theme](#9-theme)
10. [Translations](#10-translations)
11. [Session, sign-in and the current user](#11-session-sign-in-and-the-current-user)
12. [Photos and permissions](#12-photos-and-permissions)
13. [Notifications](#13-notifications)
14. [Testing](#14-testing)
15. [Conventions](#15-conventions)
16. [Known issues](#16-known-issues)

---

## 1. The short version

- Your phase owns one folder in `lib/features/`, plus the route file in it. Don't edit another phase's folder.
- Replace your `PlaceholderPage`s in your route file with real screens ([§4.4](#44-replacing-a-placeholder)).
- Call the API through `apiClientProvider` in your feature's `data/` folder ([§5](#5-calling-the-api)). Never use `dio` or `http` directly.
- Every text on screen comes from `context.l10n` ([§10](#10-translations)). Every colour comes from the theme ([§9](#9-theme)).
- Use the shared widgets ([§8](#8-shared-widgets)) for loading, errors, empty states, lists, forms and dialogs.
- Providers that load the user's data must `ref.watch(sessionTokenProvider)` ([§3](#3-state-management-riverpod)).
- Tests use the fake API, never the live one ([§14](#14-testing)).
- `flutter analyze` must show **no issues** and `flutter test` must pass before every commit.

---

## 2. Folder structure

```
lib/
  main.dart                 start-up: preferences, date formats, ProviderScope
  app/
    app.dart                MaterialApp.router: theme, language, router
    router/
      app_routes.dart       every path (the same paths as the website) and each role's home
      app_router.dart       the GoRouter: redirects and the list of all route files
      route_guard.dart      RouteGuard: routes only some roles may open
    shell/
      nav_config.dart       every section (Destinations) and each role's tabs and "More" list
      app_shell.dart        the bottom navigation bar around every signed-in page
      agrilink_app_bar.dart the app bar with the notification bell and avatar
      placeholder_page.dart "Coming soon" page for sections not built yet
      more_screen.dart, not_found_screen.dart, coming_soon_screen.dart
    theme/                  colours (AppColors), fonts, the Material theme, light/dark setting
  core/                     no screens here, only the plumbing
    api/                    ApiClient, ApiException, parseApiError, Paged, JSON helpers
    config/app_config.dart  API address, timeouts, page size
    format/formatters.dart  Rs prices, numbers and dates in the Sri Lankan locales
    session/                Role, Session, SessionController, secure token storage
    storage/preferences.dart shared_preferences provider and its keys
    validation/validators.dart NIC, phone, email, username and password rules + form validators
  l10n/
    arb/                    app_en.arb, app_si.arb, app_ta.arb (made by the import script)
    mobile/                 en.json, si.json, ta.json: strings the website doesn't have
    generated/              AppLocalizations (made by gen-l10n, not committed)
    l10n.dart               context.l10n
    labels.dart             statusLabel, cropLabel, roleLabel for values from the API
    locale_controller.dart  the chosen language (AppLanguage)
    web_keys.g.dart         translateWebKey() (made by the import script)
  shared/
    data/districts.dart     districtsProvider
    media/photo_picker.dart pickPhoto(): camera/gallery, shrunk to a 1600 px JPEG
    permissions/            PermissionService, ensureCameraPermission()
    widgets/                reusable UI (see §8)
  features/
    auth/                   login, registration, splash, session restore, current user
    account/                profile, edit profile, security settings
    notifications/          list, unread count polling, pop-ups
    farmer/                 Phase 2 (farmer_routes.dart has the placeholders)
    marketplace/            Phase 3 (marketplace_routes.dart)
    officer/                Phase 4 (officer_routes.dart)
    admin/                  Phase 4 (admin_routes.dart)
tool/
  import_web_translations.dart  website JSON → ARB files
  import_web_icons.dart         website crop icons and avatars → SVG assets
  add_mobile_strings.py         add mobile-only strings in all three languages
test/                        mirrors lib/; helpers/ has the fake API and test app
assets/fonts/, assets/icons/
```

Each feature folder is split the same way:

```
features/<feature>/
  <feature>_routes.dart   the feature's routes (the only file the router imports)
  data/                   API calls and models   (farms_api.dart, farm.dart)
  application/            Riverpod providers and logic that isn't UI
  presentation/           screens, and widgets/ for pieces used only by this feature
```

**Who may import what:**

| From | May import |
|---|---|
| `features/<yours>` | `core/`, `shared/`, `l10n/`, `app/theme/`, `app/router/app_routes.dart`, `app/router/route_guard.dart`, `app/shell/` (app bar, destinations, placeholder), and `features/auth/` (for the current user) |
| `shared/` | `core/`, `l10n/`, `app/theme/`. Never a feature. |
| `core/` | other `core/` files and `l10n/`. No widgets from `shared/` or features. |

If two phases need the same thing, it belongs in `shared/` or `core/`. Agree on it in the team chat first, because that code is shared.

---

## 3. State management (Riverpod)

We use **Riverpod 3** (`flutter_riverpod`). The patterns:

| You need | Use |
|---|---|
| An object other code uses (an API class) | `Provider` |
| Data loaded once from the API (a list, a detail) | `FutureProvider` (usually `.autoDispose`, or `.family` for an id) |
| State that screens change (a form's result, a toggle) | `Notifier` / `AsyncNotifier` with `NotifierProvider` / `AsyncNotifierProvider` |
| Local UI state (a text field, "is expanded") | a `StatefulWidget` / `ConsumerStatefulWidget`, not a provider |

```dart
// features/farmer/application/farms.dart
final myFarmsProvider = FutureProvider.autoDispose<List<Farm>>((ref) {
  ref.watch(sessionTokenProvider); // cleared when the user signs out (see below)
  return ref.watch(farmsApiProvider).mine();
});

// A detail by id:
final farmProvider = FutureProvider.autoDispose.family<Farm, int>((ref, id) {
  ref.watch(sessionTokenProvider);
  return ref.watch(farmsApiProvider).byId(id);
});
```

```dart
// In a screen
class FarmsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AgriLinkAppBar(title: context.l10n.commonNavFarms),
      body: AsyncValueView(
        value: ref.watch(myFarmsProvider),
        onRetry: () => ref.invalidate(myFarmsProvider),
        data: (farms) => FarmList(farms: farms),
      ),
    );
  }
}
```

After changing something on the server, reload what shows it: `ref.invalidate(myFarmsProvider)`.

**Rules:**

- **Watch the session for user data.** Any provider that loads or caches the signed-in user's data must `ref.watch(sessionTokenProvider)`. Then it is thrown away on sign-out, and the next person who signs in on the same phone never sees it.
- **No automatic retries.** Riverpod 3 would silently retry a failed provider; `main.dart` turns that off. A failure shows an error with a **Try again** button (`AsyncValueView` / `ErrorView`).
- Use `ref.watch` in `build`, `ref.read` in callbacks (button presses).
- Don't keep API data in widget state when a provider can hold it. Several screens may need it.

---

## 4. Routing, the role shell and placeholders

### 4.1 Paths

Paths are in `app/router/app_routes.dart` and match the **website's paths** (`/farms`, `/issues/pending`, `/marketplace/browse`, `/admin/users`, …). Use the constants, never a typed string:

```dart
context.go(AppRoutes.orders);            // switch section
context.go('${AppRoutes.farms}/$id');    // a page inside your section
```

Use `context.go`. The router builds the back stack from the path: `/farms/12` sits on top of `/farms`, so the app bar gets a back button automatically.

### 4.2 The shell

Every signed-in page is shown inside `AppShell`, which adds the bottom navigation bar for the user's role. Each role sees **only its own sections** (the website's `allowedRoles`):

| Role | Bottom bar | Under "More" |
|---|---|---|
| Farmer | Farms · My Issues · Marketplace · Orders | My Listings · My Requests |
| Buyer | Marketplace · My Requests · Orders | – |
| Officer | Dashboard · Pending Issues · My Reviews · Approvals | – |
| Admin | Dashboard · Pending Issues · Approvals · Users | All Issues · Marketplace · Departments · Audit Log |

There are at most four tabs plus "More", and the labels wrap onto two lines, so long Sinhala and Tamil labels stay readable. The tabs are set in `navigationFor()` in `app/shell/nav_config.dart`. Everyone also has **Notifications** (the bell) and **Profile** (the avatar) in the app bar.

The shell only draws the bottom bar. **Every page draws its own `Scaffold` with an `AgriLinkAppBar`**, so it has the bell, the avatar and (on a page inside a section) a back button:

```dart
Scaffold(
  appBar: AgriLinkAppBar(title: context.l10n.commonNavFarms, actions: [/* your buttons */]),
  body: ...,
)
```

### 4.3 Route guards

Routes are created with a `RouteGuard`, which sends anyone whose role isn't allowed back to their own home, like the website's `RequireRole`. Its roles also protect everything nested under it:

```dart
guard.route(
  path: Destinations.farms.path,
  roles: Destinations.farms.roles,     // {Role.farmer}
  builder: (context, state) => const FarmsScreen(),
  routes: [
    GoRoute(
      path: ':farmId',                  // → /farms/12, also farmer-only
      builder: (context, state) =>
          FarmDetailScreen(farmId: int.parse(state.pathParameters['farmId']!)),
    ),
  ],
);
```

A page that isn't in the navigation but belongs to your phase (e.g. `/advisories/:advisoryId`, `/orders/:orderId`) gets its own `guard.route(...)` with the website's allowed roles.

The router's top-level redirect (`redirectFor` in `app_router.dart`) handles signed-out users and the splash screen. Don't add sign-in checks to your screens.

### 4.4 Replacing a placeholder

Each phase's sections are already registered, showing "Coming soon", in that phase's own route file:

| Phase | File | Sections |
|---|---|---|
| 2 Farmer | `features/farmer/farmer_routes.dart` | `/farms`, `/issues/mine` |
| 3 Marketplace & orders | `features/marketplace/marketplace_routes.dart` | `/marketplace/browse`, `/marketplace/mine`, `/marketplace/requests`, `/marketplace/sent-requests`, `/orders/mine` |
| 4 Officer & admin | `features/officer/officer_routes.dart`, `features/admin/admin_routes.dart` | `/officer/dashboard`, `/issues/pending`, `/issues/reviewed`, `/registrations/pending`, `/admin`, `/admin/users`, `/admin/departments`, `/admin/audit-log`, `/issues/all` |

To replace one, build your screen and change only the `builder` (and add child routes):

```dart
// before
guard.route(
  path: Destinations.farms.path,
  roles: Destinations.farms.roles,
  builder: (context, state) => PlaceholderPage(destination: Destinations.farms),
),

// after
guard.route(
  path: Destinations.farms.path,
  roles: Destinations.farms.roles,
  builder: (context, state) => const FarmsScreen(),
  routes: [ /* detail pages */ ],
),
```

For the routes built in a loop (marketplace, officer, admin), take the destination out of the loop and give it its own `guard.route(...)` when you build its screen. The shell tests check that each role still sees its tabs; keep them passing.

---

## 5. Calling the API

### 5.1 The client

`apiClientProvider` gives you an `ApiClient` (in `core/api/api_client.dart`). It:

- uses the base URL from `AppConfig.apiBaseUrl` (production by default; see the README for `--dart-define=API_BASE_URL=…`)
- adds `Authorization: Bearer <token>` while signed in
- waits up to **30 s** to connect, because the free hosting tier sleeps and the first request can take 10–30 s
- on a **401**, ends the session. The user is taken to the login screen with "Your session has ended". Don't handle 401 yourself.
- turns every failure into an `ApiException` (see [§6](#6-errors))

Put each feature's calls in one class in `data/`, with a provider:

```dart
// features/farmer/data/farms_api.dart
class FarmsApi {
  FarmsApi(this._api);
  final ApiClient _api;

  Future<Paged<Farm>> mine({int page = 1}) =>
      _api.getPaged('/api/farms/mine', page: page, item: Farm.fromJson);

  Future<Farm> byId(int id) =>
      _api.get('/api/farms/$id', decode: (data) => Farm.fromJson(asJson(data)));

  Future<Farm> create(CreateFarmRequest request) =>
      _api.post('/api/farms', body: request.toJson(), decode: (data) => Farm.fromJson(asJson(data)));

  Future<void> delete(int id) => _api.delete('/api/farms/$id', decode: ApiClient.ignoreBody);
}

final farmsApiProvider = Provider((ref) => FarmsApi(ref.watch(apiClientProvider)));
```

The endpoints and request/response shapes are in the backend's `Controllers/*.cs` and `DTOs/**`, and in the Swagger page. The website's `frontend/src/features/*/api/*.ts` shows how it calls them.

For file uploads, pass a dio `FormData` as the `body` (see `AccountApi.uploadPhoto`).

### 5.2 Models

Models are **hand-written** classes with a `fromJson` factory (and `toJson` for request bodies). There is no code generation step. The API uses camelCase JSON names and sends enums as strings.

```dart
class Farm {
  const Farm({required this.id, required this.name, required this.createdAt, this.location});

  factory Farm.fromJson(Json json) => Farm(
    id: (json['farmId'] as num).toInt(),
    name: field<String>(json, 'name'),        // required: a clear error if missing
    location: json['location'] as String?,    // optional
    createdAt: parseApiDate(json['createdAt'] as String),
  );

  final int id;
  final String name;
  final String? location;
  final DateTime createdAt;
}
```

Helpers in `core/api/json.dart`: `Json`, `asJson`, `asJsonList`, `field<T>`, `parseApiDate` / `parseApiDateOrNull`. API dates are UTC; `parseApiDate` reads a date without an offset as UTC too. Show dates with the formatters, which convert to local time.

Numbers from JSON can be `int` or `double`: read them as `(json['x'] as num).toDouble()` or `.toInt()`.

### 5.3 Paged responses

Every list endpoint returns `{ items, page, pageSize, totalCount, totalPages }`. `ApiClient.getPaged` sends `page` and `pageSize` and returns a `Paged<T>` (`items`, `hasMore`, `totalCount`, …). Show it with the paged list ([§7](#7-paged-lists)).

---

## 6. Errors

Every failed call throws an `ApiException` with a `kind`:

| kind | When | Usually shown as |
|---|---|---|
| `network`, `timeout` | no answer (offline, server asleep) | "Can't reach the server…" with **Try again** |
| `badRequest` (400) | a rule failed: `{ message }` or validation `{ errors }` | the message, or under the field |
| `unauthorized` (401) | session over; already handled by the client | – |
| `forbidden` (403), `notFound` (404), `conflict` (409), `server` (5xx), `unknown` | | the server's `message` or a general message |

`error.serverMessage` is the server's `{ message }`. The server writes these in English, and the website shows them as they are, so we do too.

**In a form**, use `parseApiError` (a port of the website's `apiErrors.ts`). It returns messages for specific fields and general messages:

```dart
} on Object catch (error) {
  final parsed = parseApiError(error, context.l10n, generic: (l) => l.farmsDetailDeleteError);
  setState(() {
    _fieldErrors = parsed.fieldErrors;     // {'name': '...'} → AppTextField(serverError: ...)
    _generalErrors = parsed.generalErrors; // → ErrorBanner(messages: ...)
  });
}
```

It understands ASP.NET validation errors (`errors: { Field: [msg] }`, mapped through `serverFieldNames`; pass your own map for your DTO's fields), Identity error codes (translated), 409 conflicts, and a missing connection.

**On a screen that loads data**, use `ErrorView` (or `AsyncValueView`, which uses it). `describeError(error, l10n)` gives the one-line message.

**After an action** (a button that saves), show the result with `showToast(context, message, tone: ToastTone.error)`.

---

## 7. Paged lists

`PagedListController` holds the list's state (items, loading, errors). `PagedListView` draws it with infinite scroll, pull-to-refresh, loading, error-with-retry and an empty state:

```dart
class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late final _orders = PagedListController<Order>(
    loadPage: (page) => ref.read(ordersApiProvider).mine(page: page),
  );

  @override
  void dispose() {
    _orders.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AgriLinkAppBar(title: context.l10n.commonNavOrders),
    body: PagedListView<Order>(
      controller: _orders,
      empty: EmptyView(title: context.l10n.ordersListEmpty),
      itemBuilder: (context, order, index) => OrderCard(order: order),
    ),
  );
}
```

- `_orders.refresh()` reloads from page 1 (e.g. after creating one).
- `_orders.updateWhere((o) => o.id == id, (o) => updated)` changes one item in place, without reloading.

The notifications screen (`features/notifications/presentation/notifications_screen.dart`) is a working example.

---

## 8. Shared widgets

All in `lib/shared/`. Use these rather than writing your own.

| Widget / function | File | For |
|---|---|---|
| `LoadingView`, `ErrorView`, `EmptyView` | `widgets/state_views.dart` | whole-screen loading, error with **Try again**, and empty states |
| `AsyncValueView` | `widgets/state_views.dart` | a provider's `AsyncValue` with the three states above |
| `PagedListController`, `PagedListView` | `widgets/paged_list.dart` | infinite-scroll lists ([§7](#7-paged-lists)) |
| `AppTextField` | `widgets/form_fields.dart` | a labelled text field; `serverError` shows an API error under it |
| `PasswordField`, `PasswordChecklist` | `widgets/form_fields.dart` | password with show/hide; the live rules checklist |
| `AppDropdownField<T>` | `widgets/form_fields.dart` | a dropdown |
| `AppDateField` | `widgets/form_fields.dart` | a date picker field, shown in the user's language |
| `DistrictPicker` | `widgets/district_picker.dart` | the 25 districts (searchable, loaded from the API) |
| `LoadingButton` | `widgets/form_fields.dart` | the main button of a form, with a spinner while saving |
| `ErrorBanner`, `InfoBanner` | `widgets/form_fields.dart` | a form's general errors, or a notice |
| `showConfirmDialog` | `widgets/dialogs.dart` | "Are you sure?" (`destructive: true` for red) |
| `showToast` | `widgets/dialogs.dart` | a short message at the bottom (`ToastTone.success` / `.error`) |
| `StatusBadge`, `StatusBadge.status(kind, value)` | `widgets/status_badge.dart` | "Pending", "Approved"… translated and coloured |
| `UserAvatar` | `widgets/user_avatar.dart` | a person's photo, or their role's default picture |
| `CropIcon`, `cropCatalog`, `cropCatalogEntry`, `cropCatalogOrder`, `cropGroupLabel` | `widgets/crop_icon.dart` | the website's crop icons, groups and order; unknown crops get a generic icon |
| `LanguageSwitcher`, `ThemeModeButton` | `widgets/` | language and theme choices |
| `pickPhoto` | `media/photo_picker.dart` | take or choose a photo, shrunk and ready to upload ([§12](#12-photos-and-permissions)) |
| `ensureCameraPermission` | `permissions/permissions.dart` | ask for the camera properly ([§12](#12-photos-and-permissions)) |
| `FormValidators`, `normalizeNic`, `normalizePhone`, `normalizeUsername`… | `core/validation/validators.dart` | the website's validation rules |
| `formattersProvider` (`rupees`, `rupeesPerUnit`, `kilograms`, `number`, `date`, `dateTime`) | `core/format/formatters.dart` | prices, quantities and dates in the Sri Lankan locale |
| `statusLabel`, `cropLabel`, `roleLabel` | `l10n/labels.dart` | translate a value from the API |

Prices and quantities: `format.rupees(l10n, 1250.5)` → "Rs 1,250.5". Use `.mono` on the text style for numbers: `Text(price, style: textTheme.titleMedium!.mono)`.

---

## 9. Theme

The colours are the website's "Organic Bento" tokens from `frontend/src/index.css`, in light and dark.

| Token (`context.colors.…`) | Light | Dark | Use |
|---|---|---|---|
| `forest` | `#1f4d36` | `#7cbe8c` | primary: main buttons, active tab, links |
| `forestLight` | `#4a7c59` | `#9ed4aa` | softer green |
| `harvest` | `#d9a441` | `#e8bd60` | gold accent; put `ink` text on it |
| `terracotta` | `#c4623b` | `#dd7d55` | warm accent, the unread badge |
| `ink` | `#1f4d36` | `#10170f` | text on gold |
| `canvas` | `#faf7f0` | `#0f1512` | page background |
| `surface` | `#fffdf9` | `#17201a` | cards, sheets, app bars |
| `textPrimary` / `textSecondary` | `#26201a` / `#6b6259` | `#e9e4d9` / `#a49c8e` | text |
| `success` / `danger` / `info` | `#3e7a4f` / `#b84c3c` / `#3e7a82` | `#74c489` / `#e8806c` / `#66b3bb` | states |

Helpers: `colors.border`, `colors.borderStrong`, `colors.tint(color)` (a light wash for badge and banner backgrounds).

- **Never write a colour in a screen.** Use `Theme.of(context).colorScheme` (primary = forest, secondary = harvest, error = danger…) or `context.colors`. Then dark mode works with no extra code.
- Spacing: `Gaps.xs/sm/md/lg/xl` (4/8/16/24/32). Corners: `kRadius` (16).
- Fonts: **Fraunces** for headings (`headline*`, `titleLarge`), **Plus Jakarta Sans** for everything else, **JetBrains Mono** for numbers (`style.mono`). Sinhala and Tamil fall back to the bundled **Noto Sans Sinhala / Tamil**, so they look the same on every phone.
- Buttons, inputs, cards, sheets and dialogs are already styled by the theme. Use plain `FilledButton`, `OutlinedButton`, `Card`, `TextFormField`… without styling them.
- Touch targets are at least 48 dp; keep custom tappable things that size. Give every `IconButton` a `tooltip` (it's the screen reader label).

The light/dark/system choice is in the profile (and on the login screen) and is remembered.

---

## 10. Translations

The app speaks English, Sinhala and Tamil, using Flutter's gen-l10n with ARB files.

### 10.1 Where strings come from

1. **The website's strings.** `tool/import_web_translations.dart` reads the website's `frontend/src/i18n/locales/{en,si,ta}/*.json` (all nine namespaces) and writes `lib/l10n/arb/app_{en,si,ta}.arb`.
2. **Mobile-only strings** (things the website doesn't need) are in `lib/l10n/mobile/{en,si,ta}.json`, with the same key prefixes. The script adds them to the end of each ARB file, after an `@@x-mobile-only` marker.

### 10.2 Key names

`<namespace>.<path>` becomes one camelCase name:

| Website file and key | Dart getter |
|---|---|
| `auth.json` → `login.submit` | `context.l10n.authLoginSubmit` |
| `common.json` → `nav.farms` | `context.l10n.commonNavFarms` |
| `common.json` → `cropTypes.Green Gram` | `context.l10n.commonCropTypesGreenGram` |
| `common.json` → `pagination.pageOf` = "Page {{page}} of {{totalPages}}" | `context.l10n.commonPaginationPageOf(page, totalPages)` |

i18next placeholders `{{name}}` become method parameters. Each English ARB entry has a `description` with the original website key, so you can search the website code for it.

**Before adding a string, look for it in `app_en.arb`.** The website probably has it already.

### 10.3 Adding a mobile-only string

1. Write the three translations in a small JSON file (anywhere, e.g. your scratch folder):

   ```json
   {
     "farms.detail.noFields": {
       "en": "This farm has no fields yet.",
       "si": "…",
       "ta": "…"
     }
   }
   ```

2. Run:

   ```bash
   python tool/add_mobile_strings.py my_strings.json
   dart run tool/import_web_translations.dart
   flutter gen-l10n
   ```

3. Use `context.l10n.farmsDetailNoFields`.

Ask a Sinhala or Tamil speaker in the team to check new translations. The script refuses a mobile key that already exists on the website, two keys that would get the same Dart name, and translations whose placeholders differ from English.

### 10.4 When the website's translations change

Pull the website repository, then run the import again (`--web <path>` if it isn't next to this repo):

```bash
dart run tool/import_web_translations.dart
flutter gen-l10n
```

Commit the changed ARB files and `web_keys.g.dart`. The generated `lib/l10n/generated/` is **not committed**. `flutter pub get`, `flutter run` and `flutter test` regenerate it; run `flutter gen-l10n` if your editor shows `AppLocalizations` as missing.

### 10.5 Values from the API

The API sends statuses and crop names as English words ("AwaitingReview", "Green Gram"). Translate them with the helpers in `l10n/labels.dart`, like the website's `useStatusLabel` / `useCropLabel`:

```dart
statusLabel(l10n, StatusKind.issue, issue.status)  // "Awaiting review" / Sinhala / Tamil
cropLabel(l10n, crop.cropType)
roleLabel(l10n, user.role.apiName)
StatusBadge.status(StatusKind.order, order.status) // translated and coloured
```

Anything unknown is shown as it is. For other runtime keys there is `translateWebKey(l10n, 'common.status.issue.Pending')`.

### 10.6 Dates and numbers

Use `ref.watch(formattersProvider)`, which follows the chosen language with the Sri Lankan locales (`en_LK`, `si_LK`, `ta_LK`) like the website.

---

## 11. Session, sign-in and the current user

- `sessionControllerProvider` (`core/session/`) is the single source of truth for who is signed in: `status` (restoring / signedOut / signedIn), `role` and `token`. The token is kept in Android's encrypted storage and restored at start-up; an expired token (JWTs last 8 hours, with no refresh token) is dropped straight away.
- `currentUserProvider` (`features/auth/application/current_user.dart`) is the signed-in user's profile from `GET /api/users/me`: name, role, district, `farmerProfileId` for farmers, and so on.

  ```dart
  final user = ref.watch(currentUserProvider).value; // null while loading or signed out
  ```

  After an endpoint returns an updated profile, call `ref.read(currentUserProvider.notifier).set(profile)`.
- Sign out: `ref.read(authServiceProvider).signOut()`. It clears the token, and every provider watching the session is cleared with it.
- A password change (or an admin changing their own email) returns a new token, which replaces the stored one (`SessionController.signIn`). Otherwise the next request would get a 401.
- You don't check the role in your screens: the route guards do. If a screen differs by role, read `ref.watch(sessionControllerProvider).role`.

---

## 12. Photos and permissions

```dart
final photo = await pickPhoto(context, ref); // null if the user backed out
if (photo != null) {
  await api.uploadIssuePhoto(issueId, photo); // multipart, see AccountApi.uploadPhoto
}
```

`pickPhoto` asks "Take a photo / Choose from gallery". Then:

- **Camera:** it explains why, asks Android, and if the camera was turned off for good, offers to open the settings.
- **Gallery:** it uses Android's photo picker, which needs no permission.

It shrinks the photo to **1600 px on the long side** and re-encodes it as **JPEG quality 80**, with the EXIF data (e.g. GPS) removed. That keeps it well under the API's 5 MB limit and turns HEIC photos into JPEG. In tests, override `photoPickerProvider` and `permissionServiceProvider` (see `test/features/account/account_test.dart`).

Only ask for a permission at the moment the user does something that needs it.

---

## 13. Notifications

- `unreadCountProvider` (`features/notifications/application/unread_count.dart`) is the unread count shown on the bell. There are no push notifications yet: while the app is open and the user is signed in, it asks `GET /api/notifications/unread-count` every 60 s and whenever the app comes back to the foreground.
- When the count goes up, `NotificationPresenter` tells the user: a system pop-up, or an in-app message with **View** if pop-ups aren't allowed. Tapping either opens the list.
- The Android 13+ notification permission is asked once, two seconds after the user first reaches their home, with an explanation first. The notifications screen offers **Turn on** while it is off.
- If your action creates a notification for the current user and you want the badge updated at once, call `ref.read(unreadCountProvider.notifier).refresh()`.

**Adding Firebase push later:** add `firebase_messaging`, and in its foreground and background handlers call `ref.read(unreadCountProvider.notifier).refresh()` (or show the pushed message through `NotificationPresenter`). Then the polling interval can be made longer. No screen needs to change.

---

## 14. Testing

```bash
flutter test                      # everything
flutter test test/features/auth   # one folder
flutter analyze                   # must say "No issues found!"
dart format lib test tool         # before committing
```

**Tests never call the live API.** The helpers in `test/helpers/`:

- `FakeApi`: a pretend server. Register answers with `api.on('GET', '/api/farms/mine', (request) => FakeResponse(200, {...}))`. It records every request, so you can check what was sent (`api.lastTo('POST', '/api/farms')!.json`). `api.offline(method, path)` fakes a missing connection. Anything unregistered answers 404.
- `pumpAgriLink(tester, api: api, session: Session(token: fakeJwt(), role: Role.farmer))`: starts the **whole app** (router, shell, theme, translations) signed in as that role, on a phone-sized screen. It returns `TestApp` with the fake API, the stored session and the provider container. Options: `language: 'si'`, `screen: Size(320, 640)`, `permissions:`, `overrides:`.
- `profileJson(role)`: a `/api/users/me` body. Register it for signed-in tests.
- `tester.fill(finder, text)` and `tester.tapVisible(finder)`: scroll to a field or button, then type or tap.
- `pumpApp(widget)` (`pump_app.dart`): one widget with the theme and translations, for small widget tests.
- `FakePermissions`, `FakePresenter` (`fakes.dart`).

Give fields and buttons a `Key` (`Key('farm-name')`) so tests can find them. `test/features/auth/register_test.dart` and `test/app/shell_test.dart` are good examples.

For live testing on the emulator, sign in with test accounts on the **development** API. Never put account details in the code or tests.

---

## 15. Conventions

- **Formatting:** `dart format` with a 100-column line length (set in `analysis_options.yaml`). Strict analysis: zero issues.
- **Line endings:** LF (`.gitattributes`), whatever your editor does.
- **Comments:** explain *why*, in plain words, like the existing code. Public classes get a `///` doc comment.
- **Commits:** small, one step each, imperative subject ("Add the farm detail screen"). Branch per phase (`feature/phase-2-farmer`), pull request into `main`.
- **Packages:** agree as a team before adding one. Use `flutter pub add` so versions fit Flutter 3.47.5, and commit `pubspec.lock`.
- **Secrets:** none in the repo. It's public. No passwords, tokens or test accounts in code, tests or docs.
- **Backend:** read-only. If something seems to need a backend change, raise it with the team instead of working around it.

---

## 16. Known issues

- `compileSdk` is **37** (`android/app/build.gradle.kts`) because `permission_handler_android` needs it; Flutter's default is 36. Gradle downloads the Android 37 platform the first time you build.
- The build warns that `flutter_image_compress_common` applies the Kotlin Gradle Plugin, which future Flutter versions will reject. It works with Flutter 3.47.5. Check for a newer version of the package if the team ever upgrades Flutter.
- The first request after the API has been idle can take 10–30 s. The login and splash screens say so after 5 s; other screens just show their spinner.
