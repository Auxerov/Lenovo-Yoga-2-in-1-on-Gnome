#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - Multi-Touch 4-to-5 Finger Pinch Gesture Detector
# Author: Auxerov
# Lightweight, direct evdev kernel event listener (zero child processes)
# ==============================================================================

import os
import sys
import math
import time
import select
import threading
import evdev
from evdev import ecodes


class DeviceSlotState:
    """
    Tracks multi-touch finger slots and detects 4-to-5 finger pinch-inward / grab gestures.
    Supports both real-time contraction detection and fast pinch-and-release detection.
    """
    def __init__(self, name, is_touchscreen=True, sensitivity="normal", min_fingers=4, max_fingers=5, cooldown=0.80):
        self.name = name
        self.is_touchscreen = is_touchscreen
        self.current_slot = 0
        self.slots = {}  # slot_id: {"x": int, "y": int, "active": bool}

        self.min_fingers = min_fingers
        self.max_fingers = max_fingers
        self.cooldown = cooldown

        self.tracking = False
        self.session_start_time = 0.0
        self.start_radius = 0.0
        self.max_radius = 0.0
        self.min_radius = 0.0
        self.samples = 0
        self.last_trigger_time = 0.0

        self.set_sensitivity(sensitivity)

    def set_sensitivity(self, sensitivity):
        self.sensitivity = sensitivity
        if sensitivity == "high":
            self.ratio_thresh = 0.88
            self.diff_thresh = 180 if self.is_touchscreen else 60
            self.release_ratio_thresh = 0.90
            self.release_diff_thresh = 120 if self.is_touchscreen else 40
        elif sensitivity == "low":
            self.ratio_thresh = 0.70
            self.diff_thresh = 450 if self.is_touchscreen else 160
            self.release_ratio_thresh = 0.75
            self.release_diff_thresh = 320 if self.is_touchscreen else 110
        else:  # normal
            self.ratio_thresh = 0.82
            self.diff_thresh = 260 if self.is_touchscreen else 90
            self.release_ratio_thresh = 0.85
            self.release_diff_thresh = 180 if self.is_touchscreen else 60

    def process_event(self, event):
        """
        Processes a raw evdev event.
        Returns True if a 4-or-5 finger pinch inward is triggered.
        """
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
            n = len(active_points)

            # 4 or 5 fingers detected on the surface
            if self.min_fingers <= n <= self.max_fingers:
                cx = sum(p[0] for p in active_points) / float(n)
                cy = sum(p[1] for p in active_points) / float(n)
                radius = sum(math.hypot(p[0] - cx, p[1] - cy) for p in active_points) / float(n)

                if not self.tracking:
                    self.tracking = True
                    self.session_start_time = now
                    self.start_radius = radius
                    self.max_radius = radius
                    self.min_radius = radius
                    self.samples = 1
                else:
                    elapsed = now - self.session_start_time
                    if elapsed > 1.2:
                        # Session timed out, restart window with current contact
                        self.session_start_time = now
                        self.start_radius = radius
                        self.max_radius = radius
                        self.min_radius = radius
                        self.samples = 1
                    else:
                        self.max_radius = max(self.max_radius, radius)
                        self.min_radius = min(self.min_radius, radius)
                        self.samples += 1

                        diff = self.max_radius - radius
                        ratio = radius / max(1.0, self.max_radius)

                        # Live contraction check
                        if elapsed >= 0.035 and (ratio <= self.ratio_thresh or diff >= self.diff_thresh):
                            if (now - self.last_trigger_time) > self.cooldown:
                                self.last_trigger_time = now
                                self.tracking = False
                                print(f"[YogaTouch] Live pinch inward ({n} fingers, ratio={ratio:.2f}, diff={diff:.0f}) on {self.name}")
                                return True
            else:
                # Finger count dropped below threshold (release / lift-off)
                if self.tracking and self.samples >= 2:
                    elapsed = now - self.session_start_time
                    if elapsed < 0.65:
                        contraction_diff = self.max_radius - self.min_radius
                        contraction_ratio = self.min_radius / max(1.0, self.max_radius)
                        if (contraction_ratio <= self.release_ratio_thresh or contraction_diff >= self.release_diff_thresh):
                            if (now - self.last_trigger_time) > self.cooldown:
                                self.last_trigger_time = now
                                self.tracking = False
                                print(f"[YogaTouch] Release pinch inward (ratio={contraction_ratio:.2f}, diff={contraction_diff:.0f}) on {self.name}")
                                return True
                self.tracking = False

        return False


