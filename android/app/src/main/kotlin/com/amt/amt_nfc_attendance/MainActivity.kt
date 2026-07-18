package com.amt.amt_nfc_attendance

import android.os.Handler
import android.os.Looper
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.amt.amt_nfc_attendance/biometric"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // --- فحص هل الجهاز يدعم البيومتري ---
                "canAuthenticate" -> {
                    val biometricManager = BiometricManager.from(this)
                    val status = biometricManager.canAuthenticate(
                        BiometricManager.Authenticators.BIOMETRIC_WEAK or
                        BiometricManager.Authenticators.DEVICE_CREDENTIAL
                    )
                    result.success(status == BiometricManager.BIOMETRIC_SUCCESS)
                }

                // --- إظهار شاشة البصمة ---
                "authenticate" -> {
                    val executor = ContextCompat.getMainExecutor(this)

                    val prompt = BiometricPrompt(
                        this,
                        executor,
                        object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(
                                authResult: BiometricPrompt.AuthenticationResult
                            ) {
                                Handler(Looper.getMainLooper()).post {
                                    result.success(true)
                                }
                            }

                            override fun onAuthenticationFailed() {
                                // المستخدم حاول لكن فشل (لا نرد هنا — ننتظر نجاح أو إلغاء)
                            }

                            override fun onAuthenticationError(
                                errorCode: Int,
                                errString: CharSequence
                            ) {
                                Handler(Looper.getMainLooper()).post {
                                    // 10 = USER_CANCELED, 13 = NEGATIVE_BUTTON
                                    if (errorCode == 10 || errorCode == 13) {
                                        result.success(false)
                                    } else {
                                        result.error("AUTH_ERROR", errString.toString(), errorCode)
                                    }
                                }
                            }
                        }
                    )

                    val promptInfo = BiometricPrompt.PromptInfo.Builder()
                        .setTitle("التحقق من الهوية")
                        .setSubtitle("يرجى التحقق لتسجيل الحضور")
                        .setAllowedAuthenticators(
                            BiometricManager.Authenticators.BIOMETRIC_WEAK or
                            BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        )
                        .build()

                    prompt.authenticate(promptInfo)
                }

                else -> result.notImplemented()
            }
        }
    }
}
