import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/touch_sampling.dart';

void main() {
  test('采样偏移按刷新率换算为一帧 + 2ms 提前量', () {
    expect(touchSamplingOffset(60).inMicroseconds, -18667);
    expect(touchSamplingOffset(120).inMicroseconds, -10333);
    expect(touchSamplingOffset(144).inMicroseconds, -8944);
  });

  test('异常刷新率回退 60Hz，并限制在 6–20ms', () {
    expect(touchSamplingOffset(0).inMicroseconds, -18667);
    expect(touchSamplingOffset(double.nan).inMicroseconds, -18667);
    expect(touchSamplingOffset(240).inMicroseconds, -6167);
    expect(touchSamplingOffset(30).inMicroseconds, -20000);
  });
}
