import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/onboarding/onboarding_storage.dart';
import 'package:komodo_go/core/providers/shared_preferences_provider.dart';

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(onboardingSeenKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(onboardingSeenKey, true);
    state = const AsyncValue.data(true);
  }
}
