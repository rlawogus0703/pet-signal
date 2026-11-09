import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 로그인 / 회원가입 (한 화면에서 전환)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.embedded = false, this.startWithSignup = false});
  final bool embedded;
  final bool startWithSignup;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _signup = widget.startWithSignup;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _pw, _pw2, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String _msg(Object e) {
    final s = '$e'.replaceFirst('Bad state: ', '');
    if (s.contains('ClientException') || s.contains('XMLHttpRequest') || s.contains('Failed to fetch')) {
      return '서버에 연결할 수 없어요. 서버가 켜져 있는지 확인하거나 Mock 모드로 바꿔 주세요.';
    }
    if (s.contains('401')) return '이메일 또는 비밀번호가 올바르지 않아요.';
    if (s.contains('409') || s.contains('already')) return '이미 가입된 이메일이에요.';
    return s;
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    await _run(() async {
      if (_signup) {
        await s.signup(
          email: _email.text.trim(),
          password: _pw.text,
          name: _name.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
      } else {
        await s.login(_email.text.trim(), _pw.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final form = _buildForm(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 40 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1000 : 480),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.line),
              boxShadow: AppShadows.soft,
            ),
            clipBehavior: Clip.antiAlias,
            child: wide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [const Expanded(child: _AuthVisual()), Expanded(child: form)],
                    ),
                  )
                : form,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_signup ? '회원가입' : '다시 만나서 반가워요',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              _signup ? '계정을 만들면 등록한 실종견과 알림을 계정별로 관리할 수 있어요.' : '로그인하고 우리 아이와 닮은 유사 후보를 확인하세요.',
              style: const TextStyle(color: AppColors.subtext),
            ),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('로그인')),
                ButtonSegment(value: true, label: Text('회원가입')),
              ],
              selected: {_signup},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() {
                _signup = v.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_signup) ...[
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '이름', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => (v ?? '').trim().isEmpty ? '이름을 입력해 주세요' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return '이메일을 입력해 주세요';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return '이메일 형식을 확인해 주세요';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '비밀번호',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return '비밀번호를 입력해 주세요';
                if (_signup && v!.length < 6) return '6자 이상 입력해 주세요';
                return null;
              },
              onFieldSubmitted: (_) => _signup ? null : _submit(),
            ),
            if (_signup) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _pw2,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: '비밀번호 확인', prefixIcon: Icon(Icons.lock_reset_rounded)),
                validator: (v) => v != _pw.text ? '비밀번호가 일치하지 않아요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: '연락처 (선택)', hintText: '010-1234-5678', prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(height: 0)
                  : Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13.5))),
                      ]),
                    ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_signup ? '가입하고 시작하기' : '로그인'),
            ),
            const SizedBox(height: 12),
            Row(children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('또는', style: TextStyle(color: AppColors.subtext, fontSize: 12.5)),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(s.demoLogin),
              icon: const Icon(Icons.bolt_rounded, color: AppColors.coral),
              label: const Text('데모 계정으로 바로 시작'),
            ),
            const SizedBox(height: 10),
            Text(
              s.useApi ? '현재 API 서버(${s.apiBaseUrl})에 연결돼요.' : 'Mock 모드: 데모 계정 demo@petsignal.kr / demo1234',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.subtext),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthVisual extends StatelessWidget {
  const _AuthVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/dogs/my_maltese.jpg', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x3316233F), Color(0xE616233F)],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandLogo(light: true),
              Spacer(),
              Text('“흰색 말티즈”로 찾던 아이가\n“크림색 믹스견”으로 올라와 있어도',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.4)),
              SizedBox(height: 10),
              Text('표기 차이를 정규화하고 사진·설명까지 비교해서 놓치지 않게 알려드려요.',
                  style: TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
