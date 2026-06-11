import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/update_service.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/update_widgets.dart';
import 'planner_provider.dart';
import 'planner_questions.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/destination_input.dart';
import 'widgets/generate_button.dart';
import 'widgets/generating_animation.dart';
import 'widgets/option_card.dart';

/// Conversational trip planner.
///
/// All flow state (answers, current step, generating flag) lives in
/// [plannerProvider]; this widget owns only UI concerns — text/scroll
/// controllers, the update banner, navigation, and snackbars.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final _destinationCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ── Update state (screen-local UI concern) ──────────────────────────────
  UpdateResult? _updateResult;
  bool _showMinorBanner = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateService.checkForUpdate();
    if (result == null || !mounted) return;

    if (result.type == UpdateType.minor) {
      // Only show the minor banner if the user hasn't dismissed it recently.
      final shouldShow = await UpdateService.shouldShowMinorBanner();
      if (!shouldShow || !mounted) return;
    }

    setState(() {
      _updateResult = result;
      _showMinorBanner = result.type == UpdateType.minor;
    });
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Flow actions (delegate to the notifier, then handle UI effects) ─────

  void _selectAnswer(int step, String value) {
    ref.read(plannerProvider.notifier).selectAnswer(step, value);
    _scrollToBottom();
  }

  void _editStep(int step) {
    HapticFeedback.lightImpact();
    if (step <= 0) _destinationCtrl.clear();
    ref.read(plannerProvider.notifier).editStep(step);
    _scrollToBottom();
  }

  void _reset() {
    _destinationCtrl.clear();
    ref.read(plannerProvider.notifier).reset();
  }

  Future<void> _generate() async {
    final result = await ref.read(plannerProvider.notifier).generateTrip();
    if (!mounted) return;
    switch (result) {
      case GenerateAuthRequired():
        context.go('/login');
      case GenerateLimitReached():
        context.push('/paywall');
      case GenerateSuccess(:final trip):
        context.push('/itinerary', extra: trip);
      case GenerateFailure(:final error):
        ErrorSnackbar.show(context, ErrorHandler.getMessage(error));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final planner = ref.watch(plannerProvider);
    final isMajorUpdate = _updateResult?.type == UpdateType.major;
    return PopScope(
      // Block the hardware back button when a major update is pending.
      canPop: !isMajorUpdate,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Stack(
          children: [
            _buildScaffold(context, planner),
            if (planner.generating)
              Positioned.fill(
                child: GeneratingAnimation(destination: planner.destination),
              ),
            // Major update: full-screen blocking overlay.
            if (isMajorUpdate)
              Positioned.fill(
                child: MajorUpdateDialog(newVersion: _updateResult!.newVersion),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, PlannerState planner) {
    final step = planner.currentStep;
    final visibleSteps =
        step >= kPlannerTotalSteps ? kPlannerTotalSteps : step + 1;
    final displayStep = (step >= kPlannerTotalSteps ? kPlannerTotalSteps : step + 1)
        .clamp(1, kPlannerTotalSteps);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: false,
          leading: step == 0 && context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  onPressed: () => context.pop(),
                )
              : null,
          title: Text(
            'Gowai',
            style: GoogleFonts.sora(
              fontWeight: FontWeight.bold,
              fontSize: 40,
              color: AppColors.primary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$displayStep of $kPlannerTotalSteps',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Minor update banner slides in at the top when available.
            if (_showMinorBanner && _updateResult?.type == UpdateType.minor)
              MinorUpdateBanner(
                newVersion: _updateResult!.newVersion,
                onDismiss: () => setState(() => _showMinorBanner = false),
              ),
            ClipRRect(
              child: TweenAnimationBuilder<double>(
                // TweenAnimationBuilder re-targets automatically: when `end`
                // changes it animates from the current value, so no manual
                // last-progress bookkeeping (the old `_lastProgress` field
                // mutated state inside build()).
                tween: Tween<double>(begin: 0, end: planner.progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: AppColors.primaryTrack,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 3,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: visibleSteps,
                itemBuilder: (context, i) {
                  final isCurrent = i == step;
                  final answer = planner.answerAt(i);
                  final opacity = isCurrent ? 1.0 : 0.7;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BotQuestionBubble(
                        question: kPlannerQuestions[i].text,
                        animateText:
                            isCurrent && !planner.typedSteps.contains(i),
                        opacity: opacity,
                        onTypingComplete: () {
                          if (!mounted) return;
                          ref.read(plannerProvider.notifier).markTyped(i);
                          _scrollToBottom();
                        },
                      ),
                      if (answer != null)
                        UserAnswerBubble(
                          answer: answer,
                          opacity: opacity,
                          onTap: () => _editStep(i),
                        ),
                    ],
                  );
                },
              ),
            ),
            _buildBottomArea(planner),
          ],
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      ),
    );
  }

  Widget _buildBottomArea(PlannerState planner) {
    final step = planner.currentStep;
    final ready =
        step >= kPlannerTotalSteps || planner.typedSteps.contains(step);

    Widget content;
    if (!ready) {
      content = const SizedBox.shrink();
    } else if (step == 0) {
      content = DestinationInput(
        controller: _destinationCtrl,
        onSubmitted: (value) => _selectAnswer(0, value),
      );
    } else if (step < kPlannerTotalSteps) {
      content = OptionGrid(
        options: kPlannerQuestions[step].options!,
        selected: planner.answerAt(step),
        onSelected: (value) => _selectAnswer(step, value),
      );
    } else {
      content = GenerateTripButton(onPressed: _generate);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(key: ValueKey(ready ? step : -1), child: content),
        ),
      ),
    );
  }
}
