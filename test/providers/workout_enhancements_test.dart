import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker_flutter/models/diet.dart';
import 'package:gym_tracker_flutter/models/exercise.dart';
import 'package:gym_tracker_flutter/models/planner_state.dart';
import 'package:gym_tracker_flutter/models/routine.dart';
import 'package:gym_tracker_flutter/models/workout_log.dart';
import 'package:gym_tracker_flutter/providers/workout_provider.dart';
import 'package:gym_tracker_flutter/services/badges_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('com.vicente.losmooscles/watch');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  group('Per-set tonnage, warm-ups, failure reps & PR detection', () {
    test('exclui séries de aquecimento (W) da tonelagem, usa failureReps e detecta PR na série 2', () {
      final provider = WorkoutProvider();
      provider.library = [
        LibraryExercise(
          id: 'supino',
          name: 'Supino Reto',
          muscle: 'Peito',
          measurementType: MeasurementType.reps,
        ),
      ];

      final routine = Routine(
        id: 'r-supino',
        name: 'Peito A',
        defaultRest: 60,
        exercises: [
          RoutineExercise(
            id: 're-1',
            exerciseId: 'supino',
            sets: 3,
            reps: 10,
            rest: 60,
            weight: 60,
            weightsPerSet: [40.0, 80.0, 85.0],
            repsPerSet: [12, 8, 6],
            setTypes: ['W', 'N', 'N'],
          ),
        ],
      );
      provider.routines = [routine];

      provider.startWorkout(
        routine,
        WorkoutRecovery(sleepOk: SleepQuality.good, pain: [], warmUpDone: true),
        false,
      );

      // Série 0: Aquecimento (40x12) -> não deve contar na tonelagem
      provider.completeSet(0, 0, true);
      // Série 1: Trabalho (80x8 = 640kg)
      provider.completeSet(0, 1, true);
      // Série 2: Trabalho com falha em 4 reps (85x4 = 340kg)
      provider.completeSet(0, 2, true, isFailure: true, failureRep: 4);

      provider.finishWorkout(1800, 8, '');

      expect(provider.history.length, 1);
      final log = provider.history.first;
      // Tonelagem esperada: 640 + 340 = 980 (sem os 480 do aquecimento)
      expect(log.totalWeight, closeTo(980.0, 0.01));
      // PR deve detectar a série mais pesada concluída (85kg x 4)
      expect(provider.prs['supino']?.weight, 85.0);
      expect(provider.prs['supino']?.reps, 4);
    });
  });

  group('Bi-set / Superset auto-flow & descanso adaptativo', () {
    test('auto-avança entre exercícios do mesmo supersetId e aplica descanso adaptativo', () {
      final provider = WorkoutProvider();
      provider.library = [
        LibraryExercise(
            id: 'e1',
            name: 'Rosca Direta',
            muscle: 'Bíceps',
            measurementType: MeasurementType.reps),
        LibraryExercise(
            id: 'e2',
            name: 'Tríceps Testa',
            muscle: 'Tríceps',
            measurementType: MeasurementType.reps),
      ];

      final routine = Routine(
        id: 'r-biset',
        name: 'Braços',
        defaultRest: 60,
        exercises: [
          RoutineExercise(
            id: 're-a',
            exerciseId: 'e1',
            sets: 2,
            reps: 10,
            rest: 60,
            weight: 30,
            setTypes: ['W', 'N'],
            supersetId: 'sup-1',
          ),
          RoutineExercise(
            id: 're-b',
            exerciseId: 'e2',
            sets: 2,
            reps: 10,
            rest: 60,
            weight: 25,
            setTypes: ['N', 'N'],
            supersetId: 'sup-1',
          ),
        ],
      );

      provider.startWorkout(
        routine,
        WorkoutRecovery(sleepOk: SleepQuality.okay, pain: [], warmUpDone: false),
        false,
      );

      // Completa Série 1 de A: deve pular descanso e ir direto para B
      provider.completeSet(0, 0, true);
      expect(provider.activeWorkout!.currentExerciseIndex, 1);
      expect(provider.activeWorkout!.restTimer, isNull);

      // Completa Série 1 de B com falha: deve iniciar descanso (+30s = 90s) apontando para A Série 2
      provider.completeSet(1, 0, true, isFailure: true, failureRep: 8);
      expect(provider.activeWorkout!.currentExerciseIndex, 0);
      expect(provider.activeWorkout!.restTimer, isNotNull);
      expect(provider.activeWorkout!.restTimer!.totalSeconds, 90);
      expect(provider.activeWorkout!.restTimer!.nextExerciseName, 'Rosca Direta');
      expect(provider.activeWorkout!.restTimer!.nextSetNum, 2);

      // Descanso adaptativo para aquecimento 'W' = 50% (30s)
      final adaptiveWarmup = provider.computeAdaptiveRestSeconds(
        provider.activeWorkout!.exercises[0],
        0,
        isFailure: false,
      );
      expect(adaptiveWarmup, 30);
    });
  });

  group('Rest day isolation & Cardio Master badge', () {
    test('Descanso registrado com motivo é reconhecido como isRestDayLog e não infla streak/relatórios/badges', () {
      final provider = WorkoutProvider();
      provider.planner['seg'] = ['routine:r1'];
      provider.shiftPlannerForward('Viagem a trabalho');

      expect(provider.history.length, 1);
      final restLog = provider.history.first;
      expect(restLog.name, 'Descanso: Viagem a trabalho');
      expect(restLog.isRestDayLog, isTrue);

      expect(provider.streak.currentWeekCount, 0);
      expect(provider.getWeeklyReportData().workoutsThisWeek, 0);
      expect(provider.getMonthlyChallenges().first.current, 0);

      final badges = BadgesService.evaluateNewBadges(
        history: provider.history,
        currentUnlocked: const [],
        streak: provider.streak,
        library: provider.library,
      );
      expect(badges, isNot(contains('first_workout')));
    });

    test('cardio_master desbloqueia apenas ao atingir 60 minutos de cardio', () {
      final lib = [
        LibraryExercise(
          id: 'run',
          name: 'Corrida',
          muscle: 'Cardio',
          measurementType: MeasurementType.cardio,
        ),
      ];
      final shortCardio = WorkoutLog(
        id: 'c1',
        name: 'Cardio 20m',
        date: DateTime.now().toUtc().toIso8601String(),
        duration: 1200,
        completedSets: 1,
        totalSets: 1,
        totalWeight: 0,
        rpe: 6,
        notes: '',
        exercises: [
          LogExercise(
            name: 'Corrida',
            muscle: 'Cardio',
            sets: 1,
            completedSets: 1,
            reps: 20,
            weight: 3.0,
            rpe: 6,
            performedCardios: [
              PerformedCardio(distanceKm: 3.0, durationSeconds: 1200),
            ],
          ),
        ],
      );
      final longCardio = WorkoutLog(
        id: 'c2',
        name: 'Cardio 45m',
        date: DateTime.now().toUtc().toIso8601String(),
        duration: 2700,
        completedSets: 1,
        totalSets: 1,
        totalWeight: 0,
        rpe: 7,
        notes: '',
        exercises: [
          LogExercise(
            name: 'Corrida',
            muscle: 'Cardio',
            sets: 1,
            completedSets: 1,
            reps: 45,
            weight: 7.0,
            rpe: 7,
            performedCardios: [
              PerformedCardio(distanceKm: 7.0, durationSeconds: 2700),
            ],
          ),
        ],
      );

      final streak = WorkoutStreak(
        currentWeekCount: 1,
        consecutiveWeeks: 1,
        lastWorkoutDate: shortCardio.date,
        weekdaysTrained: [1],
      );

      final unlocked20 = BadgesService.evaluateNewBadges(
        history: [shortCardio],
        currentUnlocked: const [],
        streak: streak,
        library: lib,
      );
      expect(unlocked20, isNot(contains('cardio_master')));

      final unlocked65 = BadgesService.evaluateNewBadges(
        history: [shortCardio, longCardio],
        currentUnlocked: const [],
        streak: streak,
        library: lib,
      );
      expect(unlocked65, contains('cardio_master'));
    });
  });

  group('Routine progression batch update', () {
    test('detecta exercícios modificados e atualiza a rotina base em lote', () {
      final provider = WorkoutProvider();
      provider.library = [
        LibraryExercise(
            id: 'agach',
            name: 'Agachamento',
            muscle: 'Pernas',
            measurementType: MeasurementType.reps),
      ];
      final routine = Routine(
        id: 'r-legs',
        name: 'Pernas',
        defaultRest: 90,
        exercises: [
          RoutineExercise(
            id: 're-agach',
            exerciseId: 'agach',
            sets: 3,
            reps: 10,
            rest: 90,
            weight: 100,
          ),
        ],
      );
      provider.routines = [routine];
      provider.startWorkout(
        routine,
        WorkoutRecovery(sleepOk: SleepQuality.good, pain: [], warmUpDone: true),
        false,
      );

      expect(provider.getModifiedRoutineExerciseIndices(), isEmpty);

      provider.updateExerciseWeightReps(0, 110, 8);
      expect(provider.getModifiedRoutineExerciseIndices(), [0]);

      provider.applyAllModifiedExercisesToRoutine();
      expect(provider.routines.first.exercises.first.weight, 110);
      expect(provider.routines.first.exercises.first.reps, 8);
    });
  });

  group('Active planning mode consistency', () {
    test('computePlannedVolume considera apenas o modo selecionado (Dias Fixos vs Contínuo)', () {
      final lib = [
        LibraryExercise(
            id: 'supino',
            name: 'Supino',
            muscle: 'Peito',
            measurementType: MeasurementType.reps),
        LibraryExercise(
            id: 'agach',
            name: 'Agachamento',
            muscle: 'Pernas',
            measurementType: MeasurementType.reps),
        LibraryExercise(
            id: 'corrida',
            name: 'Corrida',
            muscle: 'Cardio',
            measurementType: MeasurementType.cardio),
      ];
      final routines = [
        Routine(
          id: 'r-peito',
          name: 'Peito',
          defaultRest: 60,
          exercises: [
            RoutineExercise(
              id: 're1',
              exerciseId: 'supino',
              sets: 4,
              reps: 10,
              rest: 60,
              weight: 60,
            ),
          ],
        ),
        Routine(
          id: 'r-perna',
          name: 'Pernas',
          defaultRest: 90,
          exercises: [
            RoutineExercise(
              id: 're2',
              exerciseId: 'agach',
              sets: 5,
              reps: 10,
              rest: 90,
              weight: 100,
            ),
          ],
        ),
      ];
      final baseDiet = DietState(
        caloriesGoal: 2000,
        proteinGoal: 150,
        carbsGoal: 200,
        fatGoal: 70,
        waterGoalMl: 2000,
        meals: const [],
        waterIntakeMl: 0,
        fasting: FastingState(history: const []),
        abstinence: const [],
      );

      final fixedState = PlannerState(
        library: lib,
        routines: routines,
        planner: const {'seg': ['routine:r-peito', 'exercise:corrida:25']},
        continuousBlocks: [
          WorkoutBlock(id: 'b1', name: 'Bloco', routineIds: ['routine:r-perna', 'exercise:corrida:40']),
        ],
        history: const [],
        prs: const {},
        exerciseNotes: const {},
        medidas: const [],
        settings: SettingsState(
          sound: true,
          vibration: true,
          prepSeconds: 5,
          organizationMode: OrganizationMode.fixedDays,
        ),
        diet: baseDiet,
        dietHistory: const {},
      );

      final fixedVol = WorkoutProvider.computePlannedVolume(fixedState);
      expect(fixedVol.strengthByMuscle['Peito'], 4);
      expect(fixedVol.strengthByMuscle['Pernas'], isNull);
      expect(fixedVol.totalCardioMinutes, 25);

      final continuousState = fixedState.copyWith(
        settings: fixedState.settings.copyWith(
          organizationMode: OrganizationMode.continuousList,
        ),
      );

      final contVol = WorkoutProvider.computePlannedVolume(continuousState);
      expect(contVol.strengthByMuscle['Pernas'], 5);
      expect(contVol.strengthByMuscle['Peito'], isNull);
      expect(contVol.totalCardioMinutes, 40);
    });

    test('shiftPlannerForward no modo Contínuo marca descanso hoje sem alterar planner semanal e undo restaura', () {
      final provider = WorkoutProvider();
      provider.planner = {
        'seg': ['routine:r1'],
        'ter': ['routine:r2'],
      };
      provider.settings = provider.settings.copyWith(
        organizationMode: OrganizationMode.continuousList,
        themeMode: 'dark',
      );

      provider.shiftPlannerForward('Recuperação Muscular');

      expect(provider.isContinuousRestToday, isTrue);
      expect(provider.planner['seg'], ['routine:r1']);
      expect(provider.planner['ter'], ['routine:r2']);
      expect(provider.history.length, 1);
      expect(provider.history.first.isRestDayLog, isTrue);
      expect(provider.settings.themeMode, 'dark');

      provider.undoShiftPlannerForward();

      expect(provider.isContinuousRestToday, isFalse);
      expect(provider.history, isEmpty);
      expect(provider.settings.themeMode, 'dark');
    });
  });
}
