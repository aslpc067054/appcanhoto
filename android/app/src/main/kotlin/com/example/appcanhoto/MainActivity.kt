package com.example.appcanhoto

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "appcanhoto/media_store"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"saveFile" -> {
					val filename = call.argument<String>("filename")
					val bytes = call.argument<ByteArray>("bytes")
					if (filename == null || bytes == null) {
						result.error("INVALID_ARGS", "filename or bytes missing", null)
						return@setMethodCallHandler
					}

					try {
						val resolver = applicationContext.contentResolver
						val values = ContentValues().apply {
							put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
							put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
							if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
								put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
								put(MediaStore.MediaColumns.IS_PENDING, 1)
							}
						}

						val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
							MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
						} else {
							MediaStore.Files.getContentUri("external")
						}

						val uri = resolver.insert(collection, values)
						if (uri != null) {
							resolver.openOutputStream(uri).use { out ->
								out?.write(bytes)
							}
							if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
								val updateValues = ContentValues().apply {
									put(MediaStore.MediaColumns.IS_PENDING, 0)
								}
								resolver.update(uri, updateValues, null, null)
							}
							result.success(uri.toString())
						} else {
							result.error("WRITE_FAILED", "Unable to create file in MediaStore", null)
						}
					} catch (e: Exception) {
						result.error("EXCEPTION", e.localizedMessage, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
