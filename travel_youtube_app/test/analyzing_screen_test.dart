import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/screens/analyzing_screen.dart';

class FakeVideoRepository extends VideoRepository {
  /// Held open so the screen can be observed mid-analysis, then completed
  /// to let it close.
  final Completer<VideoModel> pending = Completer<VideoModel>();

  @override
  Future<VideoModel> analyze(String youtubeUrl) => pending.future;
}

/// Fails every call, or only the first when [failuresBeforeSuccess] is 1 --
/// enough to watch 다시 시도 recover.
class FailingVideoRepository extends VideoRepository {
  FailingVideoRepository({this.failuresBeforeSuccess});

  final int? failuresBeforeSuccess;
  int calls = 0;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    calls++;
    if (failuresBeforeSuccess == null || calls <= failuresBeforeSuccess!) {
      throw const ApiException(code: 'AI_TIMEOUT', message: 'timed out');
    }
    return _video;
  }
}

const _video = VideoModel(
  videoId: 'v1',
  youtubeVideoId: 'abc',
  title: '제주 브이로그',
  isCached: false,
  places: [],
);

Widget _wrap(VideoProvider provider) => ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: AnalyzingScreen(youtubeUrl: 'https://youtu.be/abc')),
    );

void main() {
  testWidgets('shows the countdown and the four steps while analyzing', (
    tester,
  ) async {
    final repository = FakeVideoRepository();
    final provider = VideoProvider(repository: repository);
    unawaited(provider.analyze('https://youtu.be/abc'));

    await tester.pumpWidget(_wrap(provider));

    expect(find.text('영상을 분석하고 있어요'), findsOneWidget);
    expect(find.textContaining('잠시만 기다려 주세요 · 약'), findsOneWidget);
    for (final step in ['자막 불러오기', '장소 후보 추출', '지도 좌표 매칭', '결과 정리']) {
      expect(find.text(step), findsOneWidget);
    }

    // Let the analysis finish so the ticker stops before the test ends.
    repository.pending.complete(_video);
    await tester.pump();
  });

  testWidgets('past the estimate it stops counting down and says 거의 다 됐어요', (
    tester,
  ) async {
    // A long video can outrun the 20s estimate; a countdown that passes zero
    // and keeps going reads as a hang.
    final repository = FakeVideoRepository();
    final provider = VideoProvider(repository: repository);
    unawaited(provider.analyze('https://youtu.be/abc'));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(seconds: 21));

    expect(find.text('거의 다 됐어요'), findsOneWidget);
    expect(find.textContaining('잠시만 기다려 주세요'), findsNothing);

    repository.pending.complete(_video);
    await tester.pump();
  });

  testWidgets('closes itself once the analysis is done', (tester) async {
    final repository = FakeVideoRepository();
    final provider = VideoProvider(repository: repository);
    unawaited(provider.analyze('https://youtu.be/abc'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AnalyzingScreen(youtubeUrl: 'https://youtu.be/abc'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('영상을 분석하고 있어요'), findsOneWidget);

    repository.pending.complete(_video);
    // Driven frame by frame rather than with pumpAndSettle: the in-progress
    // step keeps a spinner running, which never settles.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('영상을 분석하고 있어요'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a failed analysis stays on this screen and offers 다시 시도 / 취소', (
    tester,
  ) async {
    // It used to close and let the home screen show the error inline, under
    // the input, where it shared the page with everything else.
    final provider = VideoProvider(repository: FailingVideoRepository());
    await tester.pumpWidget(_wrap(provider));
    await provider.analyze('https://youtu.be/abc');
    await tester.pumpAndSettle();

    expect(find.text('분석하지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('영상을 분석하고 있어요'), findsNothing);
  });

  testWidgets('다시 시도 runs the same analysis again', (tester) async {
    final repository = FailingVideoRepository(failuresBeforeSuccess: 1);
    final provider = VideoProvider(repository: repository);
    await tester.pumpWidget(_wrap(provider));
    await provider.analyze('https://youtu.be/abc');
    await tester.pumpAndSettle();

    await tester.tap(find.text('다시 시도'));
    // Pumped a frame at a time, not settled: the retry restarts the 100ms
    // countdown ticker, which keeps scheduling frames for as long as the
    // analysis is running.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repository.calls, 2);
    expect(find.text('분석하지 못했어요'), findsNothing);
  });

  testWidgets('취소 leaves and clears the failure', (tester) async {
    final repository = FakeVideoRepository();
    final provider = VideoProvider(repository: repository);
    // Started before the screen opens: it closes itself when it finds no
    // analysis running, so it has to be pushed onto a loading one.
    unawaited(provider.analyze('https://youtu.be/abc'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AnalyzingScreen(youtubeUrl: 'https://youtu.be/abc'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    repository.pending.completeError(
      const ApiException(code: 'AI_TIMEOUT', message: 'timed out'),
    );
    await tester.pumpAndSettle();
    expect(find.text('분석하지 못했어요'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('분석하지 못했어요'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    // The abandoned attempt must not linger as the current state.
    expect(provider.errorMessage, isNull);
  });
}
