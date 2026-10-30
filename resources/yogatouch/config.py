#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - Configuration & Profile Manager (YAML-based)
# Author: Auxerov
# ==============================================================================

import os
import copy
import yaml

CONFIG_DIR = os.path.expanduser("~/.config/yogatouch")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.yaml")
LEGACY_JSON_FILE = os.path.join(CONFIG_DIR, "config.json")

DEFAULT_PROFILES = {
    "Blender 3D": [
        {"name": "Undo", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "chord": "shift+ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Shift", "chord": "shift", "mode": "hold", "color": "zinc"},
        {"name": "Ctrl", "chord": "ctrl", "mode": "hold", "color": "zinc"},
        {"name": "Alt", "chord": "alt", "mode": "hold", "color": "zinc"},
        {"name": "Space", "chord": "space", "mode": "tap", "color": "zinc"},
        {"name": "Front 1", "chord": "num1", "mode": "tap", "color": "zinc"},
        {"name": "Top 7", "chord": "num7", "mode": "tap", "color": "zinc"},
        {"name": "Right 3", "chord": "num3", "mode": "tap", "color": "zinc"},
        {"name": "Camera 0", "chord": "num0", "mode": "tap", "color": "zinc"},
        {"name": "Focus .", "chord": "kpdot", "mode": "tap", "color": "zinc"},
        {"name": "Save", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
    ],
    "Affinity / 2D Art": [
        {"name": "Undo", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "chord": "shift+ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Brush", "chord": "b", "mode": "tap", "color": "purple"},
        {"name": "Eraser", "chord": "e", "mode": "tap", "color": "purple"},
        {"name": "Picker", "chord": "alt", "mode": "hold", "color": "emerald"},
        {"name": "Hand", "chord": "space", "mode": "hold", "color": "emerald"},
        {"name": "Shift", "chord": "shift", "mode": "hold", "color": "zinc"},
        {"name": "Ctrl", "chord": "ctrl", "mode": "hold", "color": "zinc"},
        {"name": "Zoom In", "chord": "ctrl+equal", "mode": "tap", "color": "zinc"},
        {"name": "Zoom Out", "chord": "ctrl+minus", "mode": "tap", "color": "zinc"},
        {"name": "Fit 100%", "chord": "ctrl+0", "mode": "tap", "color": "zinc"},
        {"name": "Save", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
    ],
    "Krita": [
        {"name": "Undo", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "chord": "shift+ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Brush", "chord": "b", "mode": "tap", "color": "purple"},
        {"name": "Eraser", "chord": "e", "mode": "tap", "color": "purple"},
        {"name": "Color", "chord": "ctrl", "mode": "hold", "color": "emerald"},
        {"name": "Hand", "chord": "space", "mode": "hold", "color": "emerald"},
        {"name": "Size", "chord": "shift", "mode": "hold", "color": "zinc"},
        {"name": "Reset View", "chord": "1", "mode": "tap", "color": "zinc"},
        {"name": "Rotate", "chord": "4", "mode": "tap", "color": "zinc"},
        {"name": "Save", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
    ],
    "Foliate Reader": [
        {"name": "Next Page", "chord": "pagedown", "mode": "tap", "color": "blue"},
        {"name": "Prev Page", "chord": "pageup", "mode": "tap", "color": "blue"},
        {"name": "Bookmark", "chord": "ctrl+d", "mode": "tap", "color": "purple"},
        {"name": "Search", "chord": "ctrl+f", "mode": "tap", "color": "zinc"},
        {"name": "Fullscreen", "chord": "f11", "mode": "tap", "color": "zinc"},
        {"name": "Close Book", "chord": "ctrl+w", "mode": "tap", "color": "red"},
    ],
    "General Studio": [
        {"name": "Undo", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
        {"name": "Redo", "chord": "ctrl+y", "mode": "tap", "color": "blue"},
        {"name": "Copy", "chord": "ctrl+c", "mode": "tap", "color": "zinc"},
        {"name": "Paste", "chord": "ctrl+v", "mode": "tap", "color": "zinc"},
        {"name": "Screenshot", "chord": "super+shift+s", "mode": "tap", "color": "purple"},
        {"name": "Search", "chord": "ctrl+f", "mode": "tap", "color": "zinc"},
        {"name": "Save", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
        {"name": "Lock", "chord": "super+l", "mode": "tap", "color": "red"},
    ]
}

DEFAULT_CONFIG = {
    "version": 1,
    "active_profile": "Blender 3D",
    "appearance": {
        "columns": 2,
        "button_size": "standard",  # Options: compact (46px), standard (54px), large (64px)
        "opacity": 0.94,
        "remember_position": True,
        "position": {"x": -1, "y": -1}
    },
    "gestures": {
        "enabled": True,
        "min_fingers": 4,
        "max_fingers": 5,
        "sensitivity": "normal",  # Options: low, normal, high
        "cooldown_seconds": 0.80
    },
    "hotkey": "Super+O",
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
                    loaded = yaml.safe_load(f)
                    if isinstance(loaded, dict):
                        self._deep_update(self.data, loaded)
                        # Sanitize profiles: remove legacy emojis or removed buttons (Orbit, Pan)
                        self._sanitize_profiles()
            except Exception as e:
                print(f"[YogaTouch] Error loading YAML config: {e}. Using defaults.")
        else:
            # If legacy config.json exists, remove it or ignore and initialize clean YAML
            if os.path.exists(LEGACY_JSON_FILE):
                try:
                    os.remove(LEGACY_JSON_FILE)
                except Exception:
                    pass
            self.save()

    def _deep_update(self, base, update):
        for k, v in update.items():
            if isinstance(v, dict) and k in base and isinstance(base[k], dict):
                self._deep_update(base[k], v)
            else:
                base[k] = v

    def _sanitize_profiles(self):
        """Removes Orbit and Pan buttons if present in profiles from older versions."""
        if "profiles" not in self.data or not self.data["profiles"]:
            self.data["profiles"] = copy.deepcopy(DEFAULT_PROFILES)
            return

        for prof_name, buttons in list(self.data["profiles"].items()):
            cleaned_buttons = []
            for b in buttons:
                name = str(b.get("name", "")).strip().lower()
                chord = str(b.get("chord", "")).strip().lower()
                # Remove Orbit and Pan
                if name in ("orbit", "pan") or chord in ("btn_middle", "shift+btn_middle"):
                    continue
                # Strip emoji from icon if present
                if "icon" in b:
                    del b["icon"]
                cleaned_buttons.append(b)
            self.data["profiles"][prof_name] = cleaned_buttons

    def save(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                header = (
                    "# ==============================================================================\n"
                    "# YogaTouch - Configuration & Profiles (YAML)\n"
                    "# PureRef-Style Always-On-Top Floating ExpressKeys for 2-in-1 Linux\n"
                    "# ==============================================================================\n\n"
                )
                f.write(header)
                yaml.dump(
                    self.data,
                    f,
                    sort_keys=False,
                    default_flow_style=False,
                    allow_unicode=True,
                    indent=2
                )
        except Exception as e:
            print(f"[YogaTouch] Error saving YAML config: {e}")

    @property
    def active_profile_name(self):
        name = self.data.get("active_profile", "Blender 3D")
        if name not in self.data.get("profiles", {}):
            keys = list(self.data.get("profiles", {}).keys())
            name = keys[0] if keys else "Blender 3D"
            self.data["active_profile"] = name
        return name

    @active_profile_name.setter
    def active_profile_name(self, name):
        if name in self.data.get("profiles", {}):
            self.data["active_profile"] = name
            self.save()

    @property
    def current_buttons(self):
        return self.data.get("profiles", {}).get(self.active_profile_name, [])

    @property
    def columns(self):
        return self.data.get("appearance", {}).get("columns", 2)

    @columns.setter
    def columns(self, val):
        if "appearance" not in self.data:
            self.data["appearance"] = {}
        self.data["appearance"]["columns"] = val
        self.save()

    @property
    def button_size(self):
        return self.data.get("appearance", {}).get("button_size", "standard")

    @button_size.setter
    def button_size(self, val):
        if "appearance" not in self.data:
            self.data["appearance"] = {}
        self.data["appearance"]["button_size"] = val
        self.save()

    @property
    def opacity(self):
        return self.data.get("appearance", {}).get("opacity", 0.94)

    @opacity.setter
    def opacity(self, val):
        if "appearance" not in self.data:
            self.data["appearance"] = {}
        self.data["appearance"]["opacity"] = val
        self.save()

    @property
    def gesture_sensitivity(self):
        return self.data.get("gestures", {}).get("sensitivity", "normal")

    @gesture_sensitivity.setter
    def gesture_sensitivity(self, val):
        if "gestures" not in self.data:
            self.data["gestures"] = {}
        self.data["gestures"]["sensitivity"] = val
        self.save()

    def cycle_profile(self):
        keys = list(self.data.get("profiles", {}).keys())
        if not keys:
            return
        idx = keys.index(self.active_profile_name) if self.active_profile_name in keys else 0
        next_idx = (idx + 1) % len(keys)
        self.active_profile_name = keys[next_idx]
        return self.active_profile_name
