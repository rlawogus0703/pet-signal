import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/browse_notice.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/geolocation.dart';
import '../widgets/common.dart';
import 'nearby_screen.dart';
import 'notice_detail_screen.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _Msg {
  const _Msg(this.text, {this.mine = false});
  final String text;
  final bool mine;
}

class _MapScreenState extends State<MapScreen> {
  static const _seoul = LatLng(37.5665, 126.9780);
  static const _catColor = Color(0xFF7C5CFC);
  static const _examples = ['수원 갈색 푸들', '서울 흰색 고양이', '부산 치즈 고양이', '인천 흰색 말티즈'];

  final _map = MapController();
  final _input = TextEditingController();
  final _chatScroll = ScrollController();
  bool _ready = false;
  LatLng? _me;
  bool _loading = true;
  String? _error;
  String _label = '서울특별시';
  int _total = 0;
  String? _species;
  String? _filter;
  List<BrowseNotice> _items = [];
  Map<String, LatLng> _points = {};
  BrowseNotice? _selected;
  bool _chatOpen = false;
  bool _asking = false;
  final List<_Msg> _msgs = [
    const _Msg('안녕하세요! 지역, 색상, 품종을 말해 주시면 지도에서 비슷한 공고를 찾아 드릴게요.\n예: 수원 갈색 푸들'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _input.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final q = widget.initialQuery;
    if (q != null && q.trim().isNotEmpty) {
      setState(() => _chatOpen = true);
      await _ask(q);
      return;
    }
    await _load(region: _label);
    if (!mounted) return;
    await _locate(silent: true);
  }

  Future<void> _locate({bool silent = false}) async {
    final pos = await requestBrowserLocation();
    if (!mounted) return;
    if (pos == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져오지 못했어요. 브라우저에서 위치 권한을 허용해 주세요.')),
        );
      }
      return;
    }
    final me = LatLng(pos.$1, pos.$2);
    setState(() => _me = me);
    _move(me, 12);
    if (_filter == null) await _load(center: me);
  }

  void _move(LatLng p, double zoom) {
    if (_ready) _map.move(p, zoom);
  }

  Future<void> _load({LatLng? center, String? region}) async {
    final s = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await s.repo.mapNotices(
        lat: center?.latitude,
        lng: center?.longitude,
        region: center == null ? region : null,
        species: _species,
      );
      if (!mounted) return;
      setState(() {
        _label = center == null ? page.originLabel : (_me != null && center == _me ? '내 위치' : '지도 중심');
        _total = page.total;
        _filter = null;
        _setItems(page.items);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '공고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  // 같은 좌표(시군구 중심)에 겹친 공고를 나선 모양으로 조금씩 펼칩니다.
  void _setItems(List<BrowseNotice> items) {
    _selected = null;
    _items = items.where((n) => n.foundLat != null && n.foundLng != null).toList();
    final groups = <String, int>{};
    final points = <String, LatLng>{};
    for (final n in _items) {
      final key = '${n.foundLat!.toStringAsFixed(4)},${n.foundLng!.toStringAsFixed(4)}';
      final i = groups[key] ?? 0;
      groups[key] = i + 1;
      final r = 0.0016 * math.sqrt(i.toDouble());
      final a = i * 2.39996;
      points[n.noticeId] = LatLng(n.foundLat! + r * math.sin(a), n.foundLng! + r * 1.25 * math.cos(a));
    }
    _points = points;
  }

  Future<void> _ask(String text) async {
    final t = text.trim();
    if (t.isEmpty || _asking) return;
    final s = AppScope.read(context);
    _input.clear();
    setState(() {
      _msgs.add(_Msg(t, mine: true));
      _asking = true;
    });
    _scrollChat();
    try {
      final a = await s.repo.chat(t, lat: _me?.latitude, lng: _me?.longitude);
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg(a.reply));
        _asking = false;
        if (a.matched && a.items.isNotEmpty) {
          _filter = t;
          _total = a.total;
          _label = a.regionLabel ?? '내 주변';
          _setItems(a.items);
          _loading = false;
        }
      });
      if (a.matched && a.items.isNotEmpty) {
        _move(LatLng(a.centerLat, a.centerLng), a.zoom.toDouble());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _msgs.add(const _Msg('지금은 답을 가져오지 못했어요. 잠시 후 다시 말해 주세요.'));
        _asking = false;
      });
    }
    _scrollChat();
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearFilter() {
    setState(() => _filter = null);
    final c = _ready ? _map.camera.center : _seoul;
    _load(center: c);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Stack(
      children: [
        Positioned.fill(child: _mapView()),
        Positioned(left: 12, right: 12, top: 12, child: _topBar(narrow)),
        if (_selected != null)
          Positioned(
            left: 12,
            right: narrow ? 12 : null,
            bottom: 16,
            child: SizedBox(width: narrow ? null : 380, child: _popup(_selected!)),
          ),
        if (_chatOpen)
          Positioned(
            right: 12,
            left: narrow ? 12 : null,
            bottom: 16,
            top: narrow ? null : 84,
            height: narrow ? MediaQuery.sizeOf(context).height * 0.5 : null,
            child: SizedBox(width: narrow ? null : 360, child: _chatPanel()),
          )
        else
          Positioned(
            right: 16,
            bottom: _selected != null && narrow ? 250 : 20,
            child: FloatingActionButton.extended(
              heroTag: 'chat',
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              onPressed: () => setState(() {
                _chatOpen = true;
                if (narrow) _selected = null;
              }),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('챗봇에게 물어보기'),
            ),
          ),
      ],
    );
  }

  Widget _mapView() {
    final markers = <Marker>[
      for (final n in _items)
        if (_points[n.noticeId] != null)
          Marker(
            point: _points[n.noticeId]!,
            width: _selected?.noticeId == n.noticeId ? 44 : 30,
            height: _selected?.noticeId == n.noticeId ? 44 : 30,
            child: GestureDetector(
              onTap: () => setState(() {
                _selected = n;
                if (MediaQuery.sizeOf(context).width < 700) _chatOpen = false;
              }),
              child: MouseRegion(cursor: SystemMouseCursors.click, child: _pin(n)),
            ),
          ),
      if (_me != null)
        Marker(
          point: _me!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 6)],
            ),
          ),
        ),
    ];
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _seoul,
        initialZoom: 11,
        minZoom: 6,
        maxZoom: 18,
        onMapReady: () => _ready = true,
        onTap: (_, _) => setState(() => _selected = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'io.github.rlawogus0703.petsignal',
        ),
        MarkerLayer(markers: markers),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }

  Widget _pin(BrowseNotice n) {
    final cat = n.species == 'cat';
    final sel = _selected?.noticeId == n.noticeId;
    return Container(
      decoration: BoxDecoration(
        color: sel ? AppColors.navy : (cat ? _catColor : AppColors.coral),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Icon(Icons.pets, size: sel ? 22 : 15, color: Colors.white),
    );
  }

  Widget _topBar(bool narrow) {
    final info = _loading
        ? '공고를 불러오는 중…'
        : _error ?? (_filter != null ? '‘$_filter’ 결과 · 지도에 ${_items.length}건' : '$_label 가까운 공고 ${_items.length}건 표시 (전체 $_total건)');
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (_loading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.map_outlined, size: 18, color: AppColors.coral),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: narrow ? 260 : 420),
                child: Text(info, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ]),
            if (_filter != null)
              InputChip(
                label: const Text('검색 해제'),
                onDeleted: _clearFilter,
                onPressed: _clearFilter,
              )
            else
              for (final e in const [(null, '전체'), ('dog', '강아지'), ('cat', '고양이')])
                ChoiceChip(
                  label: Text(e.$2),
                  selected: _species == e.$1,
                  onSelected: (_) {
                    setState(() => _species = e.$1);
                    _load(center: _ready ? _map.camera.center : null, region: _label);
                  },
                ),
            TextButton.icon(
              onPressed: () => _load(center: _ready ? _map.camera.center : _seoul),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('이 지역 다시 찾기'),
            ),
            TextButton.icon(
              onPressed: () => _me != null ? _move(_me!, 13) : _locate(),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('내 위치'),
            ),
          ],
        ),
      ),
    );
  }

  String _sex(String s) => switch (s) {
        'M' => '수컷',
        'F' => '암컷',
        _ => '성별 모름',
      };

  Widget _popup(BrowseNotice n) {
    final animal = n.species == 'cat' ? '고양이' : '강아지';
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: AppColors.subtext),
            const SizedBox(width: 5),
            Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
          ]),
        );
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 96,
                height: 96,
                child: DogPhoto(url: n.thumbUrl, fallbackUrl: n.thumbFallbackUrl, noticeId: n.noticeId, breed: n.breed, radius: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        '${n.color} ${n.breed}'.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selected = null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.subtext),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    [animal, _sex(n.sex), if ((n.age ?? '').isNotEmpty) n.age!].join(' · '),
                    style: const TextStyle(color: AppColors.subtext, fontSize: 12),
                  ),
                  line(Icons.place_outlined, n.foundAddress.isEmpty ? '발견 장소 정보 없음' : n.foundAddress),
                  line(Icons.event_outlined, '발견일 ${n.foundDate == null ? '-' : ymd(n.foundDate!)}'),
                ]),
              ),
            ]),
            line(
              Icons.home_work_outlined,
              [n.shelterName, if (n.shelterPhone.isNotEmpty) n.shelterPhone].where((e) => e.isNotEmpty).join(' · '),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n))),
                  child: const Text('자세히 보기'),
                ),
              ),
              if (n.shelterPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${n.shelterPhone.replaceAll('-', '')}')),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('전화'),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            const Text('지도 위치는 발견 장소 기준 대략적인 위치예요.', style: TextStyle(color: AppColors.subtext, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _chatPanel() {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.coral,
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            child: Row(children: [
              const Icon(Icons.smart_toy_outlined, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('펫 시그널 챗봇', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('지역·색상·품종으로 찾아 드려요', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
              IconButton(
                onPressed: () => setState(() => _chatOpen = false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: _chatScroll,
              padding: const EdgeInsets.all(12),
              children: [
                for (final m in _msgs) _bubble(m),
                if (_asking) _bubble(const _Msg('찾는 중이에요…')),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (final e in _examples)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(label: Text(e, style: const TextStyle(fontSize: 12)), onPressed: () => _ask(e)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: const InputDecoration(
                    hintText: '예: 서울 흰색 고양이',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: _asking ? null : () => _ask(_input.text),
                icon: const Icon(Icons.send_rounded, color: AppColors.coral),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: m.mine ? AppColors.coral : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(m.text, style: TextStyle(color: m.mine ? Colors.white : AppColors.text, fontSize: 13, height: 1.4)),
      ),
    );
  }
}


class NearbyTab extends StatefulWidget {
  const NearbyTab({super.key});

  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab> {
  static bool _urlUsed = false;
  bool _map = true;
  String? _q;

  @override
  void initState() {
    super.initState();
    if (!_urlUsed) {
      _urlUsed = true;
      final p = Uri.base.queryParameters;
      _q = p['q'];
      if (p['view'] == 'list') _map = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('지도')),
                ButtonSegment(value: false, icon: Icon(Icons.list_alt_rounded), label: Text('목록')),
              ],
              selected: {_map},
              onSelectionChanged: (v) => setState(() => _map = v.first),
            ),
          ]),
        ),
        Expanded(child: _map ? MapScreen(initialQuery: _q) : const NearbyScreen()),
      ],
    );
  }
}
