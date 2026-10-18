import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse/shared/widgets/mascot_avatar.dart';

void main() {
  // Đặt avatar đúng như context thật: góc trái màn hình (trong HomeHeader),
  // để bubble Positioned có không gian vẽ sang phải như khi chạy thật.
  Widget wrap() => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 20,
                top: 40,
                child: MascotAvatar(
                  size: 56,
                  // Tắt phần Row "Chạm để mở góc tâm tình" trong bubble: Row đó
                  // có sẵn lỗi overflow khi render standalone (không thuộc
                  // phạm vi fix này), còn phần cần kiểm chứng là bubble
                  // THÔNG / TẮT theo timer.
                  enableCompanionModal: false,
                ),
              ),
            ],
          ),
        ),
      );

  // Bubble thoại của mascot được vẽ `Positioned` đè lên nội dung kế bên
  // (vị trí đặc thù của speech bubble), nên nếu đứng vĩnh viễn nó sẽ che
  // chữ trên header và người dùng không có cách nào đóng ngoài chạm lại
  // mascot. Yêu cầu: hiện đủ nhịp đọc (~6s) rồi tự thả màn.
  testWidgets('Bubble quote tự tắt sau nhịp đọc, không đè vĩnh viễn',
      (tester) async {
    await tester.pumpWidget(wrap());

    // Ban đầu chưa có bubble.
    expect(find.byKey(const ValueKey('mascot-quote-bubble')), findsNothing);

    // Chạm mascot → bubble hiện.
    await tester.tap(find.byType(MascotAvatar));
    await tester.pump();
    expect(find.byKey(const ValueKey('mascot-quote-bubble')), findsOneWidget);

    // Quá nhịp đọc (6s) → bubble tự tắt.
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('mascot-quote-bubble')), findsNothing);
  });

  testWidgets('Bubble không tắt trước 6 giây', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.byType(MascotAvatar));
    await tester.pump();

    // Chỉ 3 giây — bubble phải vẫn còn.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('mascot-quote-bubble')), findsOneWidget);
  });
}
