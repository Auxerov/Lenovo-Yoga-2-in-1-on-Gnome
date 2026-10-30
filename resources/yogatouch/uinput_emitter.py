#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - UInput Virtual Key & Mouse Emitter
# Author: Auxerov
# ==============================================================================

import time
import threading
import evdev
from evdev import ecodes

KEY_NAME_MAP = {
    'ctrl': ecodes.KEY_LEFTCTRL,
    'lctrl': ecodes.KEY_LEFTCTRL,
    'rctrl': ecodes.KEY_RIGHTCTRL,
    'shift': ecodes.KEY_LEFTSHIFT,
    'lshift': ecodes.KEY_LEFTSHIFT,
    'rshift': ecodes.KEY_RIGHTSHIFT,
    'alt': ecodes.KEY_LEFTALT,
    'lalt': ecodes.KEY_LEFTALT,
    'ralt': ecodes.KEY_RIGHTALT,
    'super': ecodes.KEY_LEFTMETA,
    'meta': ecodes.KEY_LEFTMETA,
    'win': ecodes.KEY_LEFTMETA,
    'space': ecodes.KEY_SPACE,
    'enter': ecodes.KEY_ENTER,
    'return': ecodes.KEY_ENTER,
    'tab': ecodes.KEY_TAB,
    'esc': ecodes.KEY_ESC,
    'escape': ecodes.KEY_ESC,
    'backspace': ecodes.KEY_BACKSPACE,
    'delete': ecodes.KEY_DELETE,
    'up': ecodes.KEY_UP,
    'down': ecodes.KEY_DOWN,
    'left': ecodes.KEY_LEFT,
    'right': ecodes.KEY_RIGHT,
    'pagedown': ecodes.KEY_PAGEDOWN,
    'pageup': ecodes.KEY_PAGEUP,
    'home': ecodes.KEY_HOME,
    'end': ecodes.KEY_END,
    'equal': ecodes.KEY_EQUAL,
    'minus': ecodes.KEY_MINUS,
    'plus': ecodes.KEY_EQUAL,
    'slash': ecodes.KEY_SLASH,
    'backslash': ecodes.KEY_BACKSLASH,
    'comma': ecodes.KEY_COMMA,
    'dot': ecodes.KEY_DOT,
    'semicolon': ecodes.KEY_SEMICOLON,
    'apostrophe': ecodes.KEY_APOSTROPHE,
    'grave': ecodes.KEY_GRAVE,
    # Mouse buttons
    'btn_left': ecodes.BTN_LEFT,
    'btn_middle': ecodes.BTN_MIDDLE,
    'btn_right': ecodes.BTN_RIGHT,
    'mmb': ecodes.BTN_MIDDLE,
    'rmb': ecodes.BTN_RIGHT,
    'lmb': ecodes.BTN_LEFT,
}

# Auto populate letters and digits
for c in 'abcdefghijklmnopqrstuvwxyz':
    KEY_NAME_MAP[c] = getattr(ecodes, f'KEY_{c.upper()}', None)
for d in '0123456789':
    KEY_NAME_MAP[d] = getattr(ecodes, f'KEY_{d}', None)
for f in range(1, 25):
    KEY_NAME_MAP[f'f{f}'] = getattr(ecodes, f'KEY_F{f}', None)
for n in range(10):
    KEY_NAME_MAP[f'num{n}'] = getattr(ecodes, f'KEY_KP{n}', None)
    KEY_NAME_MAP[f'kp{n}'] = getattr(ecodes, f'KEY_KP{n}', None)
KEY_NAME_MAP['kpdot'] = getattr(ecodes, 'KEY_KPDOT', None)
KEY_NAME_MAP['kcenter'] = getattr(ecodes, 'KEY_KPENTER', None)


class InputEmitter:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                cls._instance._init_uinput()
            return cls._instance

    def _init_uinput(self):
        self.lock = threading.Lock()
        self.active_keys = set()
        
        # Collect valid keycodes below KEY_MAX
        valid_keys = [
            getattr(ecodes, k)
            for k in dir(ecodes)
            if k.startswith('KEY_') and isinstance(getattr(ecodes, k), int) and getattr(ecodes, k) < ecodes.KEY_MAX
        ]
        mouse_buttons = [ecodes.BTN_LEFT, ecodes.BTN_MIDDLE, ecodes.BTN_RIGHT]
        all_codes = list(set(valid_keys + mouse_buttons))

        try:
            self.ui = evdev.UInput(
                {ecodes.EV_KEY: all_codes},
                name='YogaTouch-Virtual-ExpressKeys',
                bustype=0x03 # BUS_USB
            )
            time.sleep(0.1) # Small warmup delay
        except Exception as e:
            print(f"[YogaTouch] Error initializing UInput: {e}")
            self.ui = None

    def parse_chord(self, chord_str):
        if not chord_str:
            return []
        parts = [p.strip().lower() for p in chord_str.split('+') if p.strip()]
        codes = []
        for p in parts:
            if p in KEY_NAME_MAP and KEY_NAME_MAP[p] is not None:
                codes.append(KEY_NAME_MAP[p])
            else:
                code = getattr(ecodes, f'KEY_{p.upper()}', None)
                if code is not None and code < ecodes.KEY_MAX:
                    codes.append(code)
                else:
                    print(f"[YogaTouch] Unknown key name: {p}")
        return codes

    def tap(self, chord_str):
        if not self.ui:
            return
        codes = self.parse_chord(chord_str)
        if not codes:
            return
        with self.lock:
            # Press all in order
            for code in codes:
                self.ui.write(ecodes.EV_KEY, code, 1)
            self.ui.syn()
            time.sleep(0.015)
            # Release all in reverse order
            for code in reversed(codes):
                self.ui.write(ecodes.EV_KEY, code, 0)
            self.ui.syn()

    def press(self, chord_str):
        if not self.ui:
            return
        codes = self.parse_chord(chord_str)
        with self.lock:
            for code in codes:
                self.ui.write(ecodes.EV_KEY, code, 1)
                self.active_keys.add(code)
            self.ui.syn()

    def release(self, chord_str):
        if not self.ui:
            return
        codes = self.parse_chord(chord_str)
        with self.lock:
            for code in codes:
                self.ui.write(ecodes.EV_KEY, code, 0)
                self.active_keys.discard(code)
            self.ui.syn()

    def release_all(self):
        if not self.ui:
            return
        with self.lock:
            for code in list(self.active_keys):
                self.ui.write(ecodes.EV_KEY, code, 0)
            self.active_keys.clear()
            self.ui.syn()

    def close(self):
        self.release_all()
        if self.ui:
            try:
                self.ui.close()
            except Exception:
                pass
            self.ui = None
