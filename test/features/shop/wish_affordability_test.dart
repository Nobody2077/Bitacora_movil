import 'package:bitacora_rpg_personal/features/shop/domain/models/wish_affordability.dart';
import 'package:flutter_test/flutter_test.dart';

WishAffordability _evaluate(int? price, int available) =>
    WishAffordability.evaluate(priceMinor: price, availableMinor: available);

void main() {
  test('sin precio no se compara', () {
    final WishAffordability result = _evaluate(null, 50000);

    expect(result.level, WishAffordabilityLevel.unpriced);
    expect(result.missingMinor, 0);
  });

  test('justo el 100 % alcanza', () {
    final WishAffordability result = _evaluate(40000, 40000);

    expect(result.level, WishAffordabilityLevel.affordable);
    expect(result.isAffordable, isTrue);
    expect(result.missingMinor, 0);
  });

  test('más saldo que precio alcanza', () {
    expect(_evaluate(40000, 90000).level, WishAffordabilityLevel.affordable);
  });

  test('justo el 75 % es «falta poco» y dice cuánto falta', () {
    final WishAffordability result = _evaluate(40000, 30000);

    expect(result.level, WishAffordabilityLevel.close);
    expect(result.missingMinor, 10000);
  });

  test('un céntimo por debajo del 75 % es «falta mucho»', () {
    final WishAffordability result = _evaluate(40000, 29999);

    expect(result.level, WishAffordabilityLevel.far);
    expect(result.missingMinor, 10001);
  });

  test('un céntimo por debajo del precio sigue siendo «falta poco»', () {
    final WishAffordability result = _evaluate(40000, 39999);

    expect(result.level, WishAffordabilityLevel.close);
    expect(result.missingMinor, 1);
  });

  test('un saldo negativo falta mucho y cuenta lo que debe', () {
    final WishAffordability result = _evaluate(40000, -5000);

    expect(result.level, WishAffordabilityLevel.far);
    expect(result.missingMinor, 45000);
  });
}
