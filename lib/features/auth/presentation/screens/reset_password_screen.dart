import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/main_shell.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_service.dart';

const Color _kAccent = AppColors.iosPrimary;
const Color _kText = Color(0xFF1A1A2E);
const Color _kMuted = Color(0xFF6B7280);
const Color _kField = Color(0xFFF6F7F9);
const Color _kBorder = Color(0xFFE8EAED);

/// Màn hình đặt lại mật khẩu — hệ thống reset hiện dùng MÃ 8 CHỮ SỐ.
///
/// Luồng (hợp đồng mới với `/api/reset_password`): bước 1 màn "Quên mật
/// khẩu" gửi mã về email (không còn email link/oobCode kiểu Firebase);
/// màn này là bước 2 — nhập mã + mật khẩu mới, server xác thực mã và đặt
/// mật khẩu thẳng qua admin API Supabase, app tự đăng nhập lại bằng mật
/// khẩu vừa đặt và vào thẳng Home.
///
/// Link reset kiểu cũ của Firebase (`?mode=resetPassword&oobCode=...`) vẫn
/// có thể được bấm: main.dart chuyển sang màn này với email có sẵn — người
/// dùng (oobCode bị bỏ qua) — người dùng nhập mã 8 chữ số như màn đăng nhập,
class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
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
        backgroundColor: isSuccess ? _kAccent : AppColors.iosError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _doSetPassword() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final pw = _pwCtrl.text;
    final confirm = _confirmCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Vui lòng nhập email đã đăng ký.', false);
      return;
    }
    if (code.length != 8) {
      _showMessage('Vui lòng nhập đủ mã 8 chữ số.', false);
      return;
    }
    if (pw.length < 6) {
      _showMessage('Mật khẩu phải có ít nhất 6 ký tự.', false);
      return;
    }
    if (pw != confirm) {
      _showMessage('Mật khẩu xác nhận không khớp!', false);
      return;
    }
    setState(() => _loading = true);
    final result = await AuthService.resetPasswordByCode(
      email: email,
      code: code,
      newPassword: pw,
    );
    if (!mounted) return;
    if (result.success) {
      // AuthService đã tự đăng nhập lại bằng mật khẩu mới — vào thẳng Home.
      setState(() => _loading = false);
      _showMessage(result.message, true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
        (route) => false,
      );
      return;
    }
    setState(() => _loading = false);
    _showMessage(result.message, false);
  }

  // ---------------------------------------------------------------------------
  // UI
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
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _kBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _kBorder, width: 1),
                        ),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Đặt mật khẩu mới',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nhập mã 8 chữ số đã gửi qua email của bạn để đặt mật khẩu mới.\n'
                        'Chưa có mã? Quay lại màn đăng nhập, chọn "Quên mật khẩu".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: _kMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _field(
                        label: 'Email',
                        ctrl: _emailCtrl,
                        hint: 'ban@email.com',
                        keyboard: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      const Text('Mã đặt lại',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kText)),
                      const SizedBox(height: 8),
                      _OtpBoxes(controller: _codeCtrl, length: 8),
                      const SizedBox(height: 16),
                      _field(
                        label: 'Mật khẩu mới',
                        ctrl: _pwCtrl,
                        hint: 'Tối thiểu 6 ký tự',
                        obscure: _obscurePw,
                        onToggle: () =>
                            setState(() => _obscurePw = !_obscurePw),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        label: 'Xác nhận mật khẩu',
                        ctrl: _confirmCtrl,
                        hint: 'Nhập lại mật khẩu mới',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _loading ? null : _doSetPassword,
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _loading
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
                          child: _loading
                              ? const CupertinoActivityIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Đặt lại mật khẩu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sau khi đặt xong, bạn sẽ được đăng nhập ngay vào tích lũy EduPulse.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5, height: 1.4, color: _kMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType keyboard = TextInputType.text,
  }) {
    final suffix = onToggle == null
        ? null
        : GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
              color: _kMuted,
            ),
          );
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
}

/// 8 ô vuông nhập mã (giống màn Auth): ô nền xám nhạt bo 12, khi focus viền
/// xanh lá; input thật trong suốt đè lên để bắt mọi thao tác chạm/bàn phím.
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
