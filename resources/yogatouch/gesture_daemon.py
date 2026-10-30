#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - Multi-Touch 4-Finger Pinch Gesture Detector
# Author: Auxerov
# ==============================================================================

import os
import sys
import math
import time
import select
import threading
import subprocess
import evdev
from evdev import ecodes


class DeviceSlotState:
    def __init__(self, name, is_touchscreen=True, sensitivity="normal"):
        self.name = name
        self.is_touchscreen = is_touchscreen
        self.current_slot = 0
        self.slots = {}  # slot_id: {"x": int, "y": int, "active": bool}
        self.initial_radius = None
        self.gesture_start_time = 0
        self.last_trigger_time = 0
        self.set_sensitivity(sensitivity)

    def set_sensitivity(self, sensitivity):
        if sensitivity == "high":
            self.ratio_thresh = 0.82
            self.diff_thresh = 300 if self.is_touchscreen else 100
        elif sensitivity == "low":
            self.ratio_thresh = 0.65
            self.diff_thresh = 600 if self.is_touchscreen else 250
        else:  # normal
            self.ratio_thresh = 0.75
            self.diff_thresh = 400 if self.is_touchscreen else 150

    def process_event(self, event):
        if event.type == ecodes.EV_ABS:
            if event.code == ecodes.ABS_MT_SLOT:
                self.current_slot = event.value
            elif event.code == ecodes.ABS_MT_TRACKING_ID:
                if self.current_slot not in self.slots:
                    self.slots[self.current_slot] = {"x": 0, "y": 0, "active": False}
                if event.value == -1:
                    self.slots[self.current_slot]["active"] = False
                else:
                    self.slots[self.current_slot]["active"] = True
            elif event.code == ecodes.ABS_MT_POSITION_X:
                if self.current_slot not in self.slots:
                    self.slots[self.current_slot] = {"x": 0, "y": 0, "active": True}
                self.slots[self.current_slot]["x"] = event.value
            elif event.code == ecodes.ABS_MT_POSITION_Y:
                if self.current_slot not in self.slots:
                    self.slots[self.current_slot] = {"x": 0, "y": 0, "active": True}
                self.slots[self.current_slot]["y"] = event.value

        elif event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
            now = time.time()
            active_points = [
                (s["x"], s["y"])
                for s in self.slots.values()
                if s.get("active", False)
            ]

            if len(active_points) == 4:
                # Exactly 4 fingers are touching!
                cx = sum(p[0] for p in active_points) / 4.0
                cy = sum(p[1] for p in active_points) / 4.0
                radius = sum(math.hypot(p[0] - cx, p[1] - cy) for p in active_points) / 4.0

                if self.initial_radius is None:
                    self.initial_radius = radius
                    self.gesture_start_time = now
                else:
                    elapsed = now - self.gesture_start_time
                    if 0.04 < elapsed < 1.0:
                        ratio = radius / max(1.0, self.initial_radius)
                        diff = self.initial_radius - radius
                        
                        # 4-Finger Pinch Inward condition
                        if (ratio < self.ratio_thresh or diff > self.diff_thresh) and (now - self.last_trigger_time > 1.2):
                            self.last_trigger_time = now
                            self.initial_radius = None
                            return True
            else:
                self.initial_radius = None

        return False


