import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/exercise.dart';
import 'package:gym_tracker_flutter/models/planner_state.dart';
import 'package:gym_tracker_flutter/models/routine.dart';
import 'package:gym_tracker_flutter/models/workout_log.dart';
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

  group('Week templates', () {
    late WorkoutProvider provider;

    setUp(() {
      provider = WorkoutProvider();
    });

    test('saveCurrentWeekAsTemplate captura dias com itens e apply restaura', () {
      provider.planner['seg'] = ['routine:r1', 'exercise:e1:3'];
      provider.planner['qua'] = ['routine:r2'];
      // ter/qui/... vazios não entram no modelo

      provider.saveCurrentWeekAsTemplate('Semana A');
      expect(provider.weekTemplates, hasLength(1));
      final t = provider.weekTemplates.values.first;
      expect(t.name, 'Semana A');
      expect(t.days['seg'], ['routine:r1', 'exercise:e1:3']);
      expect(t.days.containsKey('ter'), isFalse);

      // Altera a semana e reaplica
      provider.planner['seg'] = ['routine:outro'];
      provider.planner['sex'] = ['routine:r9'];
      provider.applyWeekTemplate(t.id);
      expect(provider.planner['seg'], ['routine:r1', 'exercise:e1:3']);
      expect(provider.planner['qua'], ['routine:r2']);
      expect(provider.planner['sex'], isEmpty);
    });

    test('deleteWeekTemplate remove o modelo', () {
      provider.planner['seg'] = ['routine:r1'];
      provider.saveCurrentWeekAsTemplate('Temp');
      final id = provider.weekTemplates.keys.first;
      provider.deleteWeekTemplate(id);
      expect(provider.weekTemplates, isEmpty);
    });
  });

  group('movePlannerItem (drag & drop)', () {
    test('move de posição arbitrária funciona como ReorderableListView', () {
      final provider = WorkoutProvider();
      provider.planner['seg'] = ['a', 'b', 'c', 'd'];
      // onReorder(0, 3): newIndex ajustado para 2 → ['b','c','a','d']
      provider.movePlannerItem('seg', 0, 3);
      expect(provider.planner['seg'], ['b', 'c', 'a', 'd']);
      // onReorder(3, 1): sem ajuste → remove 'd' e insere no índice 1
      provider.movePlannerItem('seg', 3, 1);
      expect(provider.planner['seg'], ['b', 'd', 'c', 'a']);
    });
  });

  group('Engagement (relatório e desafios)', () {
    late WorkoutProvider provider;

    setUp(() {
      provider = WorkoutProvider();
    });

    WorkoutLog logAt(DateTime date, {double weight = 1000, int duration = 3600}) {
      return WorkoutLog(
        id: 'log-${date.millisecondsSinceEpoch}',
        name: 'Treino',
        date: date.toUtc().toIso8601String(),
        duration: duration,
        completedSets: 10,
        totalSets: 10,
        totalWeight: weight,
        rpe: 8,
        notes: '',
        exercises: const [],
      );
    }

    test('getWeeklyReportData separa semana atual da anterior', () {
      final now = DateTime.now();
      provider.history = [
        logAt(now.subtract(const Duration(days: 2)), weight: 2000),
        logAt(now.subtract(const Duration(days: 10)), weight: 1000),
      ];
      final report = provider.getWeeklyReportData();
      expect(report.workoutsThisWeek, 1);
      expect(report.workoutsLastWeek, 1);
      expect(report.volumeThisWeek, 2000);
      expect(report.volumeLastWeek, 1000);
      expect(report.volumeDeltaPercent, 100);
    });

    test('getMonthlyChallenges filtra apenas o mês corrente', () {
      final now = DateTime.now();
      provider.history = [
        logAt(now, weight: 5000, duration: 7200), // 2h = 120min
        logAt(DateTime(now.year, now.month - 1, 15), weight: 99999), // mês passado
      ];
      final challenges = provider.getMonthlyChallenges();
      expect(challenges, hasLength(3));
      expect(challenges[0].current, 1); // 1 treino no mês
      expect(challenges[1].current, 5000); // só o volume do mês atual
      expect(challenges[2].current, 120); // 120 min
      expect(challenges[0].progress, 1 / 16);
    });
  });

  group('Offline watch workout sync', () {
    late WorkoutProvider provider;

    setUp(() {
      provider = WorkoutProvider();
    });

    Map<String, dynamic> watchWorkoutJson() {
      final start =
          DateTime.now().millisecondsSinceEpoch - 1800000; // 30 min atrás
      final active = ActiveWorkoutState(
        name: 'Treino Watch Offline',
        startTime: start,
        exercises: [
          ActiveExercise(
            id: 'ex-1',
            name: 'Supino',
            muscle: 'Peito',
            measurementType: MeasurementType.reps,
            sets: 3,
            reps: 10,
            rest: 60,
            weight: 40,
            setsState: [true, true, false],
            performedCardios: [null, null, null],
            failureReport: [false, false, false],
          ),
        ],
        currentExerciseIndex: 0,
        elapsedSeconds: 1800,
        recovery: WorkoutRecovery(
            sleepOk: SleepQuality.okay, pain: [], warmUpDone: true),
        isWarmup: false,
        warmupDurationSeconds: 0,
      );
      return active.toJson();
    }

    test('converte payload do Watch em WorkoutLog com métricas corretas', () {
      provider.addOfflineWatchWorkout(watchWorkoutJson(), 'watch-q-1');

      expect(provider.history, hasLength(1));
      final log = provider.history.first;
      expect(log.id, 'watch-q-1');
      expect(log.name, 'Treino Watch Offline');
      expect(log.duration, 1800);
      expect(log.completedSets, 2);
      expect(log.totalSets, 3);
      expect(log.totalWeight, 800); // 40kg * 10 reps * 2 séries
      expect(log.exercises.single.name, 'Supino');
      expect(log.exercises.single.completedSets, 2);
    });

    test('deduplica por workoutId e usa data de início do treino', () {
      final json = watchWorkoutJson();
      provider.addOfflineWatchWorkout(json, 'watch-q-2');
      provider.addOfflineWatchWorkout(json, 'watch-q-2');

      expect(provider.history, hasLength(1));
      final logDate = DateTime.parse(provider.history.first.date);
      // Data deve ser ~30min atrás (startTime), não "agora"
      final diff = DateTime.now().difference(logDate).inMinutes;
      expect(diff, greaterThan(20));
      expect(diff, lessThan(40));
    });
  });

  group('Histórico vs configuração do planejamento', () {
    late WorkoutProvider provider;

    WorkoutRecovery recovery() => WorkoutRecovery(
        sleepOk: SleepQuality.okay, pain: [], warmUpDone: false);

    WorkoutLog supinoLog() => WorkoutLog(
          id: 'log-1',
          name: 'Treino A',
          date: DateTime.now().toIso8601String(),
          duration: 3600,
          completedSets: 3,
          totalSets: 3,
          totalWeight: 1200,
          rpe: 8,
          notes: '',
          exercises: [
            LogExercise(
              name: 'Supino',
              muscle: 'Peito',
              sets: 3,
              completedSets: 3,
              reps: 8,
              weight: 50,
              rpe: 8,
            ),
          ],
        );

    Routine supinoRoutine({int reps = 15, double weight = 0}) => Routine(
          id: 'r1',
          name: 'Treino A',
          defaultRest: 60,
          exercises: [
            RoutineExercise(
              id: 're1',
              exerciseId: 'ex1',
              sets: 4,
              reps: reps,
              rest: 60,
              weight: weight,
            ),
          ],
        );

    setUp(() {
      provider = WorkoutProvider();
      provider.library = [
        LibraryExercise(
          id: 'ex1',
          name: 'Supino',
          muscle: 'Peito',
          measurementType: MeasurementType.reps,
        ),
      ];
      provider.history = [supinoLog()];
    });

    test('não sobrescreve reps configurados quando peso é 0', () {
      provider.startWorkout(supinoRoutine(reps: 15), recovery(), false);

      final ex = provider.activeWorkout!.exercises.single;
      expect(ex.weight, 50); // peso sugerido do histórico
      expect(ex.reps, 15); // reps configurados preservados
    });

    test('reps padrão (10) recebe sugestão do histórico', () {
      provider.startWorkout(supinoRoutine(reps: 10), recovery(), false);

      final ex = provider.activeWorkout!.exercises.single;
      expect(ex.weight, 50);
      expect(ex.reps, 8);
    });

    test('peso configurado não é sobrescrito pelo histórico', () {
      provider.startWorkout(supinoRoutine(reps: 12, weight: 30), recovery(),
          false);

      final ex = provider.activeWorkout!.exercises.single;
      expect(ex.weight, 30);
      expect(ex.reps, 12);
    });
  });

  group('Aplicar edição do treino à rotina', () {
    late WorkoutProvider provider;

    WorkoutRecovery recovery() => WorkoutRecovery(
        sleepOk: SleepQuality.okay, pain: [], warmUpDone: false);

    setUp(() {
      provider = WorkoutProvider();
      provider.routines = [_routine('r1', 'Treino A')];
    });

    test('applyActiveExerciseToRoutine grava peso/reps na rotina', () {
      provider.startWorkout(provider.routines.first, recovery(), false);
      provider.updateExerciseWeightReps(0, 32.5, 12);

      final ok = provider.applyActiveExerciseToRoutine(0);

      expect(ok, isTrue);
      final re = provider.routines.first.exercises.single;
      expect(re.weight, 32.5);
      expect(re.reps, 12);
    });

    test('retorna false para exercício sem rotina de origem', () {
      final temp = Routine(
        id: 'temp-1',
        name: 'Supino (Avulso)',
        defaultRest: 60,
        isDynamicExercise: true,
        exercises: [
          RoutineExercise(
            id: 'e-temp-1',
            exerciseId: 'ex-x',
            sets: 3,
            reps: 10,
            rest: 60,
            weight: 0,
          ),
        ],
      );
      provider.startWorkout(temp, recovery(), false);

      expect(provider.applyActiveExerciseToRoutine(0), isFalse);
    });
  });
}
