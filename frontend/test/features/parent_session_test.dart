import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/presentation/onboarding_page.dart';
import 'package:life_record/features/parent_answer/presentation/parent_answer_controller.dart';
import 'package:life_record/features/parent_answer/presentation/parent_answer_page.dart';
import 'package:life_record/features/recording/presentation/recording_args.dart';
import 'package:life_record/features/recording/presentation/recording_controller.dart';
import 'package:life_record/features/recording/presentation/recording_page.dart';

import 'parent_answer/fake_parent_answer_repository.dart';
import 'recording/fakes.dart';

void main() {
  for (final status in [401, 403]) {
    for (final scenario in ['upload', 'poll', 'answer', 'tts']) {
      testWidgets('$scenario $status: 올바른 화면으로 이동하고 세션을 처리한다', (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'access_token': 'test-token',
          'current_user': jsonEncode({
            'id': 'parent',
            'name': '부모',
            'role': 'PARENT',
            'pairingStatus': 'PAIRED',
          }),
          'device_id': 'keep-device',
        });
        final error = ApiException(statusCode: status);
        final recordingRepo = FakeRecordingRepository();
        final answerRepo = FakeParentAnswerRepository();
        final args = RecordingArgs(
          assignmentId: 'asg_1',
          questionText: '질문',
          recordingId: scenario == 'poll' ? 'rec_1' : null,
        );
        RecordingController? recording;
        late Widget page;
        if (scenario == 'upload' || scenario == 'poll') {
          if (scenario == 'upload') recordingRepo.uploadError = error;
          if (scenario == 'poll') recordingRepo.pollError = error;
          recording = RecordingController(
            args: args,
            repository: recordingRepo,
            recorder: FakeRecorder(),
          );
          page = RecordingPage(args: args, controller: recording);
        } else {
          if (scenario == 'answer') answerRepo.todayError = error;
          if (scenario == 'tts') answerRepo.audioError = error;
          page = ParentAnswerPage(
            controller: ParentAnswerController(answerRepo),
          );
        }
        final router = GoRouter(
          initialLocation: '/subject',
          routes: [
            GoRoute(path: '/subject', builder: (_, _) => page),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => const OnboardingPage(),
            ),
            GoRoute(
              path: '/today',
              builder: (_, _) => const Scaffold(body: Text('오늘 화면')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        if (scenario == 'upload') {
          await recording!.start();
          await recording.stop();
        }
        await tester.pumpAndSettle();
        const storage = FlutterSecureStorage();
        if (status == 401) {
          expect(find.text('카카오로 시작하기'), findsOneWidget);
          expect(await storage.read(key: 'access_token'), isNull);
          expect(await storage.read(key: 'current_user'), isNull);
        } else {
          expect(find.text('오늘 화면'), findsOneWidget);
          expect(await storage.read(key: 'access_token'), 'test-token');
          expect(await storage.read(key: 'current_user'), isNotNull);
        }
        expect(await storage.read(key: 'device_id'), 'keep-device');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
