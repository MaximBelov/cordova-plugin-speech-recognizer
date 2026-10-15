package com.pbakondy;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Silence timeouts for the Android recognizer. Without them the recognizer can end a sentence while
 * the speaker is still talking. A value of zero or less leaves the platform default in place.
 * Pure Java, with no Android types, so it can be unit tested on the JVM.
 */
final class SilenceTimeouts {

  static final String COMPLETE_SILENCE = "android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS";
  static final String POSSIBLY_COMPLETE_SILENCE = "android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS";
  static final String MINIMUM_LENGTH = "android.speech.extra.SPEECH_INPUT_MINIMUM_LENGTH_MILLIS";

  private SilenceTimeouts() {
  }

  static Map<String, Long> extras(long completeSilenceMs, long possiblyCompleteSilenceMs, long minimumLengthMs) {
    Map<String, Long> extras = new LinkedHashMap<>();
    addIfSet(extras, COMPLETE_SILENCE, completeSilenceMs);
    addIfSet(extras, POSSIBLY_COMPLETE_SILENCE, possiblyCompleteSilenceMs);
    addIfSet(extras, MINIMUM_LENGTH, minimumLengthMs);
    return extras;
  }

  private static void addIfSet(Map<String, Long> extras, String key, long valueMs) {
    if (valueMs > 0) {
      extras.put(key, valueMs);
    }
  }
}
