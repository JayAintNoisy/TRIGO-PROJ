import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/utils/phone_actions.dart';

/// Number normalisation for the Call / Text handoff.
///
/// The launch itself needs a platform channel, so only the sanitising is
/// covered here; the call sites are stubbed where the UI is tested.
void main() {
  group('PhoneActions.sanitize', () {
    test('normalises the usual Philippine formats to E.164', () {
      expect(PhoneActions.sanitize('09171112222'), '+639171112222');
      expect(PhoneActions.sanitize('0917 111 2222'), '+639171112222');
      expect(PhoneActions.sanitize('0917-111-2222'), '+639171112222');
      expect(PhoneActions.sanitize('+63 917 111 2222'), '+639171112222');
      expect(PhoneActions.sanitize('639171112222'), '+639171112222');
      expect(PhoneActions.sanitize('9171112222'), '+639171112222');
    });

    test('keeps an already international number untouched', () {
      expect(PhoneActions.sanitize('+1 415 555 0100'), '+14155550100');
    });

    test('returns empty for blank or unusable input', () {
      expect(PhoneActions.sanitize(''), '');
      expect(PhoneActions.sanitize('   '), '');
      expect(PhoneActions.sanitize('not a number'), '');
      expect(PhoneActions.sanitize('---'), '');
    });
  });

  group('PhoneActions launch guards', () {
    test('refuses to launch without a usable number', () async {
      expect(await PhoneActions.placeCall(''), isFalse);
      expect(await PhoneActions.sendSms('   '), isFalse);
      expect(await PhoneActions.placeCall('no digits here'), isFalse);
    });
  });
}
