import '../../core/constants/app_strings.dart';
import 'widgets/option_card.dart';

/// One question in the conversational planner flow.
///
/// [options] is null for the destination question (Q1), which uses a text
/// input instead of answer chips.
class PlannerQuestion {
  final String text;
  final List<PlannerOption>? options;

  const PlannerQuestion(this.text, [this.options]);
}

/// The fixed question sequence. Step indices used by PlannerState
/// (0 = destination … 5 = start time) correspond to positions in this list.
const kPlannerQuestions = <PlannerQuestion>[
  PlannerQuestion(AppStrings.whereToGo),
  PlannerQuestion(AppStrings.whatKindOfDay, [
    PlannerOption('🌿', AppStrings.vibeNature, 'Hills, waterfalls, parks'),
    PlannerOption('🍜', AppStrings.vibeFoodCulture, 'Local eats, heritage'),
    PlannerOption('🏛️', AppStrings.vibeSightseeing, 'History, monuments'),
    PlannerOption('✨', AppStrings.vibeMix, 'Surprise me!'),
  ]),
  PlannerQuestion(AppStrings.whoIsJoining, [
    PlannerOption('🧑', AppStrings.groupSolo, 'Just me'),
    PlannerOption('💑', AppStrings.groupPartner, 'Romantic trip'),
    PlannerOption('👫', AppStrings.groupFriends, 'Squad goals'),
    PlannerOption('👨‍👩‍👧', AppStrings.groupFamily, 'With kids'),
  ]),
  PlannerQuestion(AppStrings.whatsYourBudget, [
    PlannerOption('💰', AppStrings.budgetUnder500, 'Super budget'),
    PlannerOption('💳', AppStrings.budget500to1500, 'Moderate'),
    PlannerOption('💎', AppStrings.budget1500to3000, 'Comfortable'),
    PlannerOption('🤑', AppStrings.budgetNoLimit, 'Go all out'),
  ]),
  PlannerQuestion(AppStrings.howWillYouGetAround, [
    PlannerOption('🏍️', AppStrings.transportBike, 'Own vehicle'),
    PlannerOption('🚕', AppStrings.transportCab, 'Book a ride'),
    PlannerOption('🚌', AppStrings.transportPublic, 'Bus, train'),
  ]),
  PlannerQuestion(AppStrings.whenToStart, [
    PlannerOption('🌅', AppStrings.startEarly, 'Start 6–7 AM'),
    PlannerOption('☀️', AppStrings.startMorning, 'Start 9–10 AM'),
    PlannerOption('🕐', AppStrings.startFlexible, 'No fixed time'),
  ]),
];

final kPlannerTotalSteps = kPlannerQuestions.length;
