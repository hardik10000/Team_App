import 'package:flutter_test/flutter_test.dart';
import 'package:pay_circle/utils/validators.dart';

void main() {
  group('Validators Test Suite', () {
    group('validateName', () {
      test('should return error for empty name', () {
        expect(Validators.validateName(null), 'Name cannot be empty');
        expect(Validators.validateName(''), 'Name cannot be empty');
      });

      test('should return error for name less than 2 characters', () {
        expect(Validators.validateName('A'), 'Name must be at least 2 characters');
      });

      test('should return error for name more than 50 characters', () {
        final longName = 'A' * 51;
        expect(Validators.validateName(longName), 'Name cannot exceed 50 characters');
      });

      test('should return null for valid name', () {
        expect(Validators.validateName('John Doe'), null);
      });
    });

    group('validatePin', () {
      test('should return error for empty pin', () {
        expect(Validators.validatePin(null), 'PIN cannot be empty');
        expect(Validators.validatePin(''), 'PIN cannot be empty');
      });

      test('should return error for pin not exactly 4 digits', () {
        expect(Validators.validatePin('123'), 'PIN must be exactly 4 digits');
        expect(Validators.validatePin('12345'), 'PIN must be exactly 4 digits');
      });

      test('should return error for non-digit pin', () {
        expect(Validators.validatePin('12a4'), 'PIN must contain only digits');
      });

      test('should return null for valid pin', () {
        expect(Validators.validatePin('1234'), null);
      });
    });

    group('validateGroupCode', () {
      test('should return error for empty group code', () {
        expect(Validators.validateGroupCode(null), 'Group code cannot be empty');
        expect(Validators.validateGroupCode(''), 'Group code cannot be empty');
      });

      test('should return error for group code not exactly 6 characters', () {
        expect(Validators.validateGroupCode('ABCDE'), 'Group code must be 6 characters');
        expect(Validators.validateGroupCode('ABCDEFG'), 'Group code must be 6 characters');
      });

      test('should return error for lowercase letters or special characters', () {
        expect(
          Validators.validateGroupCode('abc123'),
          'Group code must contain only uppercase letters and numbers',
        );
        expect(
          Validators.validateGroupCode('AB-123'),
          'Group code must contain only uppercase letters and numbers',
        );
      });

      test('should return null for valid group code', () {
        expect(Validators.validateGroupCode('ABC123'), null);
      });
    });
  });
}
