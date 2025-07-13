// File: android/app/src/main/kotlin/com/example/primejet_mobile/MainActivity.kt

package com.example.primejet_mobile // Ensure this matches your package name

import io.flutter.embedding.android.FlutterActivity // OPay SDK does not strictly require FlutterFragmentActivity, FlutterActivity is default and often sufficient.
import io.flutter.embedding.engine.FlutterEngine
// Ensure no other payment SDK native imports or custom MethodChannel setup here.

class MainActivity : FlutterActivity() { // Use FlutterActivity as base class
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // No OPay SDK initialization or MethodChannel setup here;
        // OPay Flutter SDK handles this directly.
    }
    // Remove any lingering onActivityResult or helper methods here.
}