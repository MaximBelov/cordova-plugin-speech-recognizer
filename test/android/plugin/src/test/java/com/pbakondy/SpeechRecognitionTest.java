package com.pbakondy;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.content.pm.ServiceInfo;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognitionService;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.view.View;
import androidx.appcompat.app.AppCompatActivity;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPreferences;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import java.lang.reflect.Field;
import java.util.ArrayList;
import org.json.JSONArray;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

/**
 * The plugin's entry point, `execute`, against doubles for the cordova interfaces. Robolectric provides the Android classes;
 * the recognizer itself is never started, so no microphone is needed.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class SpeechRecognitionTest {

  private static final String NOT_AVAILABLE = "Speech recognition service is not available on the system.";
  private static final String MISSING_PERMISSION = "Missing permission";
  private static final int REQUEST_CODE_SPEECH = 2002;

  private Activity activity;
  private AppCompatActivity compatActivity;
  private CordovaInterface cordova;
  private CallbackContext callbackContext;
  private SpeechRecognition plugin;

  @Before
  public void setUp() {
    activity = Robolectric.buildActivity(Activity.class).setup().get();
    cordova = mock(CordovaInterface.class);
    CordovaWebView webView = mock(CordovaWebView.class);
    // Runs the posted work at once: a View that is not attached to a window would hold it back.
    View view = mock(View.class);
    when(view.post(any(Runnable.class))).thenAnswer(call -> {
      ((Runnable) call.getArgument(0)).run();
      return true;
    });
    // The framework hands the plugin an AppCompatActivity; the plugin only reads its package name, so a mock is enough.
    compatActivity = mock(AppCompatActivity.class);
    when(cordova.getActivity()).thenReturn(compatActivity);
    when(webView.getContext()).thenReturn(activity);
    when(webView.getView()).thenReturn(view);
    callbackContext = mock(CallbackContext.class);

    // The framework sets the interfaces through privateInitialize (initialize is empty in cordova-android 15).
    plugin = new SpeechRecognition();
    plugin.privateInitialize("SpeechRecognition", cordova, webView, mock(CordovaPreferences.class));
  }

  @Test
  public void reportsAvailableWhenARecognitionServiceIsInstalled() throws Exception {
    installRecognitionService();

    assertTrue(plugin.execute("isRecognitionAvailable", new JSONArray(), callbackContext));

    ArgumentCaptor<PluginResult> result = ArgumentCaptor.forClass(PluginResult.class);
    verify(callbackContext).sendPluginResult(result.capture());
    // PluginResult keeps the boolean as its JSON text.
    assertEquals("true", result.getValue().getMessage());
  }

  @Test
  public void startListeningRefusesWhenNoRecognitionServiceIsInstalled() throws Exception {
    grantMicrophone();

    plugin.execute("startListening", listeningArguments(0, 0, 0), callbackContext);

    verify(callbackContext).error(NOT_AVAILABLE);
    verify(cordova, never()).startActivityForResult(any(), any(), eq(REQUEST_CODE_SPEECH));
  }

  @Test
  public void startListeningRefusesWithoutTheMicrophonePermission() throws Exception {
    installRecognitionService();
    when(cordova.hasPermission(Manifest.permission.RECORD_AUDIO)).thenReturn(false);

    plugin.execute("startListening", listeningArguments(0, 0, 0), callbackContext);

    verify(callbackContext).error(MISSING_PERMISSION);
    verify(cordova, never()).startActivityForResult(any(), any(), eq(REQUEST_CODE_SPEECH));
  }

  @Test
  public void startListeningPassesTheSilenceTimeoutsToTheIntent() throws Exception {
    installRecognitionService();
    grantMicrophone();

    plugin.execute("startListening", listeningArguments(2500, 1500, 800), callbackContext);

    Intent intent = capturedListeningIntent();
    assertEquals(2500L, intent.getLongExtra(SilenceTimeouts.COMPLETE_SILENCE, -1));
    assertEquals(1500L, intent.getLongExtra(SilenceTimeouts.POSSIBLY_COMPLETE_SILENCE, -1));
    assertEquals(800L, intent.getLongExtra(SilenceTimeouts.MINIMUM_LENGTH, -1));
  }

  @Test
  public void startListeningLeavesTheRecognizerDefaultsWhenNoTimeoutIsGiven() throws Exception {
    installRecognitionService();
    grantMicrophone();

    plugin.execute("startListening", listeningArguments(0, 0, 0), callbackContext);

    Intent intent = capturedListeningIntent();
    assertFalse(intent.hasExtra(SilenceTimeouts.COMPLETE_SILENCE));
    assertFalse(intent.hasExtra(SilenceTimeouts.POSSIBLY_COMPLETE_SILENCE));
    assertFalse(intent.hasExtra(SilenceTimeouts.MINIMUM_LENGTH));
  }

  @Test
  public void gettingTheLanguagesAsksTheRecognizerAndAnswersLater() throws Exception {
    plugin.execute("getSupportedLanguages", new JSONArray(), callbackContext);

    // Nothing is answered until the recognizer's broadcast comes back to the checker.
    verify(callbackContext, never()).success(any(JSONArray.class));
    ArgumentCaptor<Intent> broadcast = ArgumentCaptor.forClass(Intent.class);
    verify(compatActivity).sendOrderedBroadcast(broadcast.capture(), any(), any(), any(), anyInt(), any(), any());
    assertEquals(RecognizerIntent.ACTION_GET_LANGUAGE_DETAILS, broadcast.getValue().getAction());
  }

  @Test
  public void unknownActionIsNotHandled() throws Exception {
    assertFalse(plugin.execute("noSuchAction", new JSONArray(), callbackContext));
  }

  @Test
  public void hasPermissionReportsTheGrant() throws Exception {
    when(cordova.hasPermission(Manifest.permission.RECORD_AUDIO)).thenReturn(true);

    plugin.execute("hasPermission", new JSONArray(), callbackContext);

    assertEquals("true", sentResult().getMessage());
  }

  @Test
  public void requestPermissionAsksWhenTheMicrophoneIsNotGranted() throws Exception {
    when(cordova.hasPermission(Manifest.permission.RECORD_AUDIO)).thenReturn(false);

    plugin.execute("requestPermission", new JSONArray(), callbackContext);

    verify(cordova).requestPermission(plugin, 23456, Manifest.permission.RECORD_AUDIO);
    verify(callbackContext, never()).success();
  }

  @Test
  public void requestPermissionSucceedsWhenTheMicrophoneIsAlreadyGranted() throws Exception {
    grantMicrophone();

    plugin.execute("requestPermission", new JSONArray(), callbackContext);

    verify(callbackContext).success();
  }

  @Test
  public void aPermissionAnswerSucceedsOnlyWhenGranted() throws Exception {
    primeCallbackContext();
    plugin.onRequestPermissionResult(23456, new String[] {Manifest.permission.RECORD_AUDIO}, new int[] {0});
    verify(callbackContext).success();

    plugin.onRequestPermissionResult(23456, new String[] {Manifest.permission.RECORD_AUDIO}, new int[] {-1});
    verify(callbackContext).error("Permission denied");
  }

  @Test
  public void aSpokenResultIsReturnedAsAJsonArray() throws Exception {
    installRecognitionService();
    grantMicrophone();
    plugin.execute("startListening", listeningArguments(0, 0, 0), callbackContext);

    ArrayList<String> matches = new ArrayList<>();
    matches.add("oak tree");
    Intent data = new Intent().putStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS, matches);
    plugin.onActivityResult(REQUEST_CODE_SPEECH, Activity.RESULT_OK, data);

    ArgumentCaptor<JSONArray> sent = ArgumentCaptor.forClass(JSONArray.class);
    verify(callbackContext).success(sent.capture());
    assertEquals("[\"oak tree\"]", sent.getValue().toString());
  }

  @Test
  public void aCancelledDialogReportsItsResultCode() throws Exception {
    primeCallbackContext();
    plugin.onActivityResult(REQUEST_CODE_SPEECH, Activity.RESULT_CANCELED, null);

    verify(callbackContext).error("0");
  }

  @Test
  public void stopListeningSucceedsWhenNothingIsRunning() throws Exception {
    plugin.execute("stopListening", new JSONArray(), callbackContext);

    verify(callbackContext).success();
  }

  @Test
  public void theRecognizerReportsItsErrorsAndResultsBack() throws Exception {
    primeCallbackContext();
    RecognitionListener listener = recognitionListener();

    listener.onError(SpeechRecognizer.ERROR_NO_MATCH);
    verify(callbackContext).error(org.mockito.ArgumentMatchers.anyString());

    ArrayList<String> heard = new ArrayList<>();
    heard.add("open the map");
    Bundle results = new Bundle();
    results.putStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION, heard);
    listener.onResults(results);
    ArgumentCaptor<JSONArray> sent = ArgumentCaptor.forClass(JSONArray.class);
    verify(callbackContext).success(sent.capture());
    assertEquals("[\"open the map\"]", sent.getValue().toString());
  }

  private PluginResult sentResult() {
    ArgumentCaptor<PluginResult> result = ArgumentCaptor.forClass(PluginResult.class);
    verify(callbackContext).sendPluginResult(result.capture());
    return result.getValue();
  }

  @Test
  public void eachRecognizerErrorHasItsOwnMessage() throws Exception {
    primeCallbackContext();
    RecognitionListener listener = recognitionListener();

    listener.onError(SpeechRecognizer.ERROR_AUDIO);
    listener.onError(SpeechRecognizer.ERROR_CLIENT);
    listener.onError(SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS);
    listener.onError(SpeechRecognizer.ERROR_NETWORK);
    listener.onError(SpeechRecognizer.ERROR_NETWORK_TIMEOUT);
    listener.onError(SpeechRecognizer.ERROR_NO_MATCH);
    listener.onError(SpeechRecognizer.ERROR_RECOGNIZER_BUSY);
    listener.onError(SpeechRecognizer.ERROR_SERVER);
    listener.onError(SpeechRecognizer.ERROR_SPEECH_TIMEOUT);
    listener.onError(999);

    verify(callbackContext).error("Audio recording error");
    verify(callbackContext).error("Client side error");
    verify(callbackContext).error("Insufficient permissions");
    verify(callbackContext).error("Network error");
    verify(callbackContext).error("Network timeout");
    verify(callbackContext).error("No match");
    verify(callbackContext).error("RecognitionService busy");
    verify(callbackContext).error("error from server");
    verify(callbackContext).error("No speech input");
    verify(callbackContext).error("Didn't understand, please try again.");
  }

  @Test
  public void partialResultsAreSentOnlyWhenTheyChange() throws Exception {
    primeCallbackContext();
    RecognitionListener listener = recognitionListener();
    ArrayList<String> first = new ArrayList<>();
    first.add("open");
    ArrayList<String> longer = new ArrayList<>();
    longer.add("open the map");

    listener.onPartialResults(partial(first));
    listener.onPartialResults(partial(first));
    listener.onPartialResults(partial(new ArrayList<String>()));
    listener.onPartialResults(partial(longer));

    // One answer from the priming call, then one per change: "open" and "open the map".
    verify(callbackContext, times(3)).sendPluginResult(any(PluginResult.class));
  }

  private static Bundle partial(ArrayList<String> matches) {
    Bundle bundle = new Bundle();
    bundle.putStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION, matches);
    return bundle;
  }

  // The plugin keeps the listener it gives the recognizer; read it back to drive the callbacks directly.
  private RecognitionListener recognitionListener() throws Exception {
    Field listenerField = SpeechRecognition.class.getDeclaredField("listener");
    listenerField.setAccessible(true);
    return (RecognitionListener) listenerField.get(plugin);
  }

  // `callbackContext` is set by execute; a harmless action sets it without answering the callback under test.
  private void primeCallbackContext() throws Exception {
    plugin.execute("hasPermission", new JSONArray(), callbackContext);
  }

  // The five original arguments, then the three silence timeouts, as the JavaScript bridge sends them.
  private static JSONArray listeningArguments(long completeSilenceMs, long possiblyCompleteSilenceMs, long minimumLengthMs) {
    return new JSONArray()
        .put("en-GB")
        .put(3)
        .put("Say a search term")
        .put(true)
        .put(true)
        .put(completeSilenceMs)
        .put(possiblyCompleteSilenceMs)
        .put(minimumLengthMs);
  }

  private void installRecognitionService() {
    ResolveInfo service = new ResolveInfo();
    service.serviceInfo = new ServiceInfo();
    service.serviceInfo.packageName = "test.recognizer";
    service.serviceInfo.name = "RecognizerService";
    Shadows.shadowOf(activity.getPackageManager()).addResolveInfoForIntent(new Intent(RecognitionService.SERVICE_INTERFACE), service);
  }

  private void grantMicrophone() {
    when(cordova.hasPermission(Manifest.permission.RECORD_AUDIO)).thenReturn(true);
  }

  private Intent capturedListeningIntent() {
    ArgumentCaptor<Intent> intent = ArgumentCaptor.forClass(Intent.class);
    verify(cordova).startActivityForResult(eq(plugin), intent.capture(), eq(REQUEST_CODE_SPEECH));
    return intent.getValue();
  }
}
