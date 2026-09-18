import 'package:flutter_test/flutter_test.dart';

import 'package:gudangmulyasari/config/auth_config.dart';

void main() {
  test('username maps to gudang domain', () {
    expect(usernameToInternalEmail('Andi'), 'andi@gudangmulyasari.pos');
  });

  test('login input accepts username or email', () {
    expect(isValidLoginInput('owner'), isTrue);
    expect(isValidLoginInput('owner@mulyasari.pos'), isTrue);
    expect(isValidLoginInput('ab'), isFalse);
  });
}
