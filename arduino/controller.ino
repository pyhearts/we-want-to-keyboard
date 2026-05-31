#include <Keyboard.h>

// 키보드 컨트롤러 4키 핀 및 매핑 설정
const int numKeys = 4;
const int buttonPins[numKeys] = {2, 3, 4, 5};    // 아두이노 디지털 핀 번호
const char keyCodes[numKeys] = {'d', 'f', 'j', 'k'}; // 매핑할 PC 키보드 키 (D, F, J, K)

// 디바운스 설정을 위한 변수
unsigned long lastDebounceTime[numKeys] = {0, 0, 0, 0};
const unsigned long debounceDelay = 10; // 디바운스 시간 (ms)

// 버튼의 이전 상태 저장 (PULL-UP 입력이므로 기본 HIGH, 눌렀을 때 LOW)
int lastButtonState[numKeys] = {HIGH, HIGH, HIGH, HIGH};
int buttonState[numKeys] = {HIGH, HIGH, HIGH, HIGH};

void setup() {
  // 디지털 입력 핀을 PULL-UP 모드로 설정 (별도의 저항 없이 버튼을 GND와 핀 사이에 연결)
  for (int i = 0; i < numKeys; i++) {
    pinMode(buttonPins[i], INPUT_PULLUP);
  }
  
  // USB 키보드 에뮬레이션 시작
  Keyboard.begin();
}

void loop() {
  unsigned long currentTime = millis();

  for (int i = 0; i < numKeys; i++) {
    // 현재 핀 상태 읽기
    int reading = digitalRead(buttonPins[i]);

    // 핀 상태가 변경된 경우 디바운스 타이머 리셋
    if (reading != lastButtonState[i]) {
      lastDebounceTime[i] = currentTime;
    }

    // 디바운스 딜레이 시간이 지난 후에만 실제 입력 상태 변경 감지
    if ((currentTime - lastDebounceTime[i]) > debounceDelay) {
      // 노이즈가 제거된 유효한 신호 상태가 기존 상태와 다른 경우
      if (reading != buttonState[i]) {
        buttonState[i] = reading;

        // 버튼 상태가 LOW로 바뀌었다면 -> 버튼이 눌림
        if (buttonState[i] == LOW) {
          Keyboard.press(keyCodes[i]);
        } 
        // 버튼 상태가 HIGH로 바뀌었다면 -> 버튼이 떼어짐
        else {
          Keyboard.release(keyCodes[i]);
        }
      }
    }

    // 다음 루프를 위해 상태 업데이트
    lastButtonState[i] = reading;
  }
}
