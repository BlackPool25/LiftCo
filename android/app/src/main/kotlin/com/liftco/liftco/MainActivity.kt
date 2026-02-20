package com.liftco.liftco

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.UUID

class MainActivity : FlutterActivity() {
	private val channelName = "com.liftco.ibeacon"

	private var advertiser: BluetoothLeAdvertiser? = null
	private var advertiseCallback: AdvertiseCallback? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"getSupport" -> {
					result.success(getSupport())
				}

				"start" -> {
					val uuidStr = call.argument<String>("uuid")
					val major = call.argument<Int>("major")
					val minor = call.argument<Int>("minor")
					val txPower = call.argument<Int>("tx_power") ?: -59

					if (uuidStr.isNullOrBlank() || major == null || minor == null) {
						result.error("bad_args", "uuid/major/minor required", null)
						return@setMethodCallHandler
					}

					try {
						startAdvertising(uuidStr, major, minor, txPower)
						result.success(null)
					} catch (e: SecurityException) {
						result.error("no_permission", e.message, null)
					} catch (e: Exception) {
						result.error("start_failed", e.message, null)
					}
				}

				"stop" -> {
					try {
						stopAdvertising()
						result.success(null)
					} catch (e: Exception) {
						result.error("stop_failed", e.message, null)
					}
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun getSupport(): Map<String, Any?> {
		val mgr = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
		val adapter = mgr.adapter
		val isBluetoothOn = adapter?.isEnabled == true
		val isSupported = adapter != null
		val advAvailable = adapter?.bluetoothLeAdvertiser != null

		val details = when {
			adapter == null -> "Bluetooth adapter not found"
			!isBluetoothOn -> "Bluetooth is off"
			!advAvailable -> "Bluetooth LE advertising not supported"
			else -> null
		}

		return mapOf(
			"platform" to "android",
			"is_supported" to isSupported,
			"bluetooth_on" to isBluetoothOn,
			"advertising_available" to advAvailable,
			"details" to details,
		)
	}

	private fun startAdvertising(uuidStr: String, major: Int, minor: Int, txPower: Int) {
		val mgr = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
		val adapter: BluetoothAdapter = mgr.adapter ?: throw IllegalStateException("Bluetooth adapter not found")
		if (!adapter.isEnabled) throw IllegalStateException("Bluetooth is off")

		advertiser = adapter.bluetoothLeAdvertiser
			?: throw IllegalStateException("BLE advertising not supported")

		// Stop any previous advertisement.
		stopAdvertising()

		val uuid = UUID.fromString(uuidStr)
		val majorClamped = major.coerceIn(0, 0xFFFF)
		val minorClamped = minor.coerceIn(0, 0xFFFF)
		val tx = txPower.coerceIn(-127, 127).toByte()

		// iBeacon manufacturer payload (Apple company ID 0x004C):
		// 0x02 0x15 + UUID(16) + major(2) + minor(2) + txPower(1)
		val payload = ByteArray(2 + 16 + 2 + 2 + 1)
		payload[0] = 0x02
		payload[1] = 0x15

		val bb = ByteBuffer.wrap(payload)
		bb.position(2)
		bb.putLong(uuid.mostSignificantBits)
		bb.putLong(uuid.leastSignificantBits)
		bb.putShort(majorClamped.toShort())
		bb.putShort(minorClamped.toShort())
		bb.put(tx)

		val settings = AdvertiseSettings.Builder()
			.setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
			.setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
			.setConnectable(false)
			.build()

		val data = AdvertiseData.Builder()
			.setIncludeDeviceName(false)
			.addManufacturerData(0x004C, payload)
			.build()

		val callback = object : AdvertiseCallback() {
			override fun onStartFailure(errorCode: Int) {
				super.onStartFailure(errorCode)
				// Keep callback so we can stop, but nothing else to do here.
			}
		}

		advertiseCallback = callback
		advertiser?.startAdvertising(settings, data, callback)
	}

	private fun stopAdvertising() {
		val adv = advertiser
		val cb = advertiseCallback
		if (adv != null && cb != null) {
			try {
				adv.stopAdvertising(cb)
			} catch (_: Exception) {
				// ignore
			}
		}
		advertiseCallback = null
	}
}
