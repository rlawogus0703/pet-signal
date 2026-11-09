import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/options.dart';
import '../state/app_state.dart';
import '../state/demo.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _color = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _features = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  Uint8List? _photo;
  String? _photoAsset;
  DateTime? _lostDate;
  String _sido = '경기도';
  Region? _region;
  bool _busy = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _breed, _color, _age, _address, _features]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _breed, _color, _age, _address, _features, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setRegion(Region r) {
    setState(() {
      _region = r;
      _sido = r.sido;
      _lat.text = r.lat.toStringAsFixed(4);
      _lng.text = r.lng.toStringAsFixed(4);
    });
  }

  void _fillExample() {
    setState(() {
      _name.text = DemoDog.name;
      _breed.text = DemoDog.breed;
      _color.text = DemoDog.color;
      _age.text = DemoDog.age;
      _features.text = DemoDog.features;
      _lostDate = DemoDog.lostDate;
      _photo = null;
      _photoAsset = DemoDog.photoAsset;
      _setRegion(regions.first);
      _address.text = '양산동 한신대학교 인근';
      _lat.text = DemoDog.lat.toString();
      _lng.text = DemoDog.lng.toString();
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        _photo = bytes;
        _photoAsset = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했어요: $e')));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lostDate ?? now,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      helpText: '실종 날짜 선택',
    );
    if (picked != null) setState(() => _lostDate = picked);
  }

  bool get _extraValid =>
      _breed.text.trim().isNotEmpty && _color.text.trim().isNotEmpty && _lostDate != null && _region != null;

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final ok = _form.currentState!.validate();
    if (!ok || !_extraValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필수 항목을 확인해 주세요')));
      return;
    }
    final s = AppScope.read(context);
    setState(() => _busy = true);
    try {
      await s.registerDog(
        name: _name.text.trim().isEmpty ? '우리 아이' : _name.text.trim(),
        photoBytes: _photo,
        photoAsset: _photoAsset,
        breed: _breed.text.trim(),
        color: _color.text.trim(),
        features: _features.text.trim(),
        age: _age.text.trim().isEmpty ? null : _age.text.trim(),
        lostDate: _lostDate!,
        lostLat: double.tryParse(_lat.text) ?? _region!.lat,
        lostLng: double.tryParse(_lng.text) ?? _region!.lng,
        lostAddress: '${_region!.label} ${_address.text.trim()}'.trim(),
      );
      s.goTab(2);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(_basicSection()),
          const SizedBox(height: Gap.m),
          _section(_lostSection()),
          const SizedBox(height: Gap.m),
          _section(_featureSection()),
          const SizedBox(height: Gap.l),
          if (!wide) ...[_submitButton(), const SizedBox(height: Gap.l)],
        ],
      ),
    );
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('실종견 등록', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  const Text('자세히 적을수록 유사 후보를 더 정확하게 찾아요. 등록 즉시 매칭이 시작돼요.',
                      style: TextStyle(color: AppColors.subtext)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _fillExample,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('논문 예시로 채우기'),
            ),
          ],
        ),
        const SizedBox(height: Gap.l),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: form),
              const SizedBox(width: Gap.l),
              SizedBox(width: 340, child: _preview()),
            ],
          )
        else
          form,
      ],
    );
  }

  Widget _section(Widget child) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: child,
      );

  Widget _basicSection() {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final photo = _PhotoDrop(
      bytes: _photo,
      asset: _photoAsset,
      onPick: _pickPhoto,
      onClear: () => setState(() {
        _photo = null;
        _photoAsset = null;
      }),
      onSample: () => setState(() {
        _photo = null;
        _photoAsset = DemoDog.photoAsset;
      }),
    );
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: '이름 (선택)', hintText: '예: 콩이'),
        ),
        const SizedBox(height: 14),
        DropdownMenu<String>(
          controller: _breed,
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          label: const Text('품종 *'),
          hintText: '목록에서 고르거나 직접 입력',
          leadingIcon: const Icon(Icons.pets_rounded),
          errorText: _submitted && _breed.text.trim().isEmpty ? '품종을 입력해 주세요' : null,
          menuHeight: 300,
          dropdownMenuEntries: [for (final b in breedOptions) DropdownMenuEntry(value: b, label: b)],
          onSelected: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _age,
          decoration: const InputDecoration(labelText: '나이', hintText: '예: 3살, 2~3년, 6개월'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in ['6개월', '1살', '2~3년', '3살', '5살', '8살 이상'])
            ActionChip(label: Text(a), onPressed: () => _age.text = a, visualDensity: VisualDensity.compact),
        ]),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('사진과 기본 정보', step: 1, subtitle: '사진은 이미지 유사도(AI) 계산에 쓰여요.'),
        const SizedBox(height: 20),
        if (narrow) ...[photo, const SizedBox(height: 16), fields]
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 220, child: photo),
            const SizedBox(width: 24),
            Expanded(child: fields),
          ]),
        const SizedBox(height: 18),
        const Text('털색 *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in colorOptions)
              ChoiceChip(
                selected: _color.text == c.label,
                showCheckmark: false,
                avatar: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                ),
                label: Text(c.label),
                onSelected: (_) => setState(() => _color.text = c.label),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _color,
          decoration: const InputDecoration(labelText: '색상 직접 입력', hintText: '예: 흰색에 갈색 반점'),
          validator: (v) => (v ?? '').trim().isEmpty ? '털색을 선택하거나 입력해 주세요' : null,
        ),
      ],
    );
  }

  Widget _lostSection() {
    final sigungu = regions.where((r) => r.sido == _sido).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('실종 날짜와 위치', step: 2, subtitle: '거리·날짜 점수 계산에 쓰여요.'),
        const SizedBox(height: 20),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '실종 날짜 *',
              prefixIcon: const Icon(Icons.event_rounded),
              errorText: _submitted && _lostDate == null ? '실종 날짜를 선택해 주세요' : null,
            ),
            child: Text(_lostDate == null ? '날짜를 선택하세요' : ymd(_lostDate!),
                style: TextStyle(color: _lostDate == null ? AppColors.subtext : AppColors.text)),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _sido,
              decoration: const InputDecoration(labelText: '시·도'),
              items: [for (final s in sidoList) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setState(() {
                _sido = v!;
                _region = null;
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<Region>(
              key: ValueKey('sgg-$_sido-${_region?.label}'),
              initialValue: _region,
              decoration: InputDecoration(
                labelText: '시·군·구 *',
                errorText: _submitted && _region == null ? '지역을 선택해 주세요' : null,
              ),
              items: [for (final r in sigungu) DropdownMenuItem(value: r, child: Text(r.sigungu))],
              onChanged: (r) => _setRegion(r!),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(
              labelText: '상세 위치', hintText: '예: 양산동 한신대학교 정문 앞', prefixIcon: Icon(Icons.place_outlined)),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('좌표 직접 조정 (선택)', style: TextStyle(fontSize: 13.5, color: AppColors.subtext)),
            children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    decoration: const InputDecoration(labelText: '위도'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    decoration: const InputDecoration(labelText: '경도'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureSection() {
    const tags = ['빨간 목걸이', '귀가 접힘', '귀가 서 있음', '꼬리 말림', '소형', '중형', '중성화', '옷 착용', '겁이 많음', '사람을 잘 따름'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('특징', step: 3, subtitle: '특징 키워드와 문장 유사도(AI) 계산에 쓰여요.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: _features,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: '외형·성격 특징 *',
            hintText: '예: 왼쪽 귀 근처에 작은 점, 빨간 목걸이, 겁이 많아요',
            alignLabelWithHint: true,
          ),
          validator: (v) => (v ?? '').trim().length < 4 ? '특징을 4자 이상 적어 주세요' : null,
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in tags)
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16),
              label: Text(t),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                final cur = _features.text.trim();
                if (cur.contains(t)) return;
                _features.text = cur.isEmpty ? t : '$cur, $t';
              },
            ),
        ]),
      ],
    );
  }

  Widget _submitButton() => FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: _busy ? null : _submit,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : const Icon(Icons.manage_search_rounded),
        label: Text(_busy ? '유사 후보를 찾는 중…' : '등록하고 유사 후보 찾기'),
      );

  Widget _preview() {
    final filled = [
      _breed.text.trim().isNotEmpty,
      _color.text.trim().isNotEmpty,
      _lostDate != null,
      _region != null,
      _features.text.trim().length >= 4,
      _photo != null || _photoAsset != null,
      _age.text.trim().isNotEmpty,
    ];
    final progress = filled.where((e) => e).length / filled.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('등록 미리보기', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: DogPhoto(bytes: _photo, asset: _photoAsset, breed: _breed.text.isEmpty ? null : _breed.text, radius: 16),
          ),
          const SizedBox(height: 14),
          Text(_name.text.isEmpty ? '우리 아이' : _name.text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            [_color.text, _breed.text, _age.text].where((e) => e.trim().isNotEmpty).join(' · ').ifEmpty('품종·색상·나이'),
            style: const TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 12),
          _kv(Icons.event_outlined, _lostDate == null ? '-' : '${ymd(_lostDate!)} 실종'),
          _kv(Icons.place_outlined, _region == null ? '-' : '${_region!.label} ${_address.text}'),
          if (_features.text.isNotEmpty) _kv(Icons.label_outline_rounded, _features.text),
          const SizedBox(height: 16),
          Row(children: [
            const Text('입력 완성도', style: TextStyle(fontSize: 12.5, color: AppColors.subtext)),
            const Spacer(),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.coralSoft,
              valueColor: const AlwaysStoppedAnimation(AppColors.coral),
            ),
          ),
          const SizedBox(height: 18),
          _submitButton(),
          const SizedBox(height: 12),
          const DisclaimerBanner(compact: true),
        ],
      ),
    );
  }

  Widget _kv(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 16, color: AppColors.subtext),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5))),
        ]),
      );
}

extension on String {
  String ifEmpty(String other) => trim().isEmpty ? other : this;
}

class _PhotoDrop extends StatelessWidget {
  const _PhotoDrop({this.bytes, this.asset, required this.onPick, required this.onClear, required this.onSample});
  final Uint8List? bytes;
  final String? asset;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final has = bytes != null || asset != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: HoverCard(
            onTap: onPick,
            color: AppColors.bg,
            radius: 18,
            child: has
                ? Stack(fit: StackFit.expand, children: [
                    DogPhoto(bytes: bytes, asset: asset, radius: 18),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        iconSize: 18,
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ])
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.coral),
                      SizedBox(height: 8),
                      Text('사진 업로드', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('JPG · PNG', style: TextStyle(fontSize: 12, color: AppColors.subtext)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onSample, child: const Text('예시 사진 사용')),
      ],
    );
  }
}
