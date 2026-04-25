package com.scansystem.scan_system_app

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(ChainwayUhfPlugin())
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Intercept Chainway hardware scan-trigger keys and forward them to
        // the UHF plugin so the Flutter layer can react in real time. Other
        // key events fall through to the default handling (soft keyboard,
        // volume buttons, etc.).
        if (ChainwayUhfPlugin.isScanKey(event.keyCode)) {
            ChainwayUhfPlugin.onScanKey(event)
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
