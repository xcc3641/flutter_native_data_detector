package com.starfruitlab.flutter_native_data_detector

import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.entityextraction.Entity
import com.google.mlkit.nl.entityextraction.EntityExtraction
import com.google.mlkit.nl.entityextraction.EntityExtractionParams
import com.google.mlkit.nl.entityextraction.EntityExtractionRemoteModel
import com.google.mlkit.nl.entityextraction.EntityExtractorOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class FlutterNativeDataDetectorPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "flutter_native_data_detector")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val language = call.argument<String>("language") ?: "en"

    when (call.method) {
      "prepareModel" -> prepareModel(language, result)
      "getModelStatus" -> getModelStatus(language, result)
      "detect" -> {
        val text = call.argument<String>("text")
        val types = call.argument<List<String>>("types")
        if (text == null || types == null) {
          result.error("BAD_ARGS", "detect expects {text: String, types: List<String>}", null)
          return
        }
        detect(text, types, language, result)
      }
      else -> result.notImplemented()
    }
  }

  private fun prepareModel(language: String, result: Result) {
    val options = EntityExtractorOptions.Builder(modelIdentifierFor(language)).build()
    val extractor = EntityExtraction.getClient(options)

    extractor.downloadModelIfNeeded()
      .addOnSuccessListener {
        result.success(true)
        extractor.close()
      }
      .addOnFailureListener { e ->
        result.error("MODEL_DOWNLOAD_ERROR", e.message ?: "Failed to download ML Kit model", null)
        extractor.close()
      }
  }

  private fun getModelStatus(language: String, result: Result) {
    val model = EntityExtractionRemoteModel.Builder(modelIdentifierFor(language)).build()

    RemoteModelManager.getInstance().isModelDownloaded(model)
      .addOnSuccessListener { downloaded ->
        result.success(if (downloaded) "ready" else "notDownloaded")
      }
      .addOnFailureListener { e ->
        result.error("MODEL_STATUS_ERROR", e.message ?: "Failed to read ML Kit model status", null)
      }
  }

  private fun detect(text: String, types: List<String>, language: String, result: Result) {
    val options = EntityExtractorOptions.Builder(modelIdentifierFor(language)).build()
    val extractor = EntityExtraction.getClient(options)

    extractor.downloadModelIfNeeded()
      .addOnSuccessListener {
        val params = EntityExtractionParams.Builder(text).build()

        extractor.annotate(params)
          .addOnSuccessListener { annotations ->
            val results = mutableListOf<Map<String, Any>>()

            for (annotation in annotations) {
              for (entity in annotation.entities) {
                val type = mapEntityType(entity) ?: continue
                if (!types.contains(type)) continue

                val data = mutableMapOf<String, String>()
                populateEntityData(entity, type, data, annotation.annotatedText)

                results.add(
                  mapOf(
                    "type" to type,
                    "text" to annotation.annotatedText,
                    "start" to annotation.start,
                    "end" to annotation.end,
                    "data" to data
                  )
                )
                break // One result per annotation
              }
            }

            result.success(results)
            extractor.close()
          }
          .addOnFailureListener { e ->
            result.error("DETECTION_ERROR", e.message ?: "Entity extraction failed", null)
            extractor.close()
          }
      }
      .addOnFailureListener { e ->
        result.error("MODEL_DOWNLOAD_ERROR", e.message ?: "Failed to download ML Kit model", null)
        extractor.close()
      }
  }

  /**
   * Maps an ISO 639-1 language code from Dart to its ML Kit
   * [EntityExtractorOptions] model identifier. Falls back to English for
   * unknown codes so detection still works.
   */
  private fun modelIdentifierFor(language: String): String {
    return when (language) {
      "ar" -> EntityExtractorOptions.ARABIC
      "nl" -> EntityExtractorOptions.DUTCH
      "en" -> EntityExtractorOptions.ENGLISH
      "fr" -> EntityExtractorOptions.FRENCH
      "de" -> EntityExtractorOptions.GERMAN
      "it" -> EntityExtractorOptions.ITALIAN
      "ja" -> EntityExtractorOptions.JAPANESE
      "ko" -> EntityExtractorOptions.KOREAN
      "pl" -> EntityExtractorOptions.POLISH
      "pt" -> EntityExtractorOptions.PORTUGUESE
      "ru" -> EntityExtractorOptions.RUSSIAN
      "es" -> EntityExtractorOptions.SPANISH
      "th" -> EntityExtractorOptions.THAI
      "tr" -> EntityExtractorOptions.TURKISH
      "zh" -> EntityExtractorOptions.CHINESE
      else -> EntityExtractorOptions.ENGLISH
    }
  }

  private fun mapEntityType(entity: Entity): String? {
    return when (entity.type) {
      Entity.TYPE_PHONE -> "phoneNumber"
      Entity.TYPE_URL -> "link"
      Entity.TYPE_EMAIL -> "email"
      Entity.TYPE_ADDRESS -> "address"
      Entity.TYPE_DATE_TIME -> "date"
      else -> null
    }
  }

  private fun populateEntityData(
    entity: Entity,
    type: String,
    data: MutableMap<String, String>,
    annotatedText: String
  ) {
    when (type) {
      "phoneNumber" -> data["phoneNumber"] = annotatedText
      "link" -> data["url"] = annotatedText
      "email" -> data["email"] = annotatedText
      "address" -> data["address"] = annotatedText
      "date" -> {
        entity.asDateTimeEntity()?.let { dateTime ->
          val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
          formatter.timeZone = TimeZone.getTimeZone("UTC")
          data["date"] = formatter.format(Date(dateTime.timestampMillis))
        }
      }
    }
  }
}
