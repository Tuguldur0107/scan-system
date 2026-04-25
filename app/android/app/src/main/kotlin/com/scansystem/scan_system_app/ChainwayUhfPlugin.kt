package com.scansystem.scan_system_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import com.rscja.deviceapi.RFIDWithUHFUART
import com.rscja.deviceapi.entity.UHFTAGInfo
import com.rscja.deviceapi.interfaces.IUHFInventoryCallback
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Flutter plugin that exposes the Chainway UHF (`RFIDWithUHFUART`) API
 * over a MethodChannel + EventChannel pair.
 *
 *  - MethodChannel  `chainway_uhf/method`  — init / free / start / stop / setPower / ...
 *  - EventChannel   `chainway_uhf/events`  — realtime tag stream + hardware key events
 *
 * Hardware scan-trigger `KeyEvent`s are forwarded from [MainActivity] via
 * [onScanKey]; pressing any of the Chainway side keys (139, 280, 291, 293,
 * 294, 311, 312, 313, 315) will emit a `{type: "key", action: "down"|"up"}`
 * event that the Flutter layer can observe.
 */
class ChainwayUhfPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "ChainwayUhfPlugin"
        private const val METHOD_CHANNEL = "chainway_uhf/method"
        private const val EVENT_CHANNEL = "chainway_uhf/events"

        /** Hardware scan-trigger key codes the Chainway C5 family exposes. */
        private val SCAN_KEYS = setOf(
            139, 280, 291, 293, 294, 311, 312, 313, 315,
        )

        fun isScanKey(keyCode: Int): Boolean = SCAN_KEYS.contains(keyCode)

        @Volatile
        private var instance: ChainwayUhfPlugin? = null

        /** Forward a hardware scan key event to the active plugin instance. */
        fun onScanKey(event: KeyEvent): Boolean {
            val plugin = instance ?: return false
            if (!isScanKey(event.keyCode)) return false
            val action = when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (event.repeatCount != 0) return true
                    "down"
                }
                KeyEvent.ACTION_UP -> "up"
                else -> return false
            }
            plugin.dispatchKeyEvent(event.keyCode, action)
            return true
        }
    }

    private lateinit var appContext: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    @Volatile private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bgExecutor = Executors.newSingleThreadExecutor()

    @Volatile private var reader: RFIDWithUHFUART? = null
    @Volatile private var isInventoryRunning: Boolean = false

    // ───────────────────────────── plugin lifecycle ─────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
        instance = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        stopInventoryInternal()
        freeReaderInternal()
        if (instance === this) instance = null
    }

    // ───────────────────────────── EventChannel ─────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ───────────────────────────── MethodChannel ─────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(trySupported())
            "init" -> initReader(result)
            "free" -> freeReader(result)
            "startInventory" -> startInventory(result)
            "stopInventory" -> stopInventory(result)
            "singleRead" -> singleRead(result)
            "setPower" -> {
                val power = (call.argument<Int>("power") ?: 20).coerceIn(5, 33)
                setPower(power, result)
            }
            "getPower" -> getPower(result)
            "getVersion" -> getVersion(result)
            else -> result.notImplemented()
        }
    }

    private fun trySupported(): Boolean = try {
        Class.forName("com.rscja.deviceapi.RFIDWithUHFUART")
        true
    } catch (_: Throwable) {
        false
    }

    private fun initReader(result: MethodChannel.Result) {
        bgExecutor.execute {
            try {
                if (reader == null) {
                    reader = RFIDWithUHFUART.getInstance()
                }
                val r = reader
                if (r == null) {
                    postResult(result, success = false, error = "getInstance returned null")
                    return@execute
                }
                val ok = r.init(appContext)
                postResult(result, success = ok, error = if (ok) null else "init returned false")
            } catch (t: Throwable) {
                Log.e(TAG, "init error", t)
                postResult(result, success = false, error = t.message ?: t.javaClass.simpleName)
            }
        }
    }

    private fun freeReader(result: MethodChannel.Result) {
        bgExecutor.execute {
            stopInventoryInternal()
            freeReaderInternal()
            mainHandler.post { result.success(true) }
        }
    }

    private fun freeReaderInternal() {
        try {
            reader?.free()
        } catch (t: Throwable) {
            Log.w(TAG, "free failed", t)
        }
        reader = null
    }

    private fun startInventory(result: MethodChannel.Result) {
        val r = reader
        if (r == null) {
            result.error("not_initialized", "Reader is not initialized", null)
            return
        }
        if (isInventoryRunning) {
            result.success(true)
            return
        }

        bgExecutor.execute {
            try {
                r.setInventoryCallback(object : IUHFInventoryCallback {
                    override fun callback(info: UHFTAGInfo?) {
                        if (info == null) return
                        val epc = info.epc ?: return
                        if (epc.isEmpty()) return

                        val payload = hashMapOf<String, Any?>(
                            "type" to "tag",
                            "epc" to epc,
                            "rssi" to (info.rssi ?: ""),
                            "count" to info.count,
                            "tid" to info.tid,
                            "user" to info.user,
                            "reserved" to info.reserved,
                            "phase" to info.phase,
                        )
                        postEvent(payload)
                    }
                })
                val started = r.startInventoryTag()
                mainHandler.post {
                    if (started) {
                        isInventoryRunning = true
                        result.success(true)
                    } else {
                        result.error(
                            "start_failed",
                            "startInventoryTag returned false",
                            null,
                        )
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "startInventory error", t)
                mainHandler.post {
                    result.error("start_error", t.message ?: t.javaClass.simpleName, null)
                }
            }
        }
    }

    private fun stopInventory(result: MethodChannel.Result) {
        bgExecutor.execute {
            val ok = stopInventoryInternal()
            mainHandler.post { result.success(ok) }
        }
    }

    private fun stopInventoryInternal(): Boolean {
        val r = reader ?: return false
        return try {
            val ok = if (isInventoryRunning) r.stopInventory() else true
            r.setInventoryCallback(null)
            isInventoryRunning = false
            ok
        } catch (t: Throwable) {
            Log.w(TAG, "stopInventory failed", t)
            isInventoryRunning = false
            false
        }
    }

    private fun singleRead(result: MethodChannel.Result) {
        bgExecutor.execute {
            val r = reader
            if (r == null) {
                mainHandler.post {
                    result.error("not_initialized", "Reader is not initialized", null)
                }
                return@execute
            }
            try {
                val info = r.inventorySingleTag()
                if (info == null) {
                    mainHandler.post { result.success(null) }
                } else {
                    val payload = hashMapOf<String, Any?>(
                        "epc" to info.epc,
                        "rssi" to info.rssi,
                        "count" to info.count,
                        "tid" to info.tid,
                        "user" to info.user,
                        "reserved" to info.reserved,
                        "phase" to info.phase,
                    )
                    mainHandler.post { result.success(payload) }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "singleRead error", t)
                mainHandler.post { result.error("single_read_error", t.message, null) }
            }
        }
    }

    private fun setPower(power: Int, result: MethodChannel.Result) {
        val r = reader
        if (r == null) {
            result.error("not_initialized", "Reader is not initialized", null)
            return
        }
        bgExecutor.execute {
            try {
                val ok = r.setPower(power)
                mainHandler.post { result.success(ok) }
            } catch (t: Throwable) {
                Log.e(TAG, "setPower error", t)
                mainHandler.post { result.error("set_power_error", t.message, null) }
            }
        }
    }

    private fun getPower(result: MethodChannel.Result) {
        val r = reader
        if (r == null) {
            result.error("not_initialized", "Reader is not initialized", null)
            return
        }
        bgExecutor.execute {
            try {
                val p = r.power
                mainHandler.post { result.success(p) }
            } catch (t: Throwable) {
                Log.e(TAG, "getPower error", t)
                mainHandler.post { result.error("get_power_error", t.message, null) }
            }
        }
    }

    private fun getVersion(result: MethodChannel.Result) {
        val r = reader
        if (r == null) {
            result.error("not_initialized", "Reader is not initialized", null)
            return
        }
        bgExecutor.execute {
            try {
                val sw = try { r.version } catch (_: Throwable) { null }
                val hw = try { r.hardwareVersion } catch (_: Throwable) { null }
                mainHandler.post {
                    result.success(
                        hashMapOf(
                            "software" to (sw ?: ""),
                            "hardware" to (hw ?: ""),
                        ),
                    )
                }
            } catch (t: Throwable) {
                Log.e(TAG, "getVersion error", t)
                mainHandler.post { result.error("version_error", t.message, null) }
            }
        }
    }

    // ───────────────────────────── helpers ─────────────────────────────

    private fun postResult(
        result: MethodChannel.Result,
        success: Boolean,
        error: String? = null,
    ) {
        mainHandler.post {
            if (success) {
                result.success(true)
            } else {
                result.error("init_failed", error ?: "Unknown error", null)
            }
        }
    }

    private fun postEvent(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.success(payload)
            } catch (_: Throwable) {
                // sink may be closed; ignore
            }
        }
    }

    /** Called by [MainActivity] via [onScanKey]. */
    internal fun dispatchKeyEvent(keyCode: Int, action: String) {
        postEvent(
            mapOf(
                "type" to "key",
                "keyCode" to keyCode,
                "action" to action,
            ),
        )
    }
}
