package com.saadhjawwadh.notebook

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import com.google.mediapipe.tasks.components.containers.Embedding
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder.TextEmbedderOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Native Android MethodChannel handler for Tier 1 on-device semantic embeddings
 * powered by MediaPipe Tasks Text + Universal Sentence Encoder (.tflite).
 */
class LiteRtChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.saadhjawwadh.notebook/litert"
        private const val MODEL_ASSET_PATH = "universal_sentence_encoder.tflite"
        private const val IDLE_TTL_MS = 60_000L
        private const val LABEL_CACHE_SIZE = 256
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val labelEmbeddingCache = LruCache<String, Embedding>(LABEL_CACHE_SIZE)
    private var textEmbedder: TextEmbedder? = null
    private var channel: MethodChannel? = null

    private val closeRunnable = Runnable {
        if (!executor.isShutdown) {
            executor.execute { closeEmbedderInternal() }
        }
    }

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    fun dispose() {
        mainHandler.removeCallbacks(closeRunnable)
        channel?.setMethodCallHandler(null)
        channel = null
        if (!executor.isShutdown) {
            executor.execute { closeEmbedderInternal() }
            executor.shutdown()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> {
                executor.execute {
                    val supported = try {
                        context.assets.openFd(MODEL_ASSET_PATH).use { true }
                    } catch (_: Exception) {
                        false
                    }
                    mainHandler.post { result.success(supported) }
                }
            }
            "scoreLabels" -> {
                val text = call.argument<String>("text")
                val labels = call.argument<List<String>>("labels")
                if (text.isNullOrBlank() || labels.isNullOrEmpty()) {
                    mainHandler.post {
                        result.error("INVALID_ARGS", "text and non-empty labels are required", null)
                    }
                    return
                }
                scheduleIdleClose()
                executor.execute {
                    try {
                        val embedder = getOrCreateEmbedder()
                        val queryEmbeddings = embedder.embed(text).embeddingResult().embeddings()
                        if (queryEmbeddings.isEmpty()) {
                            mainHandler.post { result.success(emptyMap<String, Double>()) }
                            return@execute
                        }
                        val queryEmbedding = queryEmbeddings.first()
                        val scores = HashMap<String, Double>(labels.size)
                        for (label in labels) {
                            val cached = labelEmbeddingCache.get(label)
                            val labelEmbedding = cached ?: run {
                                val prototype = enrichLabelPrototype(label)
                                val embList = embedder.embed(prototype).embeddingResult().embeddings()
                                if (embList.isNotEmpty()) {
                                    embList.first().also { labelEmbeddingCache.put(label, it) }
                                } else {
                                    null
                                }
                            }
                            if (labelEmbedding != null) {
                                scores[label] = TextEmbedder.cosineSimilarity(queryEmbedding, labelEmbedding)
                            }
                        }
                        mainHandler.post { result.success(scores) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("INFERENCE_ERROR", e.localizedMessage ?: "LiteRT embedding failed", null)
                        }
                    }
                }
            }
            "clearLabelCache" -> {
                executor.execute {
                    labelEmbeddingCache.evictAll()
                    mainHandler.post { result.success(true) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleIdleClose() {
        mainHandler.removeCallbacks(closeRunnable)
        mainHandler.postDelayed(closeRunnable, IDLE_TTL_MS)
    }

    private fun getOrCreateEmbedder(): TextEmbedder {
        textEmbedder?.let { return it }
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(MODEL_ASSET_PATH)
            .build()
        val options = TextEmbedderOptions.builder()
            .setBaseOptions(baseOptions)
            .setL2Normalize(true)
            .setQuantize(false)
            .build()
        return TextEmbedder.createFromOptions(context, options).also {
            textEmbedder = it
        }
    }

    private fun closeEmbedderInternal() {
        try {
            textEmbedder?.close()
        } catch (_: Exception) {
            // Ignore close errors
        } finally {
            textEmbedder = null
        }
    }

    /**
     * Enriches standard financial category names with representative English anchor keywords
     * so cosine similarity separates categories cleanly without model fine-tuning.
     * Custom categories and note tags pass through directly.
     */
    private fun enrichLabelPrototype(label: String): String {
        return when (label) {
            "Food & Dining" -> "Food & Dining: restaurant, cafe, bakery, pizza, kitchen, tea lounge, food delivery, coffee, dining"
            "Transport" -> "Transport: taxi, ride, cab, uber, fuel, petrol, diesel, oil, gas station, bus, train, highway, parking"
            "Shopping" -> "Shopping: retail store, clothing, apparel, mall, hardware, tools, electronics, online order"
            "Groceries" -> "Groceries: supermarket, grocery store, vegetables, fruits, provisions, mart"
            "Utilities" -> "Utilities: electricity, water bill, internet, broadband, mobile recharge, data reload, telecom"
            "Health" -> "Health: pharmacy, hospital, clinic, doctor, medical, lab test, medicine"
            "Subscriptions" -> "Subscriptions: streaming, cloud storage, software membership, monthly plan, music, video"
            "Entertainment" -> "Entertainment: cinema, movie ticket, concert, event, gaming, theatre"
            "Games" -> "Games: video games, steam, playstation, xbox, nintendo, gaming"
            "Gifts" -> "Gifts: gift, wedding, birthday, present, donation"
            "Payments" -> "Payments: loan repayment, instalment, emi, credit card bill, hire purchase"
            "Deposit" -> "Deposit: salary, cash deposit, inward remittance, interest, income, settlement"
            "Transfer" -> "Transfer: bank transfer, own account, internal transfer, fund transfer"
            "Other" -> "Other: miscellaneous general expense"
            else -> label
        }
    }
}
