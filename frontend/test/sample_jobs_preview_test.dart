import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/core/theme/app_theme.dart';
import 'package:vetrijobs/data/sample_jobs.dart';
import 'package:vetrijobs/features/candidate/sample_job_details_screen.dart';

void main() {
  test('client preview contains ten distinct local sample jobs', () {
    expect(SampleJobs.all, hasLength(10));
    expect(SampleJobs.all.map((job) => job.id).toSet(), hasLength(10));
    expect(
      SampleJobs.all.every((job) => job.isDemo && !job.isVerified),
      isTrue,
    );
    expect(() => SampleJobs.all.first.toMap(), throwsStateError);
  });

  testWidgets(
    'sample detail offers preview actions on a narrow Android screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var previewTaps = 0;
      var saveTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SampleJobDetailsScreen(
            job: SampleJobs.all.first,
            isSaved: false,
            onToggleSaved: () => saveTaps++,
            onPreviewApply: () => previewTaps++,
          ),
        ),
      );

      expect(find.text('SAMPLE JOB · PREVIEW ONLY'), findsOneWidget);
      expect(find.text('Preview apply'), findsOneWidget);
      expect(find.text('Call'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Preview apply'));
      expect(previewTaps, 1);

      await tester.tap(find.byTooltip('Save preview job'));
      await tester.pump();
      expect(saveTaps, 1);
      expect(find.byTooltip('Remove preview bookmark'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
