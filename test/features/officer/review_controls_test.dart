import 'package:agrilink_mobile/features/issues/data/advisory.dart';
import 'package:agrilink_mobile/features/officer/application/review_rules.dart';
import 'package:agrilink_mobile/features/officer/data/review_api.dart';
import 'package:agrilink_mobile/features/officer/presentation/widgets/review_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_app.dart';
import 'officer_fixtures.dart';

/// What the controls sent, in order.
class _Sent {
  final decisions = <(ReviewAction, Map<String, Object?>)>[];
  Object? failWith;

  Future<void> call(ReviewAction action, ReviewAdvisoryRequest request) async {
    if (failWith != null) {
      throw failWith!;
    }
    decisions.add((action, request.toJson()));
  }
}

void main() {
  late _Sent sent;

  setUp(() => sent = _Sent());

  Future<void> show(WidgetTester tester, Advisory advisory) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      SingleChildScrollView(
        child: ReviewControls(advisory: advisory, onSubmit: sent.call),
      ),
    );
  }

  Finder key(String name) => find.byKey(Key(name));
  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  void expectSent(ReviewAction action, Map<String, Object?> body) {
    expect(sent.decisions, hasLength(1));
    expect(sent.decisions.single.$1, action);
    expect(sent.decisions.single.$2, equals(body));
  }

  Future<void> approve(WidgetTester tester) async {
    await tester.tapVisible(key('review-approve'));
  }

  Future<void> reject(WidgetTester tester) async {
    await tester.tapVisible(key('review-reject'));
  }

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(inDialog(label));
    await tester.pumpAndSettle();
  }

  Future<void> chooseDisease(WidgetTester tester, String name) async {
    await tester.tapVisible(key('review-disease'));
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  group('an advisory without a photo diagnosis', () {
    testWidgets('shows only the note and the two decisions', (tester) async {
      await show(tester, reviewerAdvisory());
      expect(key('review-note'), findsOneWidget);
      expect(key('review-treatment'), findsNothing);
      expect(key('review-disease'), findsNothing);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('approving asks first, then sends the note', (tester) async {
      await show(tester, reviewerAdvisory());
      await tester.fill(key('review-note'), '  Looks right  ');
      await approve(tester);

      expect(find.text('Approve this advisory?'), findsOneWidget);
      expect(find.textContaining('the farmer will be told your decision'), findsOneWidget);
      expect(sent.decisions, isEmpty);

      await confirm(tester, 'Approve');
      expectSent(ReviewAction.approve, {'note': 'Looks right'});
    });

    testWidgets('backing out of the confirmation sends nothing', (tester) async {
      await show(tester, reviewerAdvisory());
      await approve(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(sent.decisions, isEmpty);
    });

    testWidgets('rejecting is allowed without a note, as on the website', (tester) async {
      await show(tester, reviewerAdvisory());
      await reject(tester);
      expect(find.text('Reject this advisory?'), findsOneWidget);
      await confirm(tester, 'Reject');
      expectSent(ReviewAction.reject, {});
    });

    testWidgets('a rejection can carry a note', (tester) async {
      await show(tester, reviewerAdvisory());
      await tester.fill(key('review-note'), 'The photo shows a different pest.');
      await reject(tester);
      await confirm(tester, 'Reject');
      expectSent(ReviewAction.reject, {'note': 'The photo shows a different pest.'});
    });
  });

  group('a photo diagnosis still held as a draft', () {
    final draft = reviewerAdvisory(photo: true);

    testWidgets('the buttons are named for what they do to the diagnosis', (tester) async {
      await show(tester, draft);
      expect(find.text('Confirm diagnosis'), findsOneWidget);
      expect(find.text('Correct diagnosis'), findsOneWidget);
    });

    testWidgets('confirming needs the treatment, and says so on the field', (tester) async {
      await show(tester, draft);
      expect(find.text('Treatment for the farmer'), findsOneWidget);
      await approve(tester);

      expect(find.text('Add the treatment the farmer should follow.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(sent.decisions, isEmpty);
    });

    testWidgets('confirming with a treatment sends it, and no disease', (tester) async {
      await show(tester, draft);
      await tester.fill(key('review-treatment'), 'Spray a copper fungicide.');
      await approve(tester);
      expect(find.text('Confirm this diagnosis?'), findsOneWidget);
      await confirm(tester, 'Confirm diagnosis');

      expectSent(ReviewAction.approve, {'treatment': 'Spray a copper fungicide.'});
    });

    testWidgets('choosing another disease while confirming points to Correct diagnosis', (
      tester,
    ) async {
      await show(tester, draft);
      await tester.fill(key('review-treatment'), 'Spray.');
      await chooseDisease(tester, 'Rust');
      await approve(tester);

      expect(find.text('To change the diagnosis, use Correct diagnosis.'), findsOneWidget);
      expect(sent.decisions, isEmpty);
    });

    testWidgets('correcting needs the disease and the treatment', (tester) async {
      await show(tester, draft);
      await reject(tester);

      expect(find.text('Choose the correct disease to correct the diagnosis.'), findsOneWidget);
      expect(find.text('Add the treatment the farmer should follow.'), findsOneWidget);
      expect(sent.decisions, isEmpty);
    });

    testWidgets('correcting with both sends the disease and the treatment', (tester) async {
      await show(tester, draft);
      await tester.fill(key('review-treatment'), 'Remove the affected leaves.');
      await chooseDisease(tester, 'Rust');
      await tester.fill(key('review-note'), 'It is rust, not leaf spot.');
      await reject(tester);
      expect(find.text('Correct this diagnosis?'), findsOneWidget);
      await confirm(tester, 'Correct diagnosis');

      expectSent(ReviewAction.reject, {
        'note': 'It is rust, not leaf spot.',
        'treatment': 'Remove the affected leaves.',
        'diseaseKey': 'rust',
      });
    });

    testWidgets('the suggested treatment can be copied into the treatment field', (tester) async {
      await show(tester, draft);
      expect(find.text('Suggested treatment (not officer-approved)'), findsOneWidget);
      expect(find.text('Spray a copper fungicide every 7 days.'), findsOneWidget);

      await tester.tapVisible(key('review-use-suggested'));
      expect(
        tester.widget<TextFormField>(key('review-treatment')).controller!.text,
        'Spray a copper fungicide every 7 days.',
      );
    });

    testWidgets('the disease list is the one the API sent', (tester) async {
      await show(tester, draft);
      await tester.tapVisible(key('review-disease'));
      expect(find.text('Leaf spot'), findsWidgets);
      expect(find.text('Rust'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });
  });

  group('preliminary advice, already sent to the farmer', () {
    final preliminary = reviewerAdvisory(status: 'Preliminary', photo: true);

    testWidgets('confirming needs no treatment', (tester) async {
      await show(tester, preliminary);
      expect(
        find.text('Treatment for the farmer (optional — replaces the preliminary advice)'),
        findsOneWidget,
      );
      await approve(tester);
      await confirm(tester, 'Confirm diagnosis');
      expect(sent.decisions.single.$1, ReviewAction.approve);
    });

    testWidgets('correcting still needs the disease and the treatment', (tester) async {
      await show(tester, preliminary);
      await reject(tester);
      expect(find.text('Choose the correct disease to correct the diagnosis.'), findsOneWidget);
      expect(sent.decisions, isEmpty);
    });
  });

  group('when the decision cannot be sent', () {
    testWidgets('what the officer typed stays and they can try again', (tester) async {
      sent.failWith = Exception('offline');
      await show(tester, reviewerAdvisory());
      await tester.fill(key('review-note'), 'My note');
      await approve(tester);
      await confirm(tester, 'Approve');

      expect(sent.decisions, isEmpty);
      expect(tester.widget<TextFormField>(key('review-note')).controller!.text, 'My note');

      sent.failWith = null;
      await approve(tester);
      await confirm(tester, 'Approve');
      expect(sent.decisions.single.$2, {'note': 'My note'});
    });
  });

  testWidgets('the controls fit a narrow screen in Tamil', (tester) async {
    tester.view.physicalSize = const Size(320, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      SingleChildScrollView(
        child: ReviewControls(advisory: reviewerAdvisory(photo: true), onSubmit: sent.call),
      ),
      locale: const Locale('ta'),
    );
    expect(tester.takeException(), isNull);
  });
}