class GestureMonitor(threading.Thread):
    def __init__(self, callback, sensitivity="normal", min_fingers=4, max_fingers=5, cooldown=0.80):
        super().__init__(daemon=True)
        self.callback = callback
        self.sensitivity = sensitivity
        self.min_fingers = min_fingers
        self.max_fingers = max_fingers
        self.cooldown = cooldown
        self.running = True
        self.devices = {}  # fd: (InputDevice, DeviceSlotState)

    def scan_devices(self):
        # Close old file descriptors
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

                # Device must have multi-touch capability
                if ecodes.ABS_MT_SLOT in abs_codes:
                    is_ts = ("finger" in dev.name.lower() or "touchscreen" in dev.name.lower())
                    state = DeviceSlotState(
                        name=dev.name,
                        is_touchscreen=is_ts,
                        sensitivity=self.sensitivity,
                        min_fingers=self.min_fingers,
                        max_fingers=self.max_fingers,
                        cooldown=self.cooldown
                    )
                    self.devices[dev.fd] = (dev, state)
                    print(f"[YogaTouch] GestureMonitor listening on: {dev.name} ({dev.path}) [Touchscreen={is_ts}]")
            except Exception:
                pass

    def run(self):
        self.scan_devices()
        reconnect_cooldown = time.time()

        while self.running:
            if not self.devices:
                time.sleep(2.0)
                self.scan_devices()
                continue

            try:
                r, _, _ = select.select(list(self.devices.keys()), [], [], 1.5)
            except (ValueError, OSError):
                self.scan_devices()
                continue

            for fd in r:
                if fd not in self.devices:
                    continue
                dev, state = self.devices[fd]
                try:
                    for event in dev.read():
                        if state.process_event(event):
                            if self.callback:
                                self.callback()
                except OSError:
                    del self.devices[fd]
                    try:
                        dev.close()
                    except Exception:
                        pass

            # Periodic device rescan every 12 seconds
            if time.time() - reconnect_cooldown > 12.0:
                reconnect_cooldown = time.time()
                current_count = len(self.devices)
                available = []
                for p in evdev.list_devices():
                    try:
                        d = evdev.InputDevice(p)
                        codes = [c[0] if isinstance(c, tuple) else c for c in d.capabilities().get(ecodes.EV_ABS, [])]
                        if ecodes.ABS_MT_SLOT in codes:
                            available.append(p)
                    except Exception:
                        pass
                if len(available) != current_count:
                    self.scan_devices()

    def update_settings(self, sensitivity=None, min_fingers=None, max_fingers=None, cooldown=None):
        if sensitivity:
            self.sensitivity = sensitivity
        if min_fingers is not None:
            self.min_fingers = min_fingers
        if max_fingers is not None:
            self.max_fingers = max_fingers
        if cooldown is not None:
            self.cooldown = cooldown

        for _, state in self.devices.values():
            if sensitivity:
                state.set_sensitivity(sensitivity)
            if min_fingers is not None:
                state.min_fingers = min_fingers
            if max_fingers is not None:
                state.max_fingers = max_fingers
            if cooldown is not None:
                state.cooldown = cooldown

    def stop(self):
        self.running = False
        for fd, (dev, _) in list(self.devices.items()):
            try:
                dev.close()
            except Exception:
                pass
        self.devices.clear()
