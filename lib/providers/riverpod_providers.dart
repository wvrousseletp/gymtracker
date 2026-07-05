import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_provider.dart';
import 'workout_provider.dart';
import 'diet_provider.dart';
import 'tracker_provider.dart';

final profileRiverpodProvider = ChangeNotifierProvider<ProfileProvider>((ref) {
  return ProfileProvider();
});

final workoutRiverpodProvider = ChangeNotifierProvider<WorkoutProvider>((ref) {
  final workout = WorkoutProvider();
  final profile = ref.watch(profileRiverpodProvider);
  workout.updateProfile(profile);
  return workout;
});

final dietRiverpodProvider = ChangeNotifierProvider<DietProvider>((ref) {
  final diet = DietProvider();
  final profile = ref.watch(profileRiverpodProvider);
  diet.updateProfile(profile);
  return diet;
});

final trackerRiverpodProvider = ChangeNotifierProvider<TrackerProvider>((ref) {
  final tracker = TrackerProvider();
  final profile = ref.watch(profileRiverpodProvider);
  final workout = ref.watch(workoutRiverpodProvider);
  final diet = ref.watch(dietRiverpodProvider);
  tracker.update(profile, workout, diet);
  return tracker;
});
