import 'package:flutter/material.dart';

import 'regions_data.dart';


const breedOptions = <String>[
  '말티즈', '믹스견', '푸들', '토이푸들', '포메라니안', '비숑프리제', '시츄', '치와와', '요크셔테리어',
  '진돗개', '골든리트리버', '비글', '웰시코기', '닥스훈트', '프렌치불독', '코카스파니엘',
];

class ColorOption {
  const ColorOption(this.label, this.color);
  final String label;
  final Color color;
}

const colorOptions = <ColorOption>[
  ColorOption('흰색', Color(0xFFFFFFFF)),
  ColorOption('크림색', Color(0xFFF3E5C8)),
  ColorOption('황색', Color(0xFFE2B866)),
  ColorOption('갈색', Color(0xFF9A6B45)),
  ColorOption('검정', Color(0xFF23262E)),
  ColorOption('회색', Color(0xFF9CA3AF)),
  ColorOption('삼색', Color(0xFFC08A5B)),
  ColorOption('얼룩', Color(0xFFD6CFC7)),
];

class Region {
  const Region(this.sido, this.sigungu, this.lat, this.lng);
  final String sido;
  final String sigungu;
  final double lat;
  final double lng;
  String get label => '$sido $sigungu';
}


final List<Region> regions = () {
  final all = [for (final r in regionRows) Region(r.$1, r.$2, r.$3, r.$4)];
  final gg = all.where((r) => r.sido == '경기도').toList();
  final osan = gg.indexWhere((r) => r.sigungu == '오산시');
  if (osan > 0) gg.insert(0, gg.removeAt(osan));
  return [...gg, ...all.where((r) => r.sido != '경기도')];
}();

List<String> get sidoList => regions.map((r) => r.sido).toSet().toList();
