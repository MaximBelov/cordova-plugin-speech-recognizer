// https://developer.apple.com/library/prerelease/content/samplecode/SpeakToMe/Listings/SpeakToMe_ViewController_swift.html
// http://robusttechhouse.com/introduction-to-native-speech-recognition-for-ios/
// https://www.appcoda.com/siri-speech-framework/

#import "SpeechRecognition.h"

#import <Cordova/CDV.h>
#import <Speech/Speech.h>

#define DEFAULT_LANGUAGE @"en-US"
#define DEFAULT_MATCHES 5

#define MESSAGE_MISSING_PERMISSION @"Missing permission"
#define MESSAGE_ACCESS_DENIED @"User denied access to speech recognition"
#define MESSAGE_RESTRICTED @"Speech recognition restricted on this device"
#define MESSAGE_NOT_DETERMINED @"Speech recognition not determined on this device"
#define MESSAGE_ACCESS_DENIED_MICROPHONE @"User denied access to microphone"
#define MESSAGE_ONGOING @"Ongoing speech recognition"
#define MESSAGE_AUDIO_SESSION @"Audio session unavailable"
#define MESSAGE_AUDIO_INPUT @"Audio input unavailable"

@interface SpeechRecognition()

@property (strong, nonatomic) SFSpeechRecognizer *speechRecognizer;
@property (strong, nonatomic) AVAudioEngine *audioEngine;
@property (strong, nonatomic) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (strong, nonatomic) SFSpeechRecognitionTask *recognitionTask;

@end


BOOL SRInputFormatIsUsable(AVAudioFormat *format) {
    return format != nil && format.sampleRate > 0 && format.channelCount > 0;
}

@implementation SpeechRecognition

