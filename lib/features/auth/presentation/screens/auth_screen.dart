import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../core/utils/storage_service.dart';

/// Accent màu chủ đạo của màn đăng nhập (theo template v0 "elegant login").
const Color _kIndigo = Color(0xFF3F3FF3);

/// Bảng màu trung tính của màn đăng nhập (luôn light, giống template).
const Color _kText = Color(0xFF1A1A1A);
const Color _kMuted = Color(0xFF737373);
const Color _kBorder = Color(0xFFE5E7EB);

enum _AuthView { login, register, forgot }

/// Màn đăng nhập / đăng ký / quên mật khẩu.
///
/// Thiết kế theo template v0 "Login Page" (split-screen indigo + form trắng
/// tối giản): panel trái là khối thương hiệu màu indigo (chỉ hiện trên màn
/// rộng), panel phải là form có label trên input, chuyển view bằng link.
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final VoidCallback onSkip;

  const AuthScreen({
    super.key,
    required this.onAuthSuccess,
    required this.onSkip,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthView _view = _AuthView.login;
  bool _isLoading = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _rememberMe = false;

  final _loginEmailCtrl = TextEditingController();
  final _loginPwCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPwCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  final _forgotEmailCtrl = TextEditingController();

  static const _rememberKey = 'auth_remember_email';

  @override
  void initState() {
    super.initState();
    // Prefill email nếu người dùng từng bật "Ghi nhớ".
    final saved = StorageService.getString(_rememberKey);
    if (saved != null && saved.isNotEmpty) {
      _rememberMe = true;
      _loginEmailCtrl.text = saved;
    }
  }

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPwCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPwCtrl.dispose();
    _regConfirmCtrl.dispose();
    _forgotEmailCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(isSuccess ? '✅ ' : '⚠️ '),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? _kIndigo : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _switchView(_AuthView v) {
    if (mounted) setState(() => _view = v);
  }

  Future<void> _doLogin() async {
    final email = _loginEmailCtrl.text.trim();
    final pw = _loginPwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ email và mật khẩu.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await SupabaseService.signIn(email: email, password: pw);
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
    // Lưu / xoá email ghi nhớ.
    StorageService.setString(_rememberKey, _rememberMe ? email : '');
    if (result.success) {
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onAuthSuccess();
    }
  }

  Future<void> _doRegister() async {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pw = _regPwCtrl.text;
    final confirm = _regConfirmCtrl.text;
    if (name.isEmpty || email.isEmpty || pw.isEmpty) {
      _showMessage('Vui lòng điền đầy đủ thông tin.', false);
      return;
    }
    if (pw != confirm) {
      _showMessage('Mật khẩu xác nhận không khớp!', false);
      return;
    }
    if (pw.length < 6) {
      _showMessage('Mật khẩu phải có ít nhất 6 ký tự.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result =
        await SupabaseService.signUp(email: email, password: pw, name: name);
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
    if (result.success) {
      if (SupabaseService.isLoggedIn) {
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onAuthSuccess();
      } else {
        _switchView(_AuthView.login);
        _loginEmailCtrl.text = email;
      }
    }
  }

  Future<void> _doResetPassword() async {
    final email = _forgotEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Vui lòng nhập email để nhận liên kết đặt lại.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await SupabaseService.resetPassword(email);
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
    if (result.success) _switchView(_AuthView.login);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const wideBreakpoint = 1024.0;
    final isWide = MediaQuery.of(context).size.width >= wideBreakpoint;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isWide
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildFormColumn(),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildFormColumn(withMobileLogo: true),
                ),
              ),
            ),
    );
  }

  // Logo nhỏ trên mobile (giống header mobile của template).
  Widget _buildMobileLogo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          _buildLogoMark(size: 36, inner: 18),
          const SizedBox(height: 10),
          const Text(
            'EduPulse',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
        ],
      ),
    );
  }

  /// Khối logo: ô trắng bo góc chứa ô vuông màu accent bên trong.
  Widget _buildLogoMark({required double size, required double inner}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: _kIndigo,
          borderRadius: BorderRadius.circular(inner * 0.28),
        ),
      ),
    );
  }

  Widget _buildFormColumn({bool withMobileLogo = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (withMobileLogo) Center(child: _buildMobileLogo()),
        // Nút back cho view quên mật khẩu.
        if (_view == _AuthView.forgot)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => _switchView(_AuthView.login),
              icon: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: _kText),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_view),
            child: _buildViewBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildViewBody() {
    switch (_view) {
      case _AuthView.login:
        return _buildLoginView();
      case _AuthView.register:
        return _buildRegisterView();
      case _AuthView.forgot:
        return _buildForgotView();
    }
  }

  // ---------------------------------------------------------------------------
  // Các view
  // ---------------------------------------------------------------------------

  Widget _buildLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ViewHeader(
          title: 'Chào mừng trở lại',
          subtitle: 'Nhập email và mật khẩu để tiếp tục ôn thi nhé.',
        ),
        const SizedBox(height: 24),
        _authField(
          label: 'Email',
          ctrl: _loginEmailCtrl,
          hint: 'ban@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _authField(
          label: 'Mật khẩu',
          ctrl: _loginPwCtrl,
          hint: 'Nhập mật khẩu',
          obscure: _obscurePw,
          suffix: _eyeToggle(_obscurePw, () => setState(() => _obscurePw = !_obscurePw)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  _checkbox(_rememberMe),
                  const SizedBox(width: 8),
                  const Text('Ghi nhớ đăng nhập',
                      style: TextStyle(fontSize: 13, color: _kMuted)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _switchView(_AuthView.forgot),
              behavior: HitTestBehavior.opaque,
              child: const Text('Quên mật khẩu?',
                  style: TextStyle(
                      fontSize: 13,
                      color: _kIndigo,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Đăng nhập',
          onTap: _isLoading ? null : _doLogin,
        ),
        const SizedBox(height: 20),
        _orDivider(),
        const SizedBox(height: 20),
        _outlineButton(
          label: 'Tiếp tục ở chế độ khách',
          onTap: _isLoading ? null : widget.onSkip,
        ),
        const SizedBox(height: 8),
        const Text(
          'Chế độ khách: dữ liệu chỉ lưu trên thiết bị này.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: _kMuted),
        ),
        const SizedBox(height: 20),
        _viewSwitchFooter(
          prefix: 'Chưa có tài khoản? ',
          linkText: 'Đăng ký ngay.',
          onTap: () => _switchView(_AuthView.register),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ViewHeader(
          title: 'Tạo tài khoản',
          subtitle: 'Tạo tài khoản mới để sao lưu và đồng bộ tiến độ ôn thi.',
        ),
        const SizedBox(height: 24),
        _authField(
          label: 'Tên / Biệt danh',
          ctrl: _regNameCtrl,
          hint: 'VD: Minh 2k9',
        ),
        const SizedBox(height: 16),
        _authField(
          label: 'Email',
          ctrl: _regEmailCtrl,
          hint: 'ban@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _authField(
          label: 'Mật khẩu',
          ctrl: _regPwCtrl,
          hint: 'Tối thiểu 6 ký tự',
          obscure: _obscurePw,
          suffix: _eyeToggle(_obscurePw, () => setState(() => _obscurePw = !_obscurePw)),
        ),
        const SizedBox(height: 16),
        _authField(
          label: 'Xác nhận mật khẩu',
          ctrl: _regConfirmCtrl,
          hint: 'Nhập lại mật khẩu',
          obscure: _obscureConfirm,
          suffix: _eyeToggle(
              _obscureConfirm,
              () =>
                  setState(() => _obscureConfirm = !_obscureConfirm)),
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Tạo tài khoản',
          onTap: _isLoading ? null : _doRegister,
        ),
        const SizedBox(height: 20),
        _orDivider(),
        const SizedBox(height: 20),
        _outlineButton(
          label: 'Tiếp tục ở chế độ khách',
          onTap: _isLoading ? null : widget.onSkip,
        ),
        const SizedBox(height: 20),
        _viewSwitchFooter(
          prefix: 'Đã có tài khoản? ',
          linkText: 'Đăng nhập.',
          onTap: () => _switchView(_AuthView.login),
        ),
      ],
    );
  }

  Widget _buildForgotView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ViewHeader(
          title: 'Đặt lại mật khẩu',
          subtitle:
              'Nhập email của bạn — chúng tôi sẽ gửi liên kết đặt lại mật khẩu.',
        ),
        const SizedBox(height: 24),
        _authField(
          label: 'Email',
          ctrl: _forgotEmailCtrl,
          hint: 'ban@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Gửi liên kết đặt lại',
          onTap: _isLoading ? null : _doResetPassword,
        ),
        const SizedBox(height: 20),
        _viewSwitchFooter(
          prefix: 'Nhớ lại mật khẩu rồi? ',
          linkText: 'Về đăng nhập.',
          onTap: () => _switchView(_AuthView.login),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets dùng chung
  // ---------------------------------------------------------------------------

  /// Input kiểu template: label đậm phía trên, ô cao 48, viền nhạt 1px,
  /// focus viền indigo, không shadow.
  Widget _authField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14.5, color: _kText),
          cursorColor: _kIndigo,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: _kMuted),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            filled: true,
            fillColor: Colors.white,
            // Ô cao 48px tổng thể.
            isDense: true,
            constraints: const BoxConstraints(minHeight: 48),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kIndigo, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _eyeToggle(bool obscure, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 19,
        color: _kMuted,
      ),
    );
  }

  Widget _checkbox(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: value ? _kIndigo : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: value ? _kIndigo : _kBorder,
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }

  /// Nút chính: full-width, cao 48, indigo đặc, không shadow.
  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isLoading ? _kIndigo.withValues(alpha: 0.55) : _kIndigo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Nút outline phụ (khách): viền nhạt, không shadow — giống social buttons.
  Widget _outlineButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _kText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Divider với nhãn "HOẶC" ở giữa (separator của template).
  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _kBorder, thickness: 1, height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'HOẶC',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _kBorder, thickness: 1, height: 1)),
      ],
    );
  }

  /// Footer chuyển view: chữ xám + link indigo.
  Widget _viewSwitchFooter({
    required String prefix,
    required String linkText,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prefix, style: const TextStyle(fontSize: 13, color: _kMuted)),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(linkText,
              style: const TextStyle(
                  fontSize: 13,
                  color: _kIndigo,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Panel thương hiệu bên trái (chỉ hiện trên màn rộng ≥1024px)
// -----------------------------------------------------------------------------

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kIndigo,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo: ô trắng + ô vuông indigo bên trong + tên app.
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _kIndigo,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'EduPulse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Học tập kỷ luật,\nchạm tới kỳ thi mơ ước.',
                style: TextStyle(
                  fontSize: 38,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đăng nhập để đồng bộ streak, nhiệm vụ và tiến độ ôn thi trên mọi thiết bị.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '© 2026 EduPulse',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  Text(
                    'Đồng bộ & sao lưu đám mây',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề + mô tả của từng view (giống cặp h2 + p muted của template).
class _ViewHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ViewHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _kText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}
