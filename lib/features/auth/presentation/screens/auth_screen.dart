import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_service.dart';
import '../../../../core/utils/storage_service.dart';

/// Accent xanh lá chủ đạo từ theme app.
const Color _kAccent = AppColors.primary;

/// Bảng màu theo style "Stratis UI — Login modals": card trắng bo tròn nằm
/// giữa, tab đổi Đăng nhập / Đăng ký ở đầu modal, input nền xám nhạt, nút pill.
const Color _kText = Color(0xFF1A1A2E);
const Color _kMuted = Color(0xFF6B7280);
const Color _kField = Color(0xFFF6F7F9);
const Color _kBorder = Color(0xFFE8EAED);
const Color _kTrack = Color(0xFFF1F3F0);

enum _AuthView { login, register, verify, forgot }

/// Màn đăng nhập / đăng ký / xác minh email / quên mật khẩu.
///
/// Re-design theo "Stratis UI — Login modals": toàn màn hình nền gradient nhẹ,
/// ở giữa là một modal card trắng (max 440px) chứa logo, tab Đăng nhập/Đăng ký,
/// form input sạch, nút pill. Mọi trạng thái vẫn theo theme EduPulse (xanh lá).
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

  /// Bước trong luồng quên mật khẩu: 0 = nhập email, 1 = nhập mã 8 chữ số.
  int _forgotStep = 0;

  final _loginEmailCtrl = TextEditingController();
  final _loginPwCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPwCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  final _forgotEmailCtrl = TextEditingController();
  final _forgotCodeCtrl = TextEditingController();
  final _verifyEmailCtrl = TextEditingController();
  final _verifyCodeCtrl = TextEditingController();

  static const _rememberKey = 'auth_remember_email';

  @override
  void initState() {
    super.initState();
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
    _forgotCodeCtrl.dispose();
    _verifyEmailCtrl.dispose();
    _verifyCodeCtrl.dispose();
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
        backgroundColor: isSuccess ? _kAccent : AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _switchView(_AuthView v) {
    if (mounted) setState(() => _view = v);
  }

  /// Mở màn quên mật khẩu, luôn bắt đầu từ bước nhập email.
  void _openForgot() {
    if (mounted) {
      setState(() {
        _forgotStep = 0;
        _view = _AuthView.forgot;
      });
    }
  }

  /// Mở màn đăng ký có sẵn email (khi email chưa từng đăng ký).
  void _openRegisterWithEmail(String email) {
    if (mounted) {
      _regEmailCtrl.text = email;
      setState(() => _view = _AuthView.register);
    }
  }

  Future<void> _doGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (AuthService.isLoggedIn) {
      _showMessage('Đăng nhập Google thành công! 🎉', true);
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onAuthSuccess();
      return;
    }
    _showMessage(result.message, result.success);
  }

  Future<void> _doLogin() async {
    final email = _loginEmailCtrl.text.trim();
    final pw = _loginPwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ email và mật khẩu.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await AuthService.signIn(email: email, password: pw);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
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
        await AuthService.signUp(email: email, password: pw, name: name);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
    if (result.success) {
      if (AuthService.isEmailVerified) {
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onAuthSuccess();
      } else {
        _switchView(_AuthView.verify);
        _verifyEmailCtrl.text = email;
        AuthService.sendVerificationCode();
      }
    }
  }

  /// Bước 1 quên mật khẩu: gửi mã 8 chữ số về email rồi sang bước nhập mã.
  /// (Email tồn tại hay không được xác minh ở bước 2 để tránh lộ thông tin.)
  Future<void> _doSendResetCode() async {
    final email = _forgotEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Vui lòng nhập email trước để gửi mã.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await AuthService.sendResetCode(email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
    if (result.success) {
      setState(() => _forgotStep = 1);
    }
  }

  /// Bước 2 quên mật khẩu: nhập mã 8 chữ số → server kích hoạt email đặt lại
  /// mật khẩu Firebase (bấm link trong email để đặt mật khẩu mới).
  Future<void> _doResetPassword() async {
    final email = _forgotEmailCtrl.text.trim();
    final code = _forgotCodeCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Vui lòng nhập email.', false);
      return;
    }
    if (code.isEmpty || code.length != 8) {
      _showMessage('Vui lòng nhập đủ mã 8 chữ số.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result =
        await AuthService.resetPasswordByCode(email: email, code: code);
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Email chưa từng đăng ký → chuyển sang đăng ký với email vừa nhập.
    if (result.code == 'EMAIL_NOT_FOUND') {
      _openRegisterWithEmail(email);
      _showMessage(
          'Email chưa đăng ký EduPulse — tạo tài khoản mới nhé!', false);
      return;
    }

    _showMessage(result.message, result.success);
    if (result.success) {
      await Future.delayed(const Duration(milliseconds: 600));
      _switchView(_AuthView.login);
    }
  }

  /// Gửi mã 8 chữ số nhập tay lên serverless API để xác nhận (thay cho link).
  Future<void> _doVerifyEmail() async {
    final code = _verifyCodeCtrl.text.trim();
    if (code.isEmpty || code.length != 8) {
      _showMessage('Vui lòng nhập đủ mã xác minh 8 chữ số.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await AuthService.verifyEmailWithCode(code);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
    if (result.success) {
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onAuthSuccess();
    }
  }

  Future<void> _doResendEmail() async {
    setState(() => _isLoading = true);
    final result = await AuthService.sendVerificationCode();
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEFBE0), Colors.white, Colors.white],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildModalCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Modal card giữa màn hình theo style Stratis: trắng, bo 24, viền 1px +
  /// shadow rất mềm.
  Widget _buildModalCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF58CC02).withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModalHeader(),
          const SizedBox(height: 20),
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
      ),
    );
  }

  /// Logo nhỏ + tên app ở đầu modal (thay cho đăng nhập căn giữa trống trải).
  Widget _buildModalHeader() {
    return Column(
      children: [
        _buildLogoMark(size: 44, inner: 22),
        const SizedBox(height: 10),
        const Text(
          'EduPulse',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kText,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoMark({required double size, required double inner}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(inner * 0.3),
        ),
      ),
    );
  }

  Widget _buildViewBody() {
    switch (_view) {
      case _AuthView.login:
        return _buildLoginView();
      case _AuthView.register:
        return _buildRegisterView();
      case _AuthView.verify:
        return _buildVerifyView();
      case _AuthView.forgot:
        return _buildForgotView();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab Đăng nhập / Đăng ký (điểm nhấn "Login modals" của Stratis)
  // ---------------------------------------------------------------------------

  Widget _buildAuthTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(
            label: 'Đăng nhập',
            active: _view == _AuthView.login,
            onTap: () => _switchView(_AuthView.login),
          ),
          _tab(
            label: 'Đăng ký',
            active: _view == _AuthView.register,
            onTap: () => _switchView(_AuthView.register),
          ),
        ],
      ),
    );
  }

  Widget _tab(
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF58CC02).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? _kAccent : _kMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Các view
  // ---------------------------------------------------------------------------

  Widget _buildLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAuthTabs(),
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
          suffix: _eyeToggle(
              _obscurePw, () => setState(() => _obscurePw = !_obscurePw)),
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
              onTap: _openForgot,
              behavior: HitTestBehavior.opaque,
              child: const Text('Quên mật khẩu?',
                  style: TextStyle(
                      fontSize: 13,
                      color: _kAccent,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _primaryButton(
          label: 'Đăng nhập',
          onTap: _isLoading ? null : _doLogin,
        ),
        const SizedBox(height: 18),
        _orDivider(),
        const SizedBox(height: 18),
        _googleButton(onTap: _isLoading ? null : _doGoogleSignIn),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _isLoading ? null : widget.onSkip,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Text(
              'Tiếp tục ở chế độ khách',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _kMuted,
                decoration: TextDecoration.underline,
                decorationColor: _kMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Chế độ khách: dữ liệu chỉ lưu trên thiết bị này.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: _kMuted),
        ),
        const SizedBox(height: 14),
        const Divider(color: _kBorder, thickness: 0.5, height: 1),
        const SizedBox(height: 14),
        const Text(
          'Tiếp tục tức là bạn đồng ý với Điều khoản sử dụng của EduPulse.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.4, color: _kMuted),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAuthTabs(),
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
          suffix: _eyeToggle(
              _obscurePw, () => setState(() => _obscurePw = !_obscurePw)),
        ),
        const SizedBox(height: 16),
        _authField(
          label: 'Xác nhận mật khẩu',
          ctrl: _regConfirmCtrl,
          hint: 'Nhập lại mật khẩu',
          obscure: _obscureConfirm,
          suffix: _eyeToggle(_obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm)),
        ),
        const SizedBox(height: 22),
        _primaryButton(
          label: 'Tạo tài khoản',
          onTap: _isLoading ? null : _doRegister,
        ),
        const SizedBox(height: 18),
        _orDivider(),
        const SizedBox(height: 18),
        _googleButton(onTap: _isLoading ? null : _doGoogleSignIn),
        const SizedBox(height: 14),
        const Text(
          'Tiếp tục tức là bạn đồng ý với Điều khoản sử dụng của EduPulse.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.4, color: _kMuted),
        ),
      ],
    );
  }

  Widget _buildVerifyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBackRow(onTap: () => _switchView(_AuthView.login)),
        const SizedBox(height: 4),
        const _ViewHeader(
          title: 'Xác minh email',
          subtitle:
              'Nhập mã 8 chữ số chúng tôi vừa gửi qua email để kích hoạt tài khoản.',
        ),
        const SizedBox(height: 22),
        _authField(
          label: 'Email',
          ctrl: _verifyEmailCtrl,
          hint: 'ban@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Mã xác minh'),
        const SizedBox(height: 8),
        _OtpBoxes(controller: _verifyCodeCtrl, length: 8),
        const SizedBox(height: 22),
        _primaryButton(
          label: 'Xác nhận mã',
          onTap: _isLoading ? null : _doVerifyEmail,
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : _doResendEmail,
            child: const Text(
              'Gửi lại mã',
              style: TextStyle(
                fontSize: 13,
                color: _kMuted,
                decoration: TextDecoration.underline,
                decorationColor: _kMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotView() {
    final isCodeStep = _forgotStep == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBackRow(onTap: () => _switchView(_AuthView.login)),
        const SizedBox(height: 4),
        _ViewHeader(
          title: isCodeStep ? 'Nhập mã xác minh' : 'Đặt lại mật khẩu',
          subtitle: isCodeStep
              ? 'Nhập mã 8 chữ số chúng tôi vừa gửi. Mã đúng sẽ gửi liên kết đặt lại mật khẩu về email.'
              : 'Nhập email đã đăng ký — chúng tôi kiểm tra rồi gửi mã 8 chữ số về hộp thư.',
        ),
        const SizedBox(height: 22),
        _authField(
          label: 'Email',
          ctrl: _forgotEmailCtrl,
          hint: 'ban@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        if (isCodeStep) ...[
          const SizedBox(height: 16),
          const _FieldLabel('Mã đặt lại'),
          const SizedBox(height: 8),
          _OtpBoxes(controller: _forgotCodeCtrl, length: 8),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _isLoading ? null : _doSendResetCode,
              child: const Text(
                'Gửi lại mã',
                style: TextStyle(
                  fontSize: 13,
                  color: _kMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: _kMuted,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        _primaryButton(
          label: isCodeStep ? 'Xác nhận mã' : 'Kiểm tra email',
          onTap: _isLoading
              ? null
              : (isCodeStep ? _doResetPassword : _doSendResetCode),
        ),
        if (!isCodeStep) ...[
          const SizedBox(height: 16),
          const Text(
            'Chưa có tài khoản? Tạo tài khoản mới ở màn đăng ký.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
        ],
      ],
    );
  }

  /// Nút back nhỏ phía trên các view phụ (verify / forgot).
  Widget _buildBackRow({required VoidCallback onTap}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: _kField,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_rounded, size: 18, color: _kText),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets dùng chung
  // ---------------------------------------------------------------------------

  /// Input style Stratis: ô cao 50, nền xám nhạt bo 12, không viền; khi focus
  /// viền xanh lá 1.5px. Label nhỏ đậm ở trên.
  Widget _authField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    int? maxLength,
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
          cursorColor: _kAccent,
          inputFormatters: maxLength != null
              ? [LengthLimitingTextInputFormatter(maxLength)]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: _kMuted),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: _kField,
            isDense: true,
            constraints: const BoxConstraints(minHeight: 50),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kAccent, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
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
        color: value ? _kAccent : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: value ? _kAccent : _kBorder,
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }

  /// Nút chính: pill, xanh lá đặc, shadow xanh nhạt — giống Stratis CTA.
  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isLoading
              ? _kAccent.withValues(alpha: 0.55)
              : _kAccent.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  /// Nút Google: pill outline, icon "G" màu Google.
  Widget _googleButton({VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata_rounded,
                color: Color(0xFF4285F4), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Tiếp tục với Google',
              style: TextStyle(
                color: _kText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dòng "hoặc" với 2 gạch ngang.
  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(
            child: Divider(color: _kBorder, thickness: 1, height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'hoặc',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ),
        const Expanded(
            child: Divider(color: _kBorder, thickness: 1, height: 1)),
      ],
    );
  }
}

/// Nhãn phía trên input (dùng chung với _authField).
class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: _kText));
  }
}

