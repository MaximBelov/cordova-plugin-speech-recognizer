#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

// True when the input format can be tapped: a zero sample rate or channel count means the microphone is held.
BOOL SRInputFormatIsUsable(AVAudioFormat * _Nullable format);

@interface SpeechRecognition : CDVPlugin

- (void)isRecognitionAvailable:(CDVInvokedUrlCommand*)command;
- (void)startListening:(CDVInvokedUrlCommand*)command;
- (void)stopListening:(CDVInvokedUrlCommand*)command;
- (void)getSupportedLanguages:(CDVInvokedUrlCommand*)command;
- (void)hasPermission:(CDVInvokedUrlCommand*)command;
- (void)requestPermission:(CDVInvokedUrlCommand*)command;

@end
