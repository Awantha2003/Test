// Compile-check stubs mirroring the Flutter embedding API surface the plugin uses.
package io.flutter.plugin.common
interface BinaryMessenger
class MethodCall(val method: String, val arguments: Any?)
class MethodChannel(messenger: BinaryMessenger, name: String) {
    interface Result { fun success(result: Any?); fun error(code: String, message: String?, details: Any?); fun notImplemented() }
    interface MethodCallHandler { fun onMethodCall(call: MethodCall, result: Result) }
    fun setMethodCallHandler(handler: MethodCallHandler?) {}
}
