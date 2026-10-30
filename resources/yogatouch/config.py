#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - Configuration & Profile Manager
# Author: Auxerov
# ==============================================================================

import os
import json
import copy

CONFIG_DIR = os.path.expanduser("~/.config/yogatouch")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

DEFAULT_PROFILES = {
    "Blender 3D": [
        {"name": "Undo", "icon": "↶", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "icon": "↷", "chord": "shift+ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Orbit", "icon": "⤾", "chord": "btn_middle", "mode": "hold", "color": "purple"},
        {"name": "Pan", "icon": "⤿", "chord": "shift+btn_middle", "mode": "hold", "color": "purple"},
        {"name": "Shift", "icon": "⇧", "chord": "shift", "mode": "hold", "color": "zinc"},
        {"name": "Ctrl", "icon": "⌃", "chord": "ctrl", "mode": "hold", "color": "zinc"},
        {"name": "Alt", "icon": "⌥", "chord": "alt", "mode": "hold", "color": "zinc"},
        {"name": "Space", "icon": "␣", "chord": "space", "mode": "tap", "color": "zinc"},
        {"name": "Front 1", "icon": "👁", "chord": "num1", "mode": "tap", "color": "zinc"},
        {"name": "Top 7", "icon": "🔝", "chord": "num7", "mode": "tap", "color": "zinc"},
        {"name": "Focus .", "icon": "🔍", "chord": "kpdot", "mode": "tap", "color": "zinc"},
        {"name": "Save", "icon": "💾", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
    ],
    "Affinity / 2D Art": [
        {"name": "Undo", "icon": "↶", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "icon": "↷", "chord": "shift+ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Brush", "icon": "🖌️", "chord": "b", "mode": "tap", "color": "purple"},
        {"name": "Eraser", "icon": "🧹", "chord": "e", "mode": "tap", "color": "purple"},
        {"name": "Picker", "icon": "💧", "chord": "alt", "mode": "hold", "color": "emerald"},
        {"name": "Hand", "icon": "🖐️", "chord": "space", "mode": "hold", "color": "emerald"},
        {"name": "Shift", "icon": "⇧", "chord": "shift", "mode": "hold", "color": "zinc"},
        {"name": "Ctrl", "icon": "⌃", "chord": "ctrl", "mode": "hold", "color": "zinc"},
        {"name": "Zoom In", "icon": "➕", "chord": "ctrl+equal", "mode": "tap", "color": "zinc"},
        {"name": "Zoom Out", "icon": "➖", "chord": "ctrl+minus", "mode": "tap", "color": "zinc"},
        {"name": "Fit 100%", "icon": "↺", "chord": "ctrl+0", "mode": "tap", "color": "zinc"},
        {"name": "Save", "icon": "💾", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
    ],
    "Krita": [
        {"name": "Undo", "icon": "↶", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "icon": "↷", "chord": "shift+ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Brush", "icon": "🖌️", "chord": "b", "mode": "tap", "color": "purple"},
        {"name": "Eraser", "icon": "🧹", "chord": "e", "mode": "tap", "color": "purple"},
        {"name": "Color", "icon": "💧", "chord": "ctrl", "mode": "hold", "color": "emerald"},
        {"name": "Pan", "icon": "🖐️", "chord": "space", "mode": "hold", "color": "emerald"},
        {"name": "Size", "icon": "↔", "chord": "shift", "mode": "hold", "color": "zinc"},
        {"name": "Reset", "icon": "↺", "chord": "1", "mode": "tap", "color": "zinc"},
        {"name": "Rotate", "icon": "🔄", "chord": "4", "mode": "tap", "color": "zinc"},
        {"name": "Save", "icon": "💾", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
    ],
    "Foliate Reader": [
        {"name": "Next Page", "icon": "⬇", "chord": "pagedown", "mode": "tap", "color": "blue"},
        {"name": "Prev Page", "icon": "⬆", "chord": "pageup", "mode": "tap", "color": "blue"},
        {"name": "Bookmark", "icon": "🔖", "chord": "ctrl+d", "mode": "tap", "color": "purple"},
        {"name": "Search", "icon": "🔍", "chord": "ctrl+f", "mode": "tap", "color": "zinc"},
        {"name": "Fullscreen", "icon": "🖥️", "chord": "f11", "mode": "tap", "color": "zinc"},
        {"name": "Close Book", "icon": "✕", "chord": "ctrl+w", "mode": "tap", "color": "red"},
    ],
    "General Studio": [
        {"name": "Undo", "icon": "↶", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "icon": "↷", "chord": "ctrl+y", "mode": "tap", "color": "blue"},
        {"name": "Copy", "icon": "📋", "chord": "ctrl+c", "mode": "tap", "color": "zinc"},
        {"name": "Paste", "icon": "📥", "chord": "ctrl+v", "mode": "tap", "color": "zinc"},
        {"name": "Screenshot", "icon": "📸", "chord": "super+shift+s", "mode": "tap", "color": "purple"},
        {"name": "Search", "icon": "🔍", "chord": "ctrl+f", "mode": "tap", "color": "zinc"},
        {"name": "Save", "icon": "💾", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
        {"name": "Lock", "icon": "🔒", "chord": "super+l", "mode": "tap", "color": "red"},
    ]
}

DEFAULT_CONFIG = {
    "version": 1,
    "active_profile": "Blender 3D",
    "opacity": 0.94,
    "columns": 2,
    "button_size": "standard",  # compact (46px), standard (54px), large (64px)
    "pinch_sensitivity": "normal",  # low, normal, high
    "position": {"x": -1, "y": -1},
    "remember_position": True,
    "pinned": True,
    "haptic_feedback": False,
    "profiles": DEFAULT_PROFILES
}


class ConfigManager:
    def __init__(self):
        self.data = copy.deepcopy(DEFAULT_CONFIG)
        self.load()

    def load(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    loaded = json.load(f)
                    self.data.update(loaded)
                    # Ensure all default profiles exist
                    if "profiles" not in self.data or not self.data["profiles"]:
                        self.data["profiles"] = copy.deepcopy(DEFAULT_PROFILES)
                    for k, v in DEFAULT_PROFILES.items():
                        if k not in self.data["profiles"]:
                            self.data["profiles"][k] = v
            except Exception as e:
                print(f"[YogaTouch] Error loading config: {e}. Using defaults.")
        else:
            self.save()

    def save(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"[YogaTouch] Error saving config: {e}")

    @property
    def active_profile_name(self):
        name = self.data.get("active_profile", "Blender 3D")
        if name not in self.data["profiles"]:
            name = list(self.data["profiles"].keys())[0]
            self.data["active_profile"] = name
        return name

    @active_profile_name.setter
    def active_profile_name(self, name):
        if name in self.data["profiles"]:
            self.data["active_profile"] = name
            self.save()

    @property
    def current_buttons(self):
        return self.data["profiles"].get(self.active_profile_name, [])

    def cycle_profile(self):
        keys = list(self.data["profiles"].keys())
        if not keys:
            return
        idx = keys.index(self.active_profile_name) if self.active_profile_name in keys else 0
        next_idx = (idx + 1) % len(keys)
        self.active_profile_name = keys[next_idx]
        return self.active_profile_name
