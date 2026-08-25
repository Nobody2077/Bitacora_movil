import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success ejecuta solamente onSuccess', () {
      const Result<int> result = Success<int>(21);

      final int value = result.fold<int>(
        onSuccess: (int success) => success * 2,
        onFailure: (AppFailure failure) => -1,
      );

      expect(value, 42);
    });

    test('Failure conserva el error tipado', () {
      const AppFailure expected = ValidationFailure('Título obligatorio');
      const Result<int> result = Failure<int>(expected);

      final AppFailure value = result.fold<AppFailure>(
        onSuccess: (int success) =>
            const UnexpectedFailure('No debe ejecutarse'),
        onFailure: (AppFailure failure) => failure,
      );

      expect(value, same(expected));
      expect(value.code, 'validation_failure');
    });
  });
}
