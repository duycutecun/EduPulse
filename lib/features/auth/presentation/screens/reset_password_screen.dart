import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../app/main_shell.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';

const Color _kAccent = AppColors.primary;
const Color _kText = Color(0xFF1A1A2E);
const Color _kMuted = Color(0xFF6B7280);
const Color _kField = Color(0xFFF6F7F9);
const Color _kBorder = Color(0xFFE8EAED);

/// Màn hình đặt mật khẩu mới — mở khi người dùng bấm link reset từ email.
///
/// Link từ Firebase (PASSWORD_RESET) chuyển hướng về app kèm `oobCode` và
/// `mode=resetPassword` trong URL. Màn này nhận oobCode rồi dùng
/// `FirebaseAuth.confirmPasswordReset` để đặt mật khẩu mới, sau đó tự đăng
/// nhập bằng mật khẩu vừa đặt — KHÔNG cần service account Firebase.
class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.oobCode,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
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
        backgroundColor: isSuccess ? _kAccent : AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _doSetPassword() async {
    final pw = _pwCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pw.length < 6) {
      _showMessage('Mật khẩu phải có ít nhất 6 ký tự.', false);
      return;
    }
    if (pw != confirm) {
      _showMessage('Mật khẩu xác nhận không khớp!', false);
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance
          .confirmPasswordReset(code: widget.oobCode, newPassword: pw);
      if (widget.email.isNotEmpty) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: widget.email,
          password: pw,
        );
      }
      // Đã chứng minh quyền sở hữu email qua link reset → coi như đã xác minh.
      StorageService.setEmailVerified(true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(_mapError(e), false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Không đặt lại được mật khẩu. Kiểm tra mạng và thử lại.', false);
    }
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Mật khẩu phải có ít nhất 6 ký tự.';
      case 'expired-action-code':
        return 'Link đặt lại mật khẩu đã hết hạn. Hãy làm lại từ đầu.';
      case 'invalid-action-code':
        return 'Link đặt lại mật khẩu không hợp lệ hoặc đã dùng rồi.';
      case 'user-disabled':
        return 'Tài khoản đã bị khoá. Liên hệ hỗ trợ.';
      case 'user-not-found':
        return 'Tài khoản không tồn tại.';
      default:
        final msg = e.message;
        return (msg != null && msg.isNotEmpty) ? 'Lỗi: $msg' : 'Có lỗi xảy ra.';
    }
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                      Text(
                        'Chào ${widget.email.trim().isEmpty ? 'bạn' : widget.email.trim()}\n'
                        'Liên kết đã xác thực. Nhập mật khẩu mới để tiếp tục.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: _kMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                              ? const CupertinoActivityIndicator(color: Colors.white)
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
                        style: TextStyle(fontSize: 11.5, height: 1.4, color: _kMuted),
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
    required bool obscure,
    required VoidCallback onToggle,
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
          obscureText: obscure,
          style: const TextStyle(fontSize: 14.5, color: _kText),
          cursorColor: _kAccent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: _kMuted),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 19,
                color: _kMuted,
              ),
            ),
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