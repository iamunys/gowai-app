import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/trip.dart';
import '../../core/services/service_providers.dart';
import '../../core/utils/route_optimizer.dart';
import 'planner_questions.dart';

// ─── State ──────────────────────────────────────────────────────────────────

/// Immutable snapshot of the planner conversation flow.
class PlannerState {
  /// Trimmed destination; empty string means unanswered (step 0).
  final String destination;
  final String? vibe;
  final String? group;
  final String? budget;
  final String? transport;
  final String? startTime;

  /// Steps whose question bubble has finished its typewriter animation.
  final Set<int> typedSteps;

  /// True while the trip is being generated (Claude + Places enrichment).
  final bool generating;

  const PlannerState({
    this.destination = '',
    this.vibe,
    this.group,
    this.budget,
    this.transport,
    this.startTime,
    this.typedSteps = const {},
    this.generating = false,
  });

  /// Index (0-based) of the question currently being asked.
  /// Returns [kPlannerTotalSteps] once every question has been answered.
  int get currentStep {
    if (destination.isEmpty) return 0;
    if (vibe == null) return 1;
    if (group == null) return 2;
    if (budget == null) return 3;
    if (transport == null) return 4;
    if (startTime == null) return 5;
    return kPlannerTotalSteps;
  }

  bool get allAnswered => currentStep >= kPlannerTotalSteps;

  double get progress => currentStep / kPlannerTotalSteps;

  String? answerAt(int step) {
    switch (step) {
      case 0:
        return destination.isEmpty ? null : destination;
      case 1:
        return vibe;
      case 2:
        return group;
      case 3:
        return budget;
      case 4:
        return transport;
      case 5:
        return startTime;
    }
    return null;
  }

  static const _unset = Object();

  PlannerState copyWith({
    String? destination,
    Object? vibe = _unset,
    Object? group = _unset,
    Object? budget = _unset,
    Object? transport = _unset,
    Object? startTime = _unset,
    Set<int>? typedSteps,
    bool? generating,
  }) {
    return PlannerState(
      destination: destination ?? this.destination,
      vibe: identical(vibe, _unset) ? this.vibe : vibe as String?,
      group: identical(group, _unset) ? this.group : group as String?,
      budget: identical(budget, _unset) ? this.budget : budget as String?,
      transport:
          identical(transport, _unset) ? this.transport : transport as String?,
      startTime:
          identical(startTime, _unset) ? this.startTime : startTime as String?,
      typedSteps: typedSteps ?? this.typedSteps,
      generating: generating ?? this.generating,
    );
  }
}

// ─── Generation result ──────────────────────────────────────────────────────

/// Outcome of [PlannerNotifier.generateTrip]. Navigation and snackbars stay
/// in the widget; the notifier only reports what happened.
sealed class GenerateResult {
  const GenerateResult();
}

class GenerateSuccess extends GenerateResult {
  final Trip trip;
  const GenerateSuccess(this.trip);
}

class GenerateLimitReached extends GenerateResult {
  const GenerateLimitReached();
}

class GenerateAuthRequired extends GenerateResult {
  const GenerateAuthRequired();
}

class GenerateFailure extends GenerateResult {
  final Object error;
  const GenerateFailure(this.error);
}

// ─── Notifier ───────────────────────────────────────────────────────────────

/// Owns the planner flow state and orchestrates trip generation.
///
/// autoDispose so the flow resets when the user leaves the planner tab —
/// matching the previous StatefulWidget behavior. Pushing /paywall or
/// /itinerary keeps the planner mounted underneath, so answers survive
/// those, exactly as before.
class PlannerNotifier extends AutoDisposeNotifier<PlannerState> {
  @override
  PlannerState build() => const PlannerState();

  void selectAnswer(int step, String value) {
    switch (step) {
      case 0:
        state = state.copyWith(destination: value.trim());
      case 1:
        state = state.copyWith(vibe: value);
      case 2:
        state = state.copyWith(group: value);
      case 3:
        state = state.copyWith(budget: value);
      case 4:
        state = state.copyWith(transport: value);
      case 5:
        state = state.copyWith(startTime: value);
    }
  }

  /// Resets [step] and every step after it, returning the flow to that
  /// question so the user can pick a different answer.
  void editStep(int step) {
    state = state.copyWith(
      destination: step <= 0 ? '' : null,
      vibe: step <= 1 ? null : state.vibe,
      group: step <= 2 ? null : state.group,
      budget: step <= 3 ? null : state.budget,
      transport: step <= 4 ? null : state.transport,
      startTime: step <= 5 ? null : state.startTime,
      typedSteps: state.typedSteps.where((s) => s <= step).toSet(),
    );
  }

  void markTyped(int step) {
    if (state.typedSteps.contains(step)) return;
    state = state.copyWith(typedSteps: {...state.typedSteps, step});
  }

  void reset() => state = const PlannerState();

  /// Charge one credit, generate via Claude, enrich via Places, and return
  /// the assembled trip. The increment RPC is the atomic check-and-charge —
  /// it must remain the single charge per generation (see module-1 fix).
  Future<GenerateResult> generateTrip() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const GenerateAuthRequired();

    final s = state;
    if (!s.allAnswered) {
      return GenerateFailure(StateError('Planner flow incomplete'));
    }

    // Keep this provider alive while the async work runs, even if the
    // screen is disposed mid-generation (e.g. hardware back press) —
    // otherwise autoDispose would tear the notifier down under us.
    final keepAlive = ref.keepAlive();
    state = s.copyWith(generating: true);
    try {
      final canGenerate =
          await ref.read(supabaseServiceProvider).incrementTripCount(user.id);
      if (!canGenerate) return const GenerateLimitReached();

      final stops = await ref.read(claudeServiceProvider).generateItinerary(
            destination: s.destination,
            date: DateFormat('EEEE, MMMM d').format(DateTime.now()),
            startTime: s.startTime!,
            budget: s.budget!,
            vibe: s.vibe!,
            groupType: s.group!,
            // There is no separate interests question yet; vibe doubles as
            // interests so the prompt sent to Claude stays unchanged. If an
            // interests step is ever added, wire it here.
            interests: s.vibe!,
            transport: s.transport!,
          );

      final enrichedStops = await ref
          .read(placesServiceProvider)
          .enrichStops(stops, destination: s.destination);

      // Reorder stops so the route doesn't zigzag across the destination —
      // the AI's order reflects a plausible day schedule, not geography.
      final orderedStops = optimizeStopOrder(enrichedStops);

      return GenerateSuccess(Trip(
        destination: s.destination,
        tripDate: DateTime.now(),
        vibe: s.vibe!,
        budget: s.budget!,
        groupType: s.group!,
        stops: orderedStops,
      ));
    } catch (e) {
      return GenerateFailure(e);
    } finally {
      state = state.copyWith(generating: false);
      keepAlive.close();
    }
  }
}

final plannerProvider =
    NotifierProvider.autoDispose<PlannerNotifier, PlannerState>(
        PlannerNotifier.new);
