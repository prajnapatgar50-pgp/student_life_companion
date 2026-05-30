package com.example.student_life_companion

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState) // 🌟 ಫಿಕ್ಸ್: ಇಲ್ಲಿದ್ದ ಬ್ರಾಕೆಟ್ ತಪ್ಪು ಸರಿಪಡಿಸಲಾಗಿದೆ
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        // 🌟 ಫಿಕ್ಸ್: ಎರಡು ಸ್ಲ್ಯಾಶ್ ಬಳಸಿ ಕಮೆಂಟ್ ಅನ್ನು ಕ್ಲೀನ್ ಮಾಡಲಾಗಿದೆ
        // ಅಲಾರಾಂ ಅಥವಾ ನೋಟಿಫಿಕೇಶನ್ ಇಂಟೆಂಟ್ ಬಂದಾಗ ಆಪ್ ಅನ್ನು ಫೋರ್ಸ್ ಆಗಿ ಮುಂಭಾಗಕ್ಕೆ ಓಪನ್ ಮಾಡಲು ಇದು ಸಹಾಯ ಮಾಡುತ್ತದೆ
        if (intent != null) {
            this.intent = intent
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
    }
}