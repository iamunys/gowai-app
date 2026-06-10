import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/trip.dart';
import '../../core/services/claude_service.dart';
import '../../core/services/places_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_handler.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../../shared/widgets/primary_button.dart';
import 'widgets/answer_chip.dart';
import 'widgets/generating_animation.dart';
import 'widgets/question_card.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final _destinationCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _service = SupabaseService();
  final _claudeService = ClaudeService();
  final _placesService = PlacesService();

  String? _vibe;
  String? _group;
  String? _budget;
  String? _transport;
  String? _startTime;
  bool _generating = false;

  bool get _allAnswered =>
      _destinationCtrl.text.isNotEmpty &&
      _vibe != null &&
      _group != null &&
      _budget != null &&
      _transport != null &&
      _startTime != null;

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    final canGenerate = await _service.canGenerateTrip(user.id);
    if (!canGenerate) {
      if (mounted) context.push('/paywall');
      return;
    }

    setState(() => _generating = true);
    try {
      final stops = await _claudeService.generateItinerary(
        destination: _destinationCtrl.text.trim(),
        date: DateFormat('EEEE, MMMM d').format(DateTime.now()),
        startTime: _startTime!,
        budget: _budget!,
        vibe: _vibe!,
        groupType: _group!,
        interests: _vibe!,
        transport: _transport!,
      );

      final enrichedStops = await _placesService.enrichStops(stops);

      await _service.incrementTripCount(user.id);

      final trip = Trip(
        destination: _destinationCtrl.text.trim(),
        tripDate: DateTime.now(),
        vibe: _vibe!,
        budget: _budget!,
        groupType: _group!,
        stops: enrichedStops,
      );

      if (mounted) context.push('/itinerary', extra: trip);
    } catch (e) {
      if (mounted) {
        ErrorSnackbar.show(context, ErrorHandler.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Stack(
        children: [
          _buildScaffold(context),
          if (_generating) const Positioned.fill(child: GeneratingAnimation()),
        ],
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'gowai',
                style: GoogleFonts.sora(
                    fontWeight: FontWeight.w800,
                    fontSize: 40,
                    color: AppColors.primary),
              ),
              // const SizedBox(width: 5),
              // SvgPicture.asset(
              //   'assets/images/gowai_logo.svg',
              //   width: 40,
              //   height: 40,
              //   colorFilter: const ColorFilter.mode(
              //     AppColors.primary,
              //     BlendMode.srcIn,
              //   ),
              // ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _destinationCtrl.clear();
                  _vibe = null;
                  _group = null;
                  _budget = null;
                  _transport = null;
                  _startTime = null;
                });
              },
              tooltip: 'Reset',
            ),
          ],
        ),
        body: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Q1: Destination
            QuestionCard(
              question: AppStrings.whereToGo,
              stepNumber: 1,
              totalSteps: 6,
              child: TextField(
                controller: _destinationCtrl,
                decoration: InputDecoration(
                  hintText: AppStrings.enterDestination,
                  prefixIcon: const Icon(Icons.location_on_outlined,
                      color: AppColors.primary),
                  suffixIcon: _destinationCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _destinationCtrl.clear());
                          },
                        )
                      : null,
                ),
                onChanged: (_) {
                  setState(() {});
                  _scrollToBottom();
                },
              ),
            ),
            if (_destinationCtrl.text.isEmpty)
              SizedBox(
                height: 500,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/illu_trav.svg',
                      width: 200,
                      height: 200,
                    ),
                  ],
                ),
              ),

            // Q2: Vibe
            if (_destinationCtrl.text.isNotEmpty)
              QuestionCard(
                question: AppStrings.whatKindOfDay,
                stepNumber: 2,
                totalSteps: 6,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    (AppStrings.vibeNature, '🌿'),
                    (AppStrings.vibeFoodCulture, '🍜'),
                    (AppStrings.vibeSightseeing, '🏛️'),
                    (AppStrings.vibeMix, '✨'),
                  ].map((item) {
                    return AnswerChip(
                      label: item.$1,
                      emoji: item.$2,
                      selected: _vibe == item.$1,
                      onTap: () {
                        setState(() => _vibe = item.$1);
                        _scrollToBottom();
                      },
                    );
                  }).toList(),
                ),
              ),

            // Q3: Group
            if (_vibe != null)
              QuestionCard(
                question: AppStrings.whoIsJoining,
                stepNumber: 3,
                totalSteps: 6,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    (AppStrings.groupSolo, '🧍'),
                    (AppStrings.groupFriends, '👫'),
                    (AppStrings.groupFamily, '👨‍👩‍👧'),
                    (AppStrings.groupPartner, '💑'),
                  ].map((item) {
                    return AnswerChip(
                      label: item.$1,
                      emoji: item.$2,
                      selected: _group == item.$1,
                      onTap: () {
                        setState(() => _group = item.$1);
                        _scrollToBottom();
                      },
                    );
                  }).toList(),
                ),
              ),

            // Q4: Budget
            if (_group != null)
              QuestionCard(
                question: AppStrings.whatsYourBudget,
                stepNumber: 4,
                totalSteps: 6,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    (AppStrings.budgetUnder500, '💰'),
                    (AppStrings.budget500to1500, '💳'),
                    (AppStrings.budget1500to3000, '💎'),
                    (AppStrings.budgetNoLimit, '🤑'),
                  ].map((item) {
                    return AnswerChip(
                      label: item.$1,
                      emoji: item.$2,
                      selected: _budget == item.$1,
                      onTap: () {
                        setState(() => _budget = item.$1);
                        _scrollToBottom();
                      },
                    );
                  }).toList(),
                ),
              ),

            // Q5: Transport
            if (_budget != null)
              QuestionCard(
                question: AppStrings.howWillYouGetAround,
                stepNumber: 5,
                totalSteps: 6,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    (AppStrings.transportBike, '🏍️'),
                    (AppStrings.transportCab, '🚕'),
                    (AppStrings.transportPublic, '🚌'),
                  ].map((item) {
                    return AnswerChip(
                      label: item.$1,
                      emoji: item.$2,
                      selected: _transport == item.$1,
                      onTap: () {
                        setState(() => _transport = item.$1);
                        _scrollToBottom();
                      },
                    );
                  }).toList(),
                ),
              ),

            // Q6: Start time
            if (_transport != null)
              QuestionCard(
                question: AppStrings.whenToStart,
                stepNumber: 6,
                totalSteps: 6,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    (AppStrings.startEarly, '🌅'),
                    (AppStrings.startMorning, '☀️'),
                    (AppStrings.startFlexible, '🕐'),
                  ].map((item) {
                    return AnswerChip(
                      label: item.$1,
                      emoji: item.$2,
                      selected: _startTime == item.$1,
                      onTap: () {
                        setState(() => _startTime = item.$1);
                        _scrollToBottom();
                      },
                    );
                  }).toList(),
                ),
              ),

            // Generate button
            if (_allAnswered)
              Padding(
                padding: const EdgeInsets.all(20),
                child: PrimaryButton(
                  label: AppStrings.generateTrip,
                  onPressed: _generate,
                )
                    .animate()
                    .scale(duration: 300.ms, curve: Curves.elasticOut)
                    .fadeIn(),
              ),

            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      ),
    );
  }
}