- (void)isRecognitionAvailable:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = nil;

    if ([SFSpeechRecognizer class]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startListening:(CDVInvokedUrlCommand*)command {
    if ( self.audioEngine.isRunning ) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_ONGOING];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSLog(@"startListening()");

    SFSpeechRecognizerAuthorizationStatus status = [SFSpeechRecognizer authorizationStatus];
    if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
        NSLog(@"startListening() speech recognition access not authorized");
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_MISSING_PERMISSION];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){
        if (!granted) {
            NSLog(@"startListening() microphone access not authorized");
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_ACCESS_DENIED_MICROPHONE];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        NSString* language = [command argumentAtIndex:0 withDefault:DEFAULT_LANGUAGE];
        int matches = [[command argumentAtIndex:1 withDefault:@(DEFAULT_MATCHES)] intValue];
        BOOL showPartial = [[command argumentAtIndex:3 withDefault:@(NO)] boolValue];

        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:language];
        self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        self.audioEngine = [[AVAudioEngine alloc] init];

        // Cancel the previous task if it's running.
        if ( self.recognitionTask ) {
            [self.recognitionTask cancel];
            self.recognitionTask = nil;
        }

        // Every failure here used to be dropped (error:nil), so the caller waited for results that never came.
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSError *sessionError = nil;
        BOOL sessionReady = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                          withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                                error:&sessionError];
        sessionReady = sessionReady && [audioSession setMode:AVAudioSessionModeDefault error:&sessionError];
        sessionReady = sessionReady && [audioSession setActive:YES
                                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                         error:&sessionError];
        if (!sessionReady) {
            NSLog(@"startListening() audio session: %@", sessionError.localizedDescription);
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_AUDIO_SESSION];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        self.recognitionRequest.shouldReportPartialResults = showPartial;

        AVAudioInputNode *inputNode = self.audioEngine.inputNode;
        AVAudioFormat *format = [inputNode outputFormatForBus:0];

        // While the microphone is held (a call, another app, a Bluetooth route change) the input has no
        // format. A tap on it raises IsFormatSampleRateAndChannelCountValid as an NSException, which
        // closes the app, so refuse the start instead and let the caller show the error.
        if (!SRInputFormatIsUsable(format)) {
            NSLog(@"startListening() input format has no sample rate or channels");
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_AUDIO_INPUT];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {

            if ( result ) {

                NSMutableArray *resultArray = [[NSMutableArray alloc] init];

                int counter = 0;
                for ( SFTranscription *transcription in result.transcriptions ) {
                    if (matches > 0 && counter < matches) {
                        [resultArray addObject:transcription.formattedString];
                    }
                    counter++;
                }

                NSArray *transcriptions = [NSArray arrayWithArray:resultArray];

                NSLog(@"startListening() recognitionTask result array: %@", transcriptions.description);

                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:transcriptions];
                if (showPartial){
                    [pluginResult setKeepCallbackAsBool:YES];
                }
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }

            if ( error ) {
                NSLog(@"startListening() recognitionTask error: %@", error.description);

                [self.audioEngine stop];
                [self.audioEngine.inputNode removeTapOnBus:0];

                self.recognitionRequest = nil;
                self.recognitionTask = nil;

                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
                if (showPartial){
                    [pluginResult setKeepCallbackAsBool:YES];
                }
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }

            if ( result.isFinal ) {
                NSLog(@"startListening() recognitionTask isFinal");

                [self.audioEngine stop];
                [self.audioEngine.inputNode removeTapOnBus:0];

                self.recognitionRequest = nil;
                self.recognitionTask = nil;
            }
        }];

        @try {
            [inputNode installTapOnBus:0 bufferSize:1024 format:format block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
                [self.recognitionRequest appendAudioPCMBuffer:buffer];
            }];
        } @catch (NSException *exception) {
            // Any other refusal from AVFoundation on this path is an error for the caller, not a crash.
            NSLog(@"startListening() could not tap the input: %@", exception.reason);
            [self.recognitionTask cancel];
            self.recognitionTask = nil;
            self.recognitionRequest = nil;
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_AUDIO_INPUT];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        [self.audioEngine prepare];
        NSError *engineError = nil;
        if (![self.audioEngine startAndReturnError:&engineError]) {
            NSLog(@"startListening() audio engine: %@", engineError.localizedDescription);
            [inputNode removeTapOnBus:0];
            [self.recognitionTask cancel];
            self.recognitionTask = nil;
            self.recognitionRequest = nil;
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_AUDIO_INPUT];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

    }];

}

- (void)stopListening:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        NSLog(@"stopListening()");

        if ( self.audioEngine.isRunning ) {
            [self.audioEngine stop];
            [self.recognitionRequest endAudio];
        }

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getSupportedLanguages:(CDVInvokedUrlCommand*)command {
    NSSet<NSLocale *> *supportedLocales = [SFSpeechRecognizer supportedLocales];

    NSMutableArray *localesArray = [[NSMutableArray alloc] init];

    for(NSLocale *locale in supportedLocales) {
        [localesArray addObject:[locale localeIdentifier]];
    }

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:localesArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)hasPermission:(CDVInvokedUrlCommand*)command {
    SFSpeechRecognizerAuthorizationStatus status = [SFSpeechRecognizer authorizationStatus];
    BOOL speechAuthGranted = (status == SFSpeechRecognizerAuthorizationStatusAuthorized);

    if (!speechAuthGranted) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:granted];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)requestPermission:(CDVInvokedUrlCommand*)command {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status){
        dispatch_async(dispatch_get_main_queue(), ^{
            CDVPluginResult *pluginResult = nil;
            BOOL speechAuthGranted = NO;

            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    speechAuthGranted = YES;
                    break;
                case SFSpeechRecognizerAuthorizationStatusDenied:
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_ACCESS_DENIED];
                    break;
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_RESTRICTED];
                    break;
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_NOT_DETERMINED];
                    break;
            }

            if (!speechAuthGranted) {
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }

            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){
                CDVPluginResult *pluginResult = nil;

                if (granted) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:MESSAGE_ACCESS_DENIED_MICROPHONE];
                }

                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
        });
    }];
}

@end