/// 8 ô vuông nhập mã theo theme: ô nền xám nhạt bo 12, khi focus viền xanh lá;
/// nhập số bằng bàn phím ở mọi nền tảng, chạm vào ô nào cũng focus vào input.
class _OtpBoxes extends StatefulWidget {
  final TextEditingController controller;
  final int length;

  const _OtpBoxes({required this.controller, this.length = 8});

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCtrl);
    _focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrl);
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  /// Giữ nội dung chỉ là chữ số, tối đa [widget.length].
  void _sanitize(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    if (trimmed != widget.controller.text) {
      widget.controller.text = trimmed;
      widget.controller.selection =
          TextSelection.collapsed(offset: trimmed.length);
    }
  }

  String get _text => widget.controller.text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++)
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i == widget.length - 1 ? 0 : 8),
                  child: _box(
                    digit: i < _text.length ? _text[i] : '',
                    active: _focused && i >= _text.length,
                  ),
                ),
              ),
          ],
        ),
        // Input thật đè lên toàn bộ nhưng hoàn toàn trong suốt — mọi thao tác
        // chạm/keyboard đều rơi vào đây, nội dung hiển thị qua các ô phía dưới.
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            onChanged: _sanitize,
            enableInteractiveSelection: false,
            showCursor: false,
            cursorColor: Colors.transparent,
            obscureText: false,
            style: const TextStyle(fontSize: 16, color: Colors.transparent),
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _box({required String digit, required bool active}) {
    const boxHeight = 52.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.white : _kField,
        borderRadius: BorderRadius.circular(12),
        // Chỉ gạch DƯỚI ở ô đang nhập (không viền trên — tránh "gạch ngang").
        border: Border(
          bottom: BorderSide(
            color: active ? _kAccent : Colors.transparent,
            width: 2.5,
          ),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _kText,
        ),
      ),
    );
  }
}

/// Tiêu đề + mô tả của từng view phụ (verify / forgot).
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _kText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}
