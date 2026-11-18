import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../models/lost_dog.dart';
import '../models/score_breakdown.dart';
import 'scorer.dart';


class ScoreItem {
  const ScoreItem(this.label, this.icon, this.value, this.weight, {this.ai = false, this.note});
  final String label;
  final IconData icon;
  final double? value;
  final double weight;
  final bool ai;
  final String? note;
}


List<RuleItem> ruleItemsOf(Candidate c) => c.score.items;

IconData ruleIcon(String key) => switch (key) {
      'breed' => Icons.pets_rounded,
      'color' => Icons.palette_outlined,
      'region' => Icons.place_outlined,
      'features' => Icons.label_outline_rounded,
      'date' => Icons.event_outlined,
      _ => Icons.check_rounded,
    };


String ruleChipLabel(RuleItem it) => switch (it.key) {
      'breed' => '품종 일치',
      'color' => '색상 일치',
      'region' => '같은 시군구',
      'features' => '특징 단어 일치',
      'date' => '실종일 이후 접수',
      _ => it.label,
    };


double? distanceKm(LostDog d, Candidate c) {
  if (c.foundLat == null || c.foundLng == null) return null;
  return RuleScorer.haversineKm(d.lostLat, d.lostLng, c.foundLat!, c.foundLng!);
}

int dayDiff(LostDog d, Candidate c) => c.foundDate.difference(d.lostDate).inDays;
