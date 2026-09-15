import 'dart:js_interop';

@JS('sigoQueue')
external JSPromise<JSString> _queue(JSString action, JSString input);
Future<String> queueStore(String action, String input) async =>
    (await _queue(action.toJS, input.toJS).toDart).toDart;
