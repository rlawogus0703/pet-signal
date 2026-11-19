import 'package:flutter/material.dart';

import 'regions_data.dart';


const breedOptions = <String>[
  '말티즈', '푸들', '토이푸들', '포메라니안', '믹스견', '치와와', '시츄', '비숑프리제', '요크셔테리어',
  '웰시코기', '골든리트리버', '진돗개', '시바견', '닥스훈트', '비글', '프렌치불독', '슈나우저',
  '보더콜리', '사모예드', '퍼그',
];

const catBreedOptions = <String>[
  '코리안숏헤어', '러시안블루', '페르시안', '스코티시폴드', '브리티시숏헤어', '먼치킨', '샴', '렉돌',
  '노르웨이숲', '아비시니안', '벵갈', '터키시앙고라', '메인쿤', '스핑크스', '믹스',
];

List<String> breedsFor(String species) => species == 'cat' ? catBreedOptions : breedOptions;

String speciesLabel(String species) => species == 'cat' ? '고양이' : '강아지';

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

const catColorOptions = <ColorOption>[
  ColorOption('치즈', Color(0xFFF0B45A)),
  ColorOption('고등어', Color(0xFF8B8F8A)),
  ColorOption('턱시도', Color(0xFF2B2B2B)),
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
