import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/enums.dart';
import 'package:gym_tracker_flutter/models/exercise.dart';
import 'package:gym_tracker_flutter/models/planner_state.dart';
import 'package:gym_tracker_flutter/models/routine.dart';
import 'package:gym_tracker_flutter/providers/workout_provider.dart';

Routine _routine(String id, String name, {int sets = 3}) => Routine(
      id: id,
      name: name,
      defaultRest: 60,
      exercises: [
        RoutineExercise(
          id: 're-$id',
          exerciseId: 'ex-$id',
          sets: sets,
          reps: 10,
          rest: 60,
          weight: 20,
          isCardio: false,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Mock do canal nativo do Watch/iOS para não lançar MissingPluginException
    const channel = MethodChannel('com.vicente.losmooscles/watch');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  group('Planner actions (dias fixos)', () {
    late WorkoutProvider provider;

    setUp(() {
      provider = WorkoutProvider();
    });

    test('addPlannerItem adiciona slot vazio e updatePlannerItem preenche', () {
      provider.addPlannerItem('seg');
      expect(provider.planner['seg'], ['']);

      provider.updatePlannerItem('seg', 0, 'routine:r1');
      expect(provider.planner['seg'], ['routine:r1']);
    });

    test('removePlannerItem remove o item de verdade', () {
      provider.addPlannerItem('seg');
      provider.updatePlannerItem('seg', 0, 'routine:r1');
      provider.addPlannerItem('seg');
      provider.updatePlannerItem('seg', 1, 'exercise:e1:3');

      provider.removePlannerItem('seg', 0);
      expect(provider.planner['seg'], ['exercise:e1:3']);

      provider.removePlannerItem('seg', 0);
      expect(provider.planner['seg'], isEmpty);
    });

    test('reorderPlannerItem troca posições', () {
      provider.planner['seg'] = ['routine:a', 'routine:b', 'routine:c'];
      provider.reorderPlannerItem('seg', 0, false); // move para baixo
      expect(provider.planner['seg'], ['routine:b', 'routine:a', 'routine:c']);
    });

    test('copyPlannerDay copia itens para outro dia', () {
      provider.planner['seg'] = ['routine:a', 'exercise:e1:3'];
      provider.copyPlannerDay('seg', 'qua');
      expect(provider.planner['qua'], ['routine:a', 'exercise:e1:3']);
      // origem permanece intacta
      expect(provider.planner['seg'], ['routine:a', 'exercise:e1:3']);
    });
  });

  group('Continuous list', () {
    late WorkoutProvider provider;

    setUp(() {
      provider = WorkoutProvider();
      provider.routines = [
        _routine('r1', 'Treino A'),
        _routine('r2', 'Treino B'),
        _routine('r3', 'Treino C'),
      ];
    });

    test('flatContinuousList achata blocos na ordem', () {
      provider.addContinuousBlock(name: 'Bloco 1');
      provider.addRoutineToContinuousBlock(
          provider.continuousBlocks.first.id, 'routine:r1');
      provider.addRoutineToContinuousBlock(
          provider.continuousBlocks.first.id, 'routine:r2');
      provider.addContinuousBlock(name: 'Bloco 2');
      provider.addRoutineToContinuousBlock(
          provider.continuousBlocks.last.id, 'exercise:e9:3');

      expect(provider.flatContinuousList,
          ['routine:r1', 'routine:r2', 'exercise:e9:3']);
    });

    test('todayPlannedItems retorna item do índice atual no modo contínuo', () {
      provider.settings = provider.settings.copyWith(
        organizationMode: OrganizationMode.continuousList,
        continuousListCurrentIndex: 1,
      );
      provider.addContinuousBlock();
      final blockId = provider.continuousBlocks.first.id;
      provider.addRoutineToContinuousBlock(blockId, 'routine:r1');
      provider.addRoutineToContinuousBlock(blockId, 'routine:r2');
      provider.addRoutineToContinuousBlock(blockId, 'routine:r3');

      expect(provider.todayPlannedItems, ['routine:r2']);
    });

    test('todayPlannedItems retorna vazio quando hoje é descanso', () {
      final now = DateTime.now();
      final todayKey =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      provider.settings = provider.settings.copyWith(
        organizationMode: OrganizationMode.continuousList,
        continuousListRestDate: todayKey,
      );
      provider.addContinuousBlock();
      provider.addRoutineToContinuousBlock(
          provider.continuousBlocks.first.id, 'routine:r1');

      expect(provider.todayPlannedItems, isEmpty);
      expect(provider.isContinuousRestToday, isTrue);
    });

    test('setContinuousListRestToday limpa descanso ao desativar', () {
      provider.setContinuousListRestToday(true);
      expect(provider.isContinuousRestToday, isTrue);
      provider.setContinuousListRestToday(false);
      expect(provider.isContinuousRestToday, isFalse);
    });

    test('removeRoutineFromContinuousBlock ajusta índice', () {
      provider.settings = provider.settings.copyWith(
        organizationMode: OrganizationMode.continuousList,
        continuousListCurrentIndex: 5,
      );
      provider.addContinuousBlock();
      final blockId = provider.continuousBlocks.first.id;
      provider.addRoutineToContinuousBlock(blockId, 'routine:r1');
      provider.addRoutineToContinuousBlock(blockId, 'routine:r2');

      provider.removeRoutineFromContinuousBlock(blockId, 0);
      // índice 5 % 1 == 0
      expect(provider.settings.continuousListCurrentIndex, 0);
      expect(provider.flatContinuousList, ['routine:r2']);
    });
  });

  group('SettingsState serialização e migração', () {
    test('roundtrip preserva novos campos', () {
      final s = SettingsState(
        sound: false,
        vibration: true,
        prepSeconds: 10,
        organizationMode: OrganizationMode.continuousList,
        continuousListCurrentIndex: 3,
        continuousListRestDate: '2026-11-24',
        workoutReminderEnabled: true,
        workoutReminderHour: 7,
        workoutReminderMinute: 30,
      );

      final restored = SettingsState.fromJson(s.toJson());
      expect(restored.organizationMode, OrganizationMode.continuousList);
      expect(restored.continuousListCurrentIndex, 3);
      expect(restored.continuousListRestDate, '2026-11-24');
      expect(restored.workoutReminderEnabled, isTrue);
      expect(restored.workoutReminderHour, 7);
      expect(restored.workoutReminderMinute, 30);
      expect(restored.sound, isFalse);
    });

    test('JSON antigo sem novos campos usa defaults', () {
      final restored = SettingsState.fromJson({
        'sound': true,
        'vibration': true,
        'prepSeconds': 5,
      });
      expect(restored.continuousListRestDate, '');
      expect(restored.continuousListCurrentIndex, 0);
      expect(restored.workoutReminderEnabled, isFalse);
      expect(restored.workoutReminderHour, 19);
      expect(restored.workoutReminderMinute, 0);
    });

    test('copyWith atualiza e preserva campos', () {
      final s = SettingsState(
          sound: true, vibration: true, prepSeconds: 5,
          workoutReminderEnabled: true, workoutReminderHour: 8);
      final updated = s.copyWith(workoutReminderEnabled: false);
      expect(updated.workoutReminderEnabled, isFalse);
      expect(updated.workoutReminderHour, 8);
    });
  });
}