class GestureMonitor(threading.Thread):
    def __init__(self, callback, sensitivity="normal"):
        super().__init__(daemon=True)
        self.callback = callback
        self.sensitivity = sensitivity
        self.running = True
        self.devices = {}  # fd: (InputDevice, DeviceSlotState)
        self.libinput_proc = None

    def scan_devices(self):
        # Close old
        for fd, (dev, _) in list(self.devices.items()):
            try:
                dev.close()
            except Exception:
                pass
        self.devices.clear()

        for path in evdev.list_devices():
            try:
                dev = evdev.InputDevice(path)
                caps = dev.capabilities().get(ecodes.EV_ABS, [])
                abs_codes = [c[0] if isinstance(c, tuple) else c for c in caps]
                
                # Check for multi-touch support
                if ecodes.ABS_MT_SLOT in abs_codes:
                    is_ts = ("finger" in dev.name.lower() or "touchscreen" in dev.name.lower())
                    state = DeviceSlotState(dev.name, is_touchscreen=is_ts, sensitivity=self.sensitivity)
                    self.devices[dev.fd] = (dev, state)
                    print(f"[YogaTouch] GestureMonitor listening on: {dev.name} ({dev.path})")
            except Exception as e:
                pass

    def run(self):
        self.scan_devices()
        
        # Also start a helper thread for libinput debug-events as a secondary touchpad pinch detector
        t = threading.Thread(target=self._run_libinput_watcher, daemon=True)
        t.start()

        reconnect_cooldown = time.time()

        while self.running:
            if not self.devices:
                time.sleep(2.0)
                self.scan_devices()
                continue

            try:
                r, _, _ = select.select(list(self.devices.keys()), [], [], 1.5)
            except (ValueError, OSError):
                # An fd became invalid (e.g. device sleep)
                self.scan_devices()
                continue

            for fd in r:
                if fd not in self.devices:
                    continue
                dev, state = self.devices[fd]
                try:
                    for event in dev.read():
                        if state.process_event(event):
                            print(f"[YogaTouch] 4-Finger Pinch detected on {state.name}!")
                            if self.callback:
                                self.callback()
                except OSError:
                    # Device disconnected or power cycled
                    del self.devices[fd]
                    try:
                        dev.close()
                    except Exception:
                        pass

            # Periodic rescan for new devices every 10s
            if time.time() - reconnect_cooldown > 10.0:
                reconnect_cooldown = time.time()
                # Check if device count matches available MT devices
                current_count = len(self.devices)
                available = [
                    p for p in evdev.list_devices()
                    if ecodes.ABS_MT_SLOT in [c[0] if isinstance(c, tuple) else c for c in evdev.InputDevice(p).capabilities().get(ecodes.EV_ABS, [])]
                ]
                if len(available) != current_count:
                    self.scan_devices()

    def _run_libinput_watcher(self):
        """Reads libinput debug-events as a secondary trigger for touchpad 4-finger gestures"""
        last_libinput_trigger = 0
        while self.running:
            try:
                self.libinput_proc = subprocess.Popen(
                    ["libinput", "debug-events"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                for line in self.libinput_proc.stdout:
                    if not self.running:
                        break
                    # Look for 4-finger pinch on touchpad:
                    # e.g.: event5   GESTURE_PINCH_UPDATE  +1.23s  4  0.00/ 0.00 ( 0.00/ 0.00)  0.72* 12.34
                    # or GESTURE_PINCH_END 4
                    if "GESTURE_PINCH" in line and " 4 " in line:
                        parts = line.split()
                        # Check scale
                        scale_val = None
                        for p in parts:
                            if p.endswith("*"):
                                try:
                                    scale_val = float(p[:-1])
                                    break
                                except ValueError:
                                    pass
                        now = time.time()
                        if scale_val is not None and scale_val < 0.78:
                            if now - last_libinput_trigger > 1.2:
                                last_libinput_trigger = now
                                print("[YogaTouch] Touchpad 4-Finger Pinch scale triggered via libinput!")
                                if self.callback:
                                    self.callback()
            except Exception as e:
                time.sleep(3.0)
            finally:
                if self.libinput_proc:
                    try:
                        self.libinput_proc.terminate()
                    except Exception:
                        pass

    def stop(self):
        self.running = False
        if self.libinput_proc:
            try:
                self.libinput_proc.terminate()
            except Exception:
                pass
        for fd, (dev, _) in list(self.devices.items()):
            try:
                dev.close()
            except Exception:
                pass
        self.devices.clear()
