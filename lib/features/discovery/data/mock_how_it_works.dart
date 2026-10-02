import 'package:flutter/material.dart';
import '../domain/how_it_works_step.dart';

const List<HowItWorksStep> howItWorksSteps = [
  HowItWorksStep(
    icon: Icons.edit_note,
    title: 'Post an activity',
    description: 'Set category, location, time, and how many people you need.',
  ),
  HowItWorksStep(
    icon: Icons.travel_explore,
    title: 'Get discovered nearby',
    description:
        'People nearby see your activity by category, distance, and time.',
  ),
  HowItWorksStep(
    icon: Icons.verified_user_outlined,
    title: 'Screen who joins',
    description:
        'Review verification badges, ratings, and history before accepting anyone.',
  ),
  HowItWorksStep(
    icon: Icons.chat_bubble_outline,
    title: 'Coordinate & play',
    description:
        'Chat in-app, keep your number private, and show up ready to play.',
  ),
];
