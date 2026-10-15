/* eslint-disable */
// What a device answers WITHOUT a person: the API is there, the availability and permission checks answer, and stopListening answers
// when nothing is listening. Nothing here starts the microphone or raises a permission prompt, because the prompt is for a person to
// answer. Written for Jasmine 2 as cordova-plugin-test-framework runs it, in plain ES5.

exports.defineAutoTests = function () {
  var speech = window.plugins.speechRecognition;

  describe('SpeechRecognition (window.plugins.speechRecognition)', function () {
    it('is defined, with the whole API', function () {
      expect(speech).toBeDefined();
      ['isRecognitionAvailable', 'startListening', 'stopListening', 'getSupportedLanguages', 'hasPermission', 'requestPermission'].forEach(function (name) {
        expect(typeof speech[name]).toBe('function');
      });
    });
  });

  describe('isRecognitionAvailable', function () {
    it('answers with a boolean', function (done) {
      speech.isRecognitionAvailable(
        function (available) {
          expect(typeof available).toBe('boolean');
          done();
        },
        function (error) {
          fail('the call was refused: ' + error);
          done();
        },
      );
    });
  });

  describe('hasPermission', function () {
    it('answers with a boolean, without asking the person', function (done) {
      speech.hasPermission(
        function (granted) {
          expect(typeof granted).toBe('boolean');
          done();
        },
        function (error) {
          fail('the call was refused: ' + error);
          done();
        },
      );
    });
  });

  describe('stopListening', function () {
    it('answers ok when nothing is listening', function (done) {
      speech.stopListening(
        function () {
          expect(true).toBe(true);
          done();
        },
        function (error) {
          fail('a stop with nothing listening was refused: ' + error);
          done();
        },
      );
    });
  });

  describe('getSupportedLanguages', function () {
    // The list depends on the platform's recognizer, and an emulator may have none: either answer is a real one, a hang is not.
    it('answers with a list of languages or with a reason', function (done) {
      speech.getSupportedLanguages(
        function (languages) {
          expect(Object.prototype.toString.call(languages)).toBe('[object Array]');
          done();
        },
        function (error) {
          expect(typeof error).toBe('string');
          done();
        },
      );
    });
  });
};
