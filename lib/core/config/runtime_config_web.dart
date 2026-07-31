import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

String get stripePublishableKey {
  final config = web.window.getProperty<JSAny?>('__GAIA_CONFIG__'.toJS);
  if (config == null || config.isUndefinedOrNull) return '';
  final value = (config as JSObject).getProperty<JSAny?>(
    'STRIPE_PUBLISHABLE_KEY'.toJS,
  );
  final dartValue = value?.dartify();
  return dartValue is String ? dartValue : '';
}
