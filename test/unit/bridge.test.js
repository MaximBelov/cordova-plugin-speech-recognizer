const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

// The bridge only forwards to cordova.exec, so the tests replace it with a recorder.
let calls;
beforeEach(() => {
  calls = [];
  global.cordova = {
    exec: (success, error, service, action, args) => {
      calls.push({ success, error, service, action, args });
    },
  };
});

const bridge = () => {
  delete require.cache[require.resolve('../../www/speechRecognition.js')];
  return require('../../www/speechRecognition.js');
};

test('startListening sends the five arguments the native side reads, in order', () => {
  const success = () => {};
  const error = () => {};
  bridge().startListening(success, error, {
    language: 'en-IE',
    matches: 3,
    prompt: 'Say a search term',
    showPartial: true,
    showPopup: false,
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].service, 'SpeechRecognition');
  assert.equal(calls[0].action, 'startListening');
  // The three silence timeouts come after the original five; absent means undefined.
  assert.deepEqual(calls[0].args, ['en-IE', 3, 'Say a search term', true, false, undefined, undefined, undefined]);
  assert.equal(calls[0].success, success);
  assert.equal(calls[0].error, error);
});

test('startListening without options sends undefined for every argument', () => {
  bridge().startListening(() => {}, () => {});

  assert.deepEqual(calls[0].args, [undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined]);
});

test('silence timeouts are passed as the last three arguments, in milliseconds', () => {
  bridge().startListening(() => {}, () => {}, {
    language: 'en-GB',
    completeSilenceMs: 2500,
    possiblyCompleteSilenceMs: 1500,
    minimumLengthMs: 800,
  });

  assert.deepEqual(calls[0].args.slice(5), [2500, 1500, 800]);
});

test('stopListening, isRecognitionAvailable and the permission calls reach their own actions', () => {
  const b = bridge();
  b.stopListening(() => {}, () => {});
  b.isRecognitionAvailable(() => {}, () => {});
  b.hasPermission(() => {}, () => {});
  b.requestPermission(() => {}, () => {});
  b.getSupportedLanguages(() => {}, () => {});

  assert.deepEqual(
    calls.map((c) => [c.service, c.action, c.args]),
    [
      ['SpeechRecognition', 'stopListening', []],
      ['SpeechRecognition', 'isRecognitionAvailable', []],
      ['SpeechRecognition', 'hasPermission', []],
      ['SpeechRecognition', 'requestPermission', []],
      ['SpeechRecognition', 'getSupportedLanguages', []],
    ],
  );
});
