import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/supabase_service.dart';

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

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  final _loginEmailCtrl = TextEditingController();
  final _loginPwCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPwCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPwCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPwCtrl.dispose();
    _regConfirmCtrl.dispose();
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
        backgroundColor: isSuccess ? AppColors.green : AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
        _tabController.animateTo(0);
        _loginEmailCtrl.text = email;
      }
    }
  }

  Future<void> _doResetPassword() async {
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Nhập email trước, sau đó nhấn Quên mật khẩu.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await SupabaseService.resetPassword(email);
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.greenDark,
                          blurRadius: 0,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: const Center(
                      child: Text('🎓', style: TextStyle(fontSize: 44))),
                ),
                const SizedBox(height: 12),
                Text(
                  'EduPulse',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trợ lý Sĩ tử • Đếm ngược Kỳ thi',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textMuted,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                          tabs: const [
                            Tab(text: 'Đăng nhập'),
                            Tab(text: 'Đăng ký'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: _tabController.index == 0 ? 260 : 340,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLoginForm(),
                            _buildRegisterForm(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final isLogin = _tabController.index == 0;
                    return GestureDetector(
                      onTap: _isLoading
                          ? null
                          : (isLogin ? _doLogin : _doRegister),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color:
                              _isLoading ? AppColors.border : AppColors.green,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isLoading
                              ? null
                              : const [
                                  BoxShadow(
                                      color: AppColors.greenDark,
                                      blurRadius: 0,
                                      offset: Offset(0, 4))
                                ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: Colors.white)
                              : Text(
                                  isLogin ? 'ĐĂNG NHẬP' : 'TẠO TÀI KHOẢN',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: widget.onSkip,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: Center(
                      child: Text('Tiếp tục không cần tài khoản',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Chế độ khách: dữ liệu chỉ lưu trên thiết bị.\nĐăng ký để sao lưu & dùng trên nhiều thiết bị.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _authField(
              ctrl: _loginEmailCtrl,
              label: 'Email',
              icon: Icons.email,
              keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _authField(
            ctrl: _loginPwCtrl,
            label: 'Mật khẩu',
            icon: Icons.lock,
            obscure: _obscurePw,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePw = !_obscurePw),
              child: Icon(_obscurePw ? Icons.visibility : Icons.visibility_off,
                  size: 18, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _doResetPassword,
            child: const Text('Quên mật khẩu?',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _authField(
              ctrl: _regNameCtrl, label: 'Tên / Biệt danh', icon: Icons.person),
          const SizedBox(height: 10),
          _authField(
              ctrl: _regEmailCtrl,
              label: 'Email',
              icon: Icons.email,
              keyboard: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _authField(
            ctrl: _regPwCtrl,
            label: 'Mật khẩu (≥6 ký tự)',
            icon: Icons.lock,
            obscure: _obscurePw,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePw = !_obscurePw),
              child: Icon(_obscurePw ? Icons.visibility : Icons.visibility_off,
                  size: 18, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          _authField(
            ctrl: _regConfirmCtrl,
            label: 'Xác nhận mật khẩu',
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                  _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12), child: suffix)
              : null,
          hintText: label,
          hintStyle: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}
