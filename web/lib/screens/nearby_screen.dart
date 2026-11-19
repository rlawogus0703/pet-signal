import 'package:flutter/material.dart';

import '../data/options.dart';
import '../models/browse_notice.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/geolocation.dart';
import '../widgets/common.dart';
import 'notice_detail_screen.dart';


class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, this.embedded = false});


  final bool embedded;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  static const _defaultSido = '서울특별시';

  bool _useGps = false;
  bool _gpsBusy = false;
  double? _lat;
  double? _lng;
  late String _sido;
  String? _sigungu;
  String? _species;
  String? _kind;
  String? _color;
  int? _days = 30;
  double? _radius;
  bool _loading = true;
  String? _error;
  String _originLabel = _defaultSido;
  int _total = 0;
  int _page = 1;
  final List<BrowseNotice> _items = [];

  List<String> get _sidos {
    final s = <String>{};
    for (final r in regions) {
      s.add(r.sido);
    }
    return s.toList();
  }

  List<Region> get _gungu => regions.where((r) => r.sido == _sido).toList();

  int get _pageSize => widget.embedded ? 6 : 20;

  @override
  void initState() {
    super.initState();
    _sido = loadPref('nearby_sido') ?? _defaultSido;
    _sigungu = loadPref('nearby_sigungu');
    if (_sigungu != null && !_gungu.any((r) => r.sigungu == _sigungu)) {
      _sigungu = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  String get _regionLabel {
    if (_sigungu == null || _sigungu!.isEmpty) return _sido;
    return '$_sido $_sigungu';
  }

  Future<void> _bootstrap() async {
    await _reload(reset: true);

    if (!mounted) return;
    await _tryGps(silent: true);
  }

  Future<void> _tryGps({bool silent = false}) async {
    setState(() => _gpsBusy = true);
    final pos = await requestBrowserLocation();
    if (!mounted) return;
    setState(() => _gpsBusy = false);
    if (pos == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져오지 못했어요. 시·군·구를 선택해 주세요.')),
        );
      }
      return;
    }
    setState(() {
      _useGps = true;
      _lat = pos.$1;
      _lng = pos.$2;
    });
    await _reload(reset: true);
  }

  void _useRegion() {
    setState(() {
      _useGps = false;
      _lat = null;
      _lng = null;
    });
    savePref('nearby_sido', _sido);
    if (_sigungu != null) savePref('nearby_sigungu', _sigungu!);
    _reload(reset: true);
  }

  Future<void> _reload({bool reset = false}) async {
    final s = AppScope.read(context);
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _items.clear();
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      final page = await s.repo.listNearbyNotices(
        lat: _useGps ? _lat : null,
        lng: _useGps ? _lng : null,
        region: _useGps ? null : _regionLabel,
        kind: _kind,
        species: _species,
        color: _color,
        days: _days,
        radius: _radius,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _originLabel = page.originLabel;
        _total = page.total;
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '공고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  void _open(BrowseNotice n) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n)));
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded)
          const SectionTitle('가까운 보호소 공고', subtitle: '로그인하지 않아도 주변 보호소에 있는 아이들을 볼 수 있어요.')
        else ...[
          Row(
            children: [
              const Expanded(
                child: SectionTitle('가까운 보호소 공고', subtitle: '로그인 없이, 내 위치 또는 선택한 지역 기준으로 거리순으로 보여드려요.'),
              ),
              TextButton(
                onPressed: () => AppScope.read(context).goTab(1),
                child: const Text('모두 보기'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _filters(),
        const SizedBox(height: 8),
        Text(
          _useGps
              ? '현재 위치 기준 · $_total건'
              : '$_originLabel 기준 · $_total건',
          style: const TextStyle(color: AppColors.subtext, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_error != null && _items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(_error!, style: const TextStyle(color: AppColors.subtext)),
                const SizedBox(height: 8),
                TextButton(onPressed: () => _reload(reset: true), child: const Text('다시 시도')),
              ],
            ),
          )
        else if (!_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('조건에 맞는 공고가 없어요. 반경이나 날짜를 넓혀 보세요.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtext)),
          )
        else
          _grid(),
        if (!widget.embedded && _items.length < _total) ...[
          const SizedBox(height: 16),
          Center(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                : TextButton(
                    onPressed: () {
                      _page += 1;
                      _reload();
                    },
                    child: Text('더 보기 (${_items.length}/$_total)'),
                  ),
          ),
        ],
        if (_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
    if (widget.embedded) return body;
    return PageBody(children: [body, const SizedBox(height: 40)]);
  }

  Widget _filters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _gpsBusy ? null : () => _tryGps(),
          icon: _gpsBusy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_useGps ? Icons.my_location : Icons.location_searching, size: 18),
          label: Text(_useGps ? '현재 위치 사용 중' : '내 위치 사용'),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _sidos.contains(_sido) ? _sido : _sidos.first,
            items: [for (final s in _sidos) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _sido = v;
                _sigungu = null;
              });
              _useRegion();
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _sigungu,
            hint: const Text('시·군·구'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('시·도 전체')),
              for (final r in _gungu) DropdownMenuItem<String?>(value: r.sigungu, child: Text(r.sigungu)),
            ],
            onChanged: (v) {
              setState(() => _sigungu = v);
              _useRegion();
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _species,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('동물 전체')),
              DropdownMenuItem<String?>(value: 'dog', child: Text('강아지')),
              DropdownMenuItem<String?>(value: 'cat', child: Text('고양이')),
            ],
            onChanged: (v) {
              setState(() {
                _species = v;
                _kind = null;
              });
              _reload(reset: true);
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _kind,
            hint: const Text('품종'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('품종 전체')),
              for (final b in _species == null ? [...breedOptions, ...catBreedOptions] : breedsFor(_species!))
                DropdownMenuItem<String?>(value: b, child: Text(b)),
            ],
            onChanged: (v) {
              setState(() => _kind = v);
              _reload(reset: true);
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _color,
            hint: const Text('색상'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('색상 전체')),
              for (final c in [...colorOptions, if (_species != 'dog') ...catColorOptions])
                DropdownMenuItem<String?>(value: c.label, child: Text(c.label)),
            ],
            onChanged: (v) {
              setState(() => _color = v);
              _reload(reset: true);
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _days,
            items: const [
              DropdownMenuItem(value: 7, child: Text('최근 7일')),
              DropdownMenuItem(value: 14, child: Text('최근 14일')),
              DropdownMenuItem(value: 30, child: Text('최근 30일')),
              DropdownMenuItem(value: 90, child: Text('최근 90일')),
              DropdownMenuItem(value: null, child: Text('발견일 전체')),
            ],
            onChanged: (v) {
              setState(() => _days = v);
              _reload(reset: true);
            },
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<double?>(
            value: _radius,
            items: const [
              DropdownMenuItem(value: null, child: Text('거리 제한 없음')),
              DropdownMenuItem(value: 10, child: Text('10km')),
              DropdownMenuItem(value: 30, child: Text('30km')),
              DropdownMenuItem(value: 50, child: Text('50km')),
              DropdownMenuItem(value: 100, child: Text('100km')),
            ],
            onChanged: (v) {
              setState(() => _radius = v);
              _reload(reset: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _grid() {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 1100 ? 3 : (w >= 700 ? 2 : 1);
      const gap = 16.0;
      final itemW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final n in _items) SizedBox(width: itemW, child: _NoticeCard(notice: n, onTap: () => _open(n))),
        ],
      );
    });
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onTap});
  final BrowseNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final dist = n.distKm;
    return HoverCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: DogPhoto(
                url: n.thumbUrl,
                fallbackUrl: n.thumbFallbackUrl,
                radius: 0,
                cacheWidth: 400,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${n.color} ${n.breed}'.trim().isEmpty ? '품종 미상' : '${n.color} ${n.breed}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  '${n.age ?? '나이 미상'} · ${n.foundDate == null ? '발견일 미상' : '${ymd(n.foundDate!)} 발견'}',
                  style: const TextStyle(color: AppColors.subtext, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.subtext),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (dist != null) (dist < 10 ? '${dist.toStringAsFixed(1)}km' : '${dist.round()}km'),
                        n.foundAddress,
                      ].where((e) => e.toString().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.home_work_outlined, size: 15, color: AppColors.subtext),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        n.shelterName,
                        if (n.shelterPhone.isNotEmpty) n.shelterPhone,
                      ].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
                if (n.noticeStart != null || n.noticeEnd != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '공고 ${n.noticeStart == null ? '' : ymd(n.noticeStart!)} ~ ${n.noticeEnd == null ? '' : ymd(n.noticeEnd!)}',
                    style: const TextStyle(color: AppColors.subtext, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
