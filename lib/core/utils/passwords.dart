import 'dart:convert';

import 'package:crypto/crypto.dart';

const kMinPasswordLength = 8;

String hashLocalPassword(String password, String userId) {
  return sha256
      .convert(utf8.encode('attcontrol|$userId|$password'))
      .toString();
}

String? validatePassword(String password, {required bool required}) {
  final v = password.trim();
  if (v.isEmpty) {
    return required ? 'Contraseña requerida' : null;
  }
  if (v.length < kMinPasswordLength) {
    return 'Mínimo $kMinPasswordLength caracteres';
  }
  return null;
}
