package com.pbakondy;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.Map;
import org.junit.Test;

public class SilenceTimeoutsTest {

  @Test
  public void noValuesMeansNoExtras() {
    assertTrue(SilenceTimeouts.extras(0, 0, 0).isEmpty());
  }

  @Test
  public void negativeValuesAreIgnored() {
    assertTrue(SilenceTimeouts.extras(-1, -500, -1).isEmpty());
  }

  @Test
  public void eachPositiveValueGoesUnderItsOwnKey() {
    Map<String, Long> extras = SilenceTimeouts.extras(2500, 1500, 800);

    assertEquals(3, extras.size());
    assertEquals(Long.valueOf(2500), extras.get(SilenceTimeouts.COMPLETE_SILENCE));
    assertEquals(Long.valueOf(1500), extras.get(SilenceTimeouts.POSSIBLY_COMPLETE_SILENCE));
    assertEquals(Long.valueOf(800), extras.get(SilenceTimeouts.MINIMUM_LENGTH));
  }

  @Test
  public void onlyTheSetValuesAreSent() {
    Map<String, Long> extras = SilenceTimeouts.extras(0, 1500, 0);

    assertEquals(1, extras.size());
    assertEquals(Long.valueOf(1500), extras.get(SilenceTimeouts.POSSIBLY_COMPLETE_SILENCE));
  }

  @Test
  public void keysAreThePlatformExtraNames() {
    // Renaming one of these silently stops the recognizer from honouring the value.
    assertEquals("android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", SilenceTimeouts.COMPLETE_SILENCE);
    assertEquals("android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", SilenceTimeouts.POSSIBLY_COMPLETE_SILENCE);
    assertEquals("android.speech.extra.SPEECH_INPUT_MINIMUM_LENGTH_MILLIS", SilenceTimeouts.MINIMUM_LENGTH);
  }
}
