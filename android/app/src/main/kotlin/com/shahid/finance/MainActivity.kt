package com.shahid.finance

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt. The package MUST match namespace/applicationId
// (com.shahid.finance) — a mismatch here was the Hisab Business launch crash.
class MainActivity : FlutterFragmentActivity()
