import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

const _video = VideoModel(
  videoId: 'v1',
  youtubeVideoId: 'abc',
  title: '제주 브이로그',
  isCached: false,
  places: [],
);

Widget _wrap(VideoProvider provider) => ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: AnalyzingScreen()),
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
                MaterialPageRoute<void>(builder: (_) => const AnalyzingScreen()),
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
}
