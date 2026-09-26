import 'package:agrilink_mobile/features/issues/data/advisory.dart';
import 'package:agrilink_mobile/features/officer/presentation/widgets/agent_trace_panel.dart';
import 'package:agrilink_mobile/features/officer/presentation/widgets/photo_diagnosis_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'officer_fixtures.dart';

Future<void> show(WidgetTester tester, Widget child, {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpApp(SingleChildScrollView(child: child), locale: locale);
}

void main() {
  group('the photo diagnosis panel', () {
    testWidgets('shows what the model identified, how sure it was and why it needs a review', (
      tester,
    ) async {
      await show(tester, PhotoDiagnosisPanel(advisory: reviewerAdvisory(photo: true)));
      expect(find.text('Photo diagnosis'), findsOneWidget);
      expect(find.text('Identified: Leaf spot'), findsOneWidget);
      expect(find.text('91% model confidence'), findsOneWidget);
      expect(find.text('Model v2.1'), findsOneWidget);
      expect(find.text('Why this needs your review'), findsOneWidget);
      expect(
        find.text('This disease is marked serious and always needs an officer.'),
        findsOneWidget,
      );
    });

    testWidgets('a reason the app does not know is shown as it is', (tester) async {
      await show(
        tester,
        PhotoDiagnosisPanel(
          advisory: reviewerAdvisory(
            photo: true,
            diagnosis: {
              'escalationReasons': ['SomethingNew'],
            },
          ),
        ),
      );
      expect(find.text('SomethingNew'), findsOneWidget);
    });

    testWidgets('preliminary advice says it has already gone to the farmer', (tester) async {
      await show(
        tester,
        PhotoDiagnosisPanel(advisory: reviewerAdvisory(status: 'Preliminary', photo: true)),
      );
      expect(find.textContaining('Preliminary advice has already been sent'), findsOneWidget);
    });

    testWidgets('a draft does not say that', (tester) async {
      await show(tester, PhotoDiagnosisPanel(advisory: reviewerAdvisory(photo: true)));
      expect(find.textContaining('Preliminary advice has already been sent'), findsNothing);
    });

    testWidgets('shows nothing when there was no photo diagnosis', (tester) async {
      await show(tester, PhotoDiagnosisPanel(advisory: reviewerAdvisory()));
      expect(find.text('Photo diagnosis'), findsNothing);
    });

    testWidgets('fits a narrow screen in Sinhala', (tester) async {
      tester.view.physicalSize = const Size(320, 640) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        SingleChildScrollView(child: PhotoDiagnosisPanel(advisory: reviewerAdvisory(photo: true))),
        locale: const Locale('si'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the agent trace panel', () {
    AgentTrace trace() => reviewerAdvisory().agentTrace!;

    testWidgets('starts closed, with the status and number of steps', (tester) async {
      await show(tester, AgentTracePanel(trace: trace()));
      expect(find.text('How this was diagnosed'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('2 steps'), findsOneWidget);
      expect(find.text('Planner'), findsNothing);
    });

    testWidgets('opens to a card for each step with its name, status and time', (tester) async {
      await show(tester, AgentTracePanel(trace: trace()));
      await tester.tap(find.text('How this was diagnosed'));
      await tester.pumpAndSettle();

      expect(find.text('Planner'), findsOneWidget);
      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('350 ms'), findsOneWidget);
      expect(find.text('2.4 s'), findsOneWidget);
      // The failed step is written out, not only coloured.
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('This step produced no output.'), findsOneWidget);
    });

    testWidgets('a step\'s output is shown as labelled values, never raw JSON', (tester) async {
      await show(tester, AgentTracePanel(trace: trace()));
      await tester.tap(find.text('How this was diagnosed'));
      await tester.pumpAndSettle();

      expect(find.text('Agents To Run'), findsOneWidget);
      expect(find.text('Crop Analysis Agent'), findsNothing);
      expect(find.text('CropAnalysisAgent'), findsOneWidget);
      expect(find.text('Use Crop Agent'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('0.50'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('{'), findsNothing);
      expect(find.textContaining('['), findsNothing);
    });

    testWidgets('what a step was given is one more tap away', (tester) async {
      await show(tester, AgentTracePanel(trace: trace()));
      await tester.tap(find.text('How this was diagnosed'));
      await tester.pumpAndSettle();
      expect(find.text('Green Gram'), findsNothing);

      await tester.tap(find.text('Show what this step was given'));
      await tester.pumpAndSettle();
      expect(find.text('Crop Type'), findsOneWidget);
      expect(find.text('Green Gram'), findsOneWidget);
    });

    testWidgets('a long list shows the first few and how many more', (tester) async {
      final long = AgentTrace.fromJson({
        'objective': 'x',
        'status': 'Running',
        'startedAt': '2026-09-20T08:30:00Z',
        'steps': [
          {
            'agentName': 'CropAnalysisAgent',
            'status': 'Running',
            'startedAt': '2026-09-20T08:30:00Z',
            'output': {
              'findings': [for (var i = 1; i <= 8; i++) 'Finding $i'],
            },
          },
        ],
      });
      await show(tester, AgentTracePanel(trace: long));
      await tester.tap(find.text('How this was diagnosed'));
      await tester.pumpAndSettle();

      expect(find.text('Finding 5'), findsOneWidget);
      expect(find.text('Finding 6'), findsNothing);
      expect(find.text('+3 more'), findsOneWidget);
      expect(find.text('Running'), findsWidgets);
    });

    testWidgets('a trace with no steps shows nothing', (tester) async {
      final empty = AgentTrace.fromJson({
        'objective': 'x',
        'status': 'Completed',
        'startedAt': '2026-09-20T08:30:00Z',
        'steps': <Object?>[],
      });
      await show(tester, AgentTracePanel(trace: empty));
      expect(find.text('How this was diagnosed'), findsNothing);
    });

    testWidgets('fits a narrow screen in Tamil', (tester) async {
      tester.view.physicalSize = const Size(320, 640) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        SingleChildScrollView(child: AgentTracePanel(trace: trace())),
        locale: const Locale('ta'),
      );
      await tester.tap(find.byKey(const Key('agent-trace')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
