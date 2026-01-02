// BioRhythmEngine 单元测试
// 
// 测试覆盖：
// - 各时段 laziness 计算正确性
// - lerp 过渡平滑性
// - tolerance 计算逻辑
// - 边界条件

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion/core/engine/bio_rhythm_engine.dart';

void main() {
  late BioRhythmEngine engine;

  setUp(() {
    engine = BioRhythmEngine();
  });

  group('calculateLaziness', () {
    test('日间清醒期 (10:00-22:00) 应返回 0.0', () {
      // 测试多个日间时间点
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 10, 0)), equals(0.0));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 12, 0)), equals(0.0));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 15, 0)), equals(0.0));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 18, 0)), equals(0.0));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 21, 59)), equals(0.0));
    });

    test('极度疲惫期 (01:00-05:00) 应返回 0.9', () {
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 1, 0)), equals(0.9));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 2, 0)), equals(0.9));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 3, 0)), equals(0.9));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 4, 0)), equals(0.9));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 4, 59)), equals(0.9));
    });

    test('疲惫上升期 (22:00-01:00) 应平滑过渡 0.0 -> 0.9', () {
      // 22:00 开始
      final at22h = engine.calculateLaziness(DateTime(2024, 1, 1, 22, 0));
      expect(at22h, closeTo(0.0, 0.05));
      
      // 23:30 应约在中间
      final at2330 = engine.calculateLaziness(DateTime(2024, 1, 1, 23, 30));
      expect(at2330, greaterThan(0.3));
      expect(at2330, lessThan(0.7));
      
      // 00:30 应接近峰值
      final at0030 = engine.calculateLaziness(DateTime(2024, 1, 2, 0, 30));
      expect(at0030, greaterThan(0.6));
    });

    test('清醒恢复期 (05:00-08:00) 应平滑过渡 0.9 -> 0.0', () {
      // 05:00 开始
      final at05h = engine.calculateLaziness(DateTime(2024, 1, 1, 5, 0));
      expect(at05h, closeTo(0.9, 0.05));
      
      // 06:30 应约在中间
      final at0630 = engine.calculateLaziness(DateTime(2024, 1, 1, 6, 30));
      expect(at0630, greaterThan(0.3));
      expect(at0630, lessThan(0.7));
      
      // 08:00 应接近清醒
      final at08h = engine.calculateLaziness(DateTime(2024, 1, 1, 8, 0));
      expect(at08h, closeTo(0.0, 0.05));
    });

    test('早间清醒期 (08:00-10:00) 应返回 0.0', () {
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 8, 0)), closeTo(0.0, 0.05));
      expect(engine.calculateLaziness(DateTime(2024, 1, 1, 9, 0)), equals(0.0));
    });

    test('过渡应保持连续性（无突变）', () {
      // 检查22:00附近的连续性
      final before22 = engine.calculateLaziness(DateTime(2024, 1, 1, 21, 59));
      final at22 = engine.calculateLaziness(DateTime(2024, 1, 1, 22, 0));
      expect((at22 - before22).abs(), lessThan(0.1));
      
      // 检查05:00附近的连续性
      final before05 = engine.calculateLaziness(DateTime(2024, 1, 1, 4, 59));
      final at05 = engine.calculateLaziness(DateTime(2024, 1, 1, 5, 0));
      expect((at05 - before05).abs(), lessThan(0.1));
    });

    test('所有返回值应在 [0.0, 0.9] 范围内', () {
      for (int hour = 0; hour < 24; hour++) {
        for (int minute = 0; minute < 60; minute += 15) {
          final laziness = engine.calculateLaziness(DateTime(2024, 1, 1, hour, minute));
          expect(laziness, greaterThanOrEqualTo(0.0));
          expect(laziness, lessThanOrEqualTo(0.9));
        }
      }
    });
  });

  group('calculateTolerance', () {
    test('laziness=0 应返回 tolerance=1.0', () {
      final tolerance = engine.calculateTolerance(laziness: 0.0);
      expect(tolerance, equals(1.0));
    });

    test('laziness=0.9 应返回 tolerance=0.1', () {
      final tolerance = engine.calculateTolerance(laziness: 0.9);
      expect(tolerance, closeTo(0.1, 0.01));
    });

    test('comfort 需求应降低 tolerance 0.2', () {
      final base = engine.calculateTolerance(laziness: 0.5);
      final withComfort = engine.calculateTolerance(laziness: 0.5, needType: 'comfort');
      expect(withComfort, equals(base - 0.2));
    });

    test('vent 需求应降低 tolerance 0.2', () {
      final base = engine.calculateTolerance(laziness: 0.5);
      final withVent = engine.calculateTolerance(laziness: 0.5, needType: 'vent');
      expect(withVent, equals(base - 0.2));
    });

    test('重复话题应降低 tolerance 0.2', () {
      final base = engine.calculateTolerance(laziness: 0.5);
      final withRepeat = engine.calculateTolerance(laziness: 0.5, sameTopicRepeated: true);
      expect(withRepeat, equals(base - 0.2));
    });

    test('多重因素叠加', () {
      // laziness=0.6 -> base tolerance = 0.4
      // comfort -> -0.2
      // repeated -> -0.2
      // 结果应为 0.0 (clamp)
      final tolerance = engine.calculateTolerance(
        laziness: 0.6,
        needType: 'comfort',
        sameTopicRepeated: true,
      );
      expect(tolerance, equals(0.0));
    });

    test('tolerance 不应低于 0.0', () {
      final tolerance = engine.calculateTolerance(
        laziness: 0.9,
        needType: 'comfort',
        sameTopicRepeated: true,
      );
      expect(tolerance, equals(0.0));
    });
  });

  group('getTimePhaseDescription', () {
    test('应返回正确的时段描述', () {
      expect(engine.getTimePhaseDescription(DateTime(2024, 1, 1, 12, 0)), equals('日间清醒期'));
      expect(engine.getTimePhaseDescription(DateTime(2024, 1, 1, 23, 0)), equals('疲惫上升期'));
      expect(engine.getTimePhaseDescription(DateTime(2024, 1, 1, 3, 0)), equals('极度疲惫期'));
      expect(engine.getTimePhaseDescription(DateTime(2024, 1, 1, 6, 0)), equals('清醒恢复期'));
      expect(engine.getTimePhaseDescription(DateTime(2024, 1, 1, 9, 0)), equals('早间清醒期'));
    });
  });
}
