#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - PureRef-Style Always-On-Top Floating ExpressKeys for 2-in-1 Linux
# Author: Auxerov
# Matte Black & Monochrome Edition (Zero Blue Light)
# ==============================================================================

import os
import sys
import gc
import ctypes
import time

# Enforce HiDPI awareness and XCB before any Qt module is imported
os.environ["QT_QPA_PLATFORM"] = "xcb"
os.environ["QT_AUTO_SCREEN_SCALE_FACTOR"] = "1"
os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "1"
os.environ["QT_SCALE_FACTOR_ROUNDING_POLICY"] = "PassThrough"

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QGridLayout, QPushButton, QLabel, QMenu, QDialog, QTabWidget,
    QLineEdit, QComboBox, QSlider, QScrollArea, QMessageBox,
    QFrame, QPlainTextEdit
)
from PyQt6.QtCore import Qt, QPoint, pyqtSignal, QObject, QFileSystemWatcher, QTimer
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtNetwork import QLocalServer, QLocalSocket

from config import ConfigManager, CONFIG_FILE
from uinput_emitter import InputEmitter
from gesture_daemon import GestureMonitor

IPC_SERVER_NAME = f"yogatouch_ipc_{os.getuid()}"


def trim_memory():
    """Forces Python garbage collection and returns freed heap memory to OS."""
    gc.collect()
    try:
        ctypes.CDLL("libc.so.6").malloc_trim(0)
    except Exception:
        pass


class TouchExpressButton(QPushButton):
    """
    A touch-friendly express key button with dual Tap and Hold/Latch modes.
    Never steals focus from active workspace (Blender, Affinity, Krita, etc.).
    Matte Black & Clean White Monochrome (Zero Blue Light).
    """
    def __init__(self, item, emitter, parent=None):
        super().__init__(parent)
        self.item = item
        self.emitter = emitter
        self.is_latched = False

        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents, True)
        self.setup_ui()

    def setup_ui(self):
        name = self.item.get("name", "Key")
        chord = self.item.get("chord", "")
        mode = self.item.get("mode", "tap")

        display_name = name.upper()
        if mode == "hold":
            sub_text = f"{chord.upper()} [HOLD]"
        else:
            sub_text = chord.upper()

        self.setText(f"{display_name}\n{sub_text}")
        self.update_style()

    def update_style(self):
        color = str(self.item.get("color", "zinc")).lower()

        # Soothing Matte Black & Muted Monochrome Palette (Zero Blue Light)
        color_styles = {
            "danger": ("#1E1212", "#3E2222", "#FCA5A5", "#8E8E93"),
            "red": ("#1E1212", "#3E2222", "#FCA5A5", "#8E8E93"),
            "highlight": ("#1A1A1E", "#34343C", "#FFFFFF", "#A8A8B2"),
            "blue": ("#1A1A1E", "#34343C", "#FFFFFF", "#A8A8B2"),
            "purple": ("#18181C", "#303038", "#F4F4F5", "#9C9CA4"),
            "emerald": ("#161619", "#2A2A30", "#F4F4F5", "#94949C"),
            "accent": ("#161619", "#2A2A30", "#F4F4F5", "#94949C"),
            "zinc": ("#161618", "#27272C", "#F4F4F5", "#94949C"),
        }
        bg, border, text_pri, text_sec = color_styles.get(color, color_styles["zinc"])

        if self.is_latched:
            # Clean High-Contrast Inverted White (Monochrome Studio Latch, Zero Blue Light)
            self.setStyleSheet("""
                QPushButton {
                    background-color: #FFFFFF;
                    color: #0A0A0C;
                    border: 2px solid #FFFFFF;
                    border-radius: 9px;
                    font-size: 12px;
                    font-weight: 800;
                    padding: 4px;
                    text-align: center;
                }
            """)
        else:
            self.setStyleSheet(f"""
                QPushButton {{
                    background-color: {bg};
                    color: {text_pri};
                    border: 1px solid {border};
                    border-radius: 9px;
                    font-size: 12px;
                    font-weight: 700;
                    padding: 4px;
                    text-align: center;
                }}
                QPushButton:hover {{
                    background-color: #222228;
                    border: 1px solid #484852;
                    color: #FFFFFF;
                }}
                QPushButton:pressed {{
                    background-color: #303038;
                    border: 1px solid #FFFFFF;
                    color: #FFFFFF;
                }}
            """)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            mode = self.item.get("mode", "tap")
            chord = self.item.get("chord", "")

            if mode == "hold":
                if not self.is_latched:
                    self.emitter.press(chord)
                    self.is_latched = True
                else:
                    self.emitter.release(chord)
                    self.is_latched = False
                self.update_style()
            else:
                self.emitter.tap(chord)
        super().mousePressEvent(event)


class HeaderBar(QFrame):
    """Sleek Matte Black header with profile pill, drag handle, and quick controls."""
    def __init__(self, main_window):
        super().__init__(main_window)
        self.main_window = main_window
        self.dragging = False
        self.drag_start_pos = QPoint()
        self.setup_ui()

    def setup_ui(self):
        self.setFixedHeight(36)
        self.setStyleSheet("""
            QFrame {
                background-color: #141416;
                border-top-left-radius: 12px;
                border-top-right-radius: 12px;
                border-bottom: 1px solid #222226;
            }
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 0, 8, 0)
        layout.setSpacing(6)

        # Profile Pill Button (Matte Black & Soft White, Zero Blue)
        self.profile_btn = QPushButton(self)
        self.profile_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.profile_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.profile_btn.setStyleSheet("""
            QPushButton {
                background-color: #1A1A1E;
                color: #EDEDF0;
                border: 1px solid #2D2D34;
                border-radius: 11px;
                font-size: 11px;
                font-weight: 700;
                letter-spacing: 0.5px;
                padding: 3px 12px;
            }
            QPushButton:hover {
                background-color: #25252C;
                border-color: #484852;
                color: #FFFFFF;
            }
            QPushButton:pressed {
                background-color: #32323A;
                color: #FFFFFF;
            }
        """)
        self.profile_btn.clicked.connect(self.show_profile_menu)
        self.profile_btn.wheelEvent = self.on_profile_btn_wheel
        layout.addWidget(self.profile_btn)

        # Drag handle
        grip = QLabel(":::", self)
        grip.setStyleSheet("color: #4A4A54; font-size: 12px; font-weight: bold;")
        grip.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(grip, 1)

        # Settings button
        settings_btn = QPushButton("CFG", self)
        settings_btn.setFixedSize(32, 22)
        settings_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        settings_btn.setStyleSheet("""
            QPushButton {
                background-color: #18181C;
                color: #9C9CA4;
                border: 1px solid #2A2A30;
                font-size: 10px;
                font-weight: 700;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: #26262C;
                color: #FFFFFF;
                border-color: #484852;
            }
        """)
        settings_btn.clicked.connect(self.main_window.open_settings)
        layout.addWidget(settings_btn)

        # Close / Hide button
        close_btn = QPushButton("✕", self)
        close_btn.setFixedSize(24, 22)
        close_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        close_btn.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                color: #686872;
                border: none;
                font-size: 12px;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: #7F1D1D;
                color: #FCA5A5;
            }
        """)
        close_btn.clicked.connect(self.main_window.hide)
        layout.addWidget(close_btn)

        self.update_profile_title()

    def update_profile_title(self):
        current = self.main_window.config.active_profile_name
        self.profile_btn.setText(f"{current.upper()}  ▾")

    def show_profile_menu(self):
        menu = QMenu(self)
        menu.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        menu.setStyleSheet("""
            QMenu {
                background-color: #121214;
                color: #EDEDF0;
                border: 1px solid #28282E;
                border-radius: 8px;
                padding: 4px;
            }
            QMenu::item {
                padding: 8px 18px 8px 10px;
                border-radius: 5px;
                font-size: 11px;
                font-weight: 600;
                color: #D4D4D8;
                margin: 1px 0px;
            }
            QMenu::item:selected {
                background-color: #24242A;
                color: #FFFFFF;
            }
            QMenu::separator {
                height: 1px;
                background-color: #222226;
                margin: 4px 6px;
            }
        """)

        current_prof = self.main_window.config.active_profile_name
        profiles = list(self.main_window.config.data.get("profiles", {}).keys())

        for prof in profiles:
            btn_count = len(self.main_window.config.data.get("profiles", {}).get(prof, []))
            is_active = (prof == current_prof)
            prefix = "●  " if is_active else "    "
            action = menu.addAction(f"{prefix}{prof.upper()}  ({btn_count})")
            if is_active:
                f = action.font()
                f.setBold(True)
                action.setFont(f)
            action.triggered.connect(lambda _, p=prof: self.main_window.switch_profile(p))

        menu.addSeparator()
        add_act = menu.addAction("+  NEW PROFILE...")
        add_act.triggered.connect(self.main_window.open_new_profile_dialog)

        manage_act = menu.addAction("MANAGE PROFILES...")
        manage_act.triggered.connect(self.main_window.open_settings_profiles)

        btn_pos = self.profile_btn.mapToGlobal(QPoint(0, self.profile_btn.height() + 2))
        menu.exec(btn_pos)

    def on_profile_btn_wheel(self, event):
        delta = event.angleDelta().y()
        keys = list(self.main_window.config.data.get("profiles", {}).keys())
        if not keys:
            return
        cur = self.main_window.config.active_profile_name
        idx = keys.index(cur) if cur in keys else 0
        if delta > 0:
            next_idx = (idx - 1) % len(keys)
        else:
            next_idx = (idx + 1) % len(keys)
        self.main_window.switch_profile(keys[next_idx])
        event.accept()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.dragging = True
            self.drag_start_pos = event.globalPosition().toPoint() - self.main_window.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if self.dragging and event.buttons() == Qt.MouseButton.LeftButton:
            new_pos = event.globalPosition().toPoint() - self.drag_start_pos
            self.main_window.move(new_pos)
            event.accept()

    def mouseReleaseEvent(self, event):
        if self.dragging:
            self.dragging = False
            self.main_window.save_current_position()
            event.accept()

    def mouseDoubleClickEvent(self, event):
        self.main_window.snap_to_corner("top-right")


class SettingsDialog(QDialog):
    """Full settings and configuration window for profiles, buttons, layout, gestures, and YAML."""
    def __init__(self, main_window):
        super().__init__(main_window)
        self.main_window = main_window
        self.config = main_window.config
        self.setWindowTitle("YogaTouch Settings")
        self.setFixedSize(620, 560)
        self.setStyleSheet("""
            QDialog {
                background-color: #121214;
                color: #EDEDF0;
            }
            QTabWidget::pane {
                border: 1px solid #28282E;
                background-color: #161618;
                border-radius: 8px;
            }
            QTabBar::tab {
                background-color: #1A1A1E;
                color: #9C9CA4;
                padding: 8px 16px;
                border: 1px solid #28282E;
                border-bottom: none;
                border-top-left-radius: 6px;
                border-top-right-radius: 6px;
                margin-right: 2px;
                font-size: 12px;
                font-weight: 500;
            }
            QTabBar::tab:selected {
                background-color: #24242A;
                color: #FFFFFF;
                font-weight: bold;
                border-color: #383840;
            }
            QLabel {
                color: #D4D4D8;
                font-size: 13px;
            }
            QLineEdit, QComboBox, QPlainTextEdit {
                background-color: #1A1A1E;
                color: #FFFFFF;
                border: 1px solid #383840;
                border-radius: 6px;
                padding: 6px;
            }
            QPushButton {
                background-color: #24242A;
                color: #FFFFFF;
                border: 1px solid #383840;
                border-radius: 6px;
                padding: 6px 14px;
                font-weight: 600;
            }
            QPushButton:hover {
                background-color: #32323A;
                border-color: #484852;
            }
        """)
        self.setup_ui()

    def setup_ui(self):
        main_layout = QVBoxLayout(self)

        self.tabs = QTabWidget(self)
        self.setup_buttons_tab()
        self.setup_profiles_tab()
        self.setup_layout_gestures_tab()
        self.setup_yaml_tab()
        main_layout.addWidget(self.tabs)

        btn_layout = QHBoxLayout()
        reset_pos_btn = QPushButton("Reset Position (Top-Right)", self)
        reset_pos_btn.clicked.connect(self.reset_position)
        btn_layout.addWidget(reset_pos_btn)

        btn_layout.addStretch()

        close_btn = QPushButton("Done", self)
        close_btn.setStyleSheet("background-color: #2C2C34; color: #FFFFFF; font-weight: bold;")
        close_btn.clicked.connect(self.accept)
        btn_layout.addWidget(close_btn)
        main_layout.addLayout(btn_layout)

    def reset_position(self):
        self.main_window.snap_to_corner("top-right")

    def setup_buttons_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        top_bar = QHBoxLayout()
        top_bar.addWidget(QLabel("Active Profile:"))
        self.profile_combo = QComboBox(tab)
        self.profile_combo.addItems(list(self.config.data.get("profiles", {}).keys()))
        self.profile_combo.setCurrentText(self.config.active_profile_name)
        self.profile_combo.currentTextChanged.connect(self.on_profile_switched)
        top_bar.addWidget(self.profile_combo, 1)

        add_btn = QPushButton("+ Add Button", tab)
        add_btn.clicked.connect(self.add_button_dialog)
        top_bar.addWidget(add_btn)
        layout.addLayout(top_bar)

        scroll = QScrollArea(tab)
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("background-color: transparent; border: none;")
        self.buttons_container = QWidget()
        self.buttons_vbox = QVBoxLayout(self.buttons_container)
        self.buttons_vbox.setSpacing(6)
        scroll.setWidget(self.buttons_container)
        layout.addWidget(scroll)

        self.refresh_buttons_list()
        self.tabs.addTab(tab, "Buttons")

    def refresh_buttons_list(self):
        while self.buttons_vbox.count():
            item = self.buttons_vbox.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        profile = self.profile_combo.currentText()
        buttons = self.config.data.get("profiles", {}).get(profile, [])

        for idx, btn in enumerate(buttons):
            row = QFrame()
            row.setStyleSheet("""
                QFrame {
                    background-color: #18181B;
                    border: 1px solid #28282E;
                    border-radius: 6px;
                    padding: 4px;
                }
            """)
            rl = QHBoxLayout(row)
            rl.setContentsMargins(8, 4, 8, 4)

            name = btn.get("name", "")
            chord = btn.get("chord", "")
            mode = btn.get("mode", "tap")

            label = QLabel(f"<b>{name.upper()}</b>  <span style='color: #9C9CA4'>[{chord.upper()}]</span>  <span style='color: #D4D4D8; font-size:11px'>({mode.upper()})</span>")
            rl.addWidget(label, 1)

            del_btn = QPushButton("✕", row)
            del_btn.setFixedSize(24, 24)
            del_btn.setStyleSheet("background-color: #5C1D1D; color: #FCA5A5; border: none; border-radius: 4px;")
            del_btn.clicked.connect(lambda _, i=idx: self.delete_button(i))
            rl.addWidget(del_btn)

            self.buttons_vbox.addWidget(row)

        self.buttons_vbox.addStretch()

    def on_profile_switched(self, name):
        if not name:
            return
        self.config.active_profile_name = name
        self.refresh_buttons_list()
        self.main_window.rebuild_buttons()
        self.main_window.header.update_profile_title()

    def delete_button(self, index):
        profile = self.profile_combo.currentText()
        buttons = self.config.data.get("profiles", {}).get(profile, [])
        if 0 <= index < len(buttons):
            del buttons[index]
            self.config.save()
            self.refresh_buttons_list()
            self.main_window.rebuild_buttons()
            self.sync_yaml_tab_content()

    def add_button_dialog(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Add Express Button")
        dlg.setFixedSize(380, 260)
        dlg.setStyleSheet(self.styleSheet())
        layout = QVBoxLayout(dlg)

        layout.addWidget(QLabel("Button Name:"))
        name_in = QLineEdit(dlg)
        name_in.setPlaceholderText("e.g. Undo, Redo, Shift, Brush, Fit View")
        layout.addWidget(name_in)

        layout.addWidget(QLabel("Key Shortcut (e.g. ctrl+z, b, space, shift, alt):"))
        chord_in = QLineEdit(dlg)
        chord_in.setPlaceholderText("ctrl+z, shift+ctrl+z, space, b, num1...")
        layout.addWidget(chord_in)

        layout.addWidget(QLabel("Action Mode:"))
        mode_combo = QComboBox(dlg)
        mode_combo.addItems(["tap", "hold"])
        layout.addWidget(mode_combo)

        btn_box = QHBoxLayout()
        ok_btn = QPushButton("Add", dlg)
        ok_btn.clicked.connect(dlg.accept)
        btn_box.addWidget(ok_btn)
        layout.addLayout(btn_box)

        if dlg.exec():
            name = name_in.text().strip() or "Key"
            chord = chord_in.text().strip().lower() or "ctrl+z"
            mode = mode_combo.currentText()

            profile = self.profile_combo.currentText()
            if profile in self.config.data.get("profiles", {}):
                self.config.data["profiles"][profile].append({
                    "name": name,
                    "chord": chord,
                    "mode": mode,
                    "color": "zinc"
                })
                self.config.save()
                self.refresh_buttons_list()
                self.main_window.rebuild_buttons()
                self.sync_yaml_tab_content()

    def setup_profiles_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        layout.addWidget(QLabel("<b>Manage Profiles</b>"))

        row = QHBoxLayout()
        self.new_profile_name = QLineEdit(tab)
        self.new_profile_name.setPlaceholderText("New profile name...")
        row.addWidget(self.new_profile_name, 1)

        create_btn = QPushButton("+ Create Profile", tab)
        create_btn.clicked.connect(self.create_profile)
        row.addWidget(create_btn)
        layout.addLayout(row)

        layout.addWidget(QLabel("Existing Profiles:"))
        self.profiles_vbox = QVBoxLayout()
        layout.addLayout(self.profiles_vbox)
        layout.addStretch()

        self.refresh_profiles_tab()
        self.tabs.addTab(tab, "Profiles")

    def refresh_profiles_tab(self):
        while self.profiles_vbox.count():
            item = self.profiles_vbox.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        for name in list(self.config.data.get("profiles", {}).keys()):
            row = QFrame()
            row.setStyleSheet("background-color: #18181B; border: 1px solid #28282E; border-radius: 6px; padding: 4px;")
            rl = QHBoxLayout(row)
            btn_count = len(self.config.data["profiles"].get(name, []))
            rl.addWidget(QLabel(f"<b>{name}</b> ({btn_count} buttons)"), 1)

            if len(self.config.data.get("profiles", {})) > 1:
                del_btn = QPushButton("Delete", row)
                del_btn.setStyleSheet("background-color: #5C1D1D; color: #FFFFFF; font-size: 11px;")
                del_btn.clicked.connect(lambda _, n=name: self.delete_profile(n))
                rl.addWidget(del_btn)

            self.profiles_vbox.addWidget(row)

    def create_profile(self):
        name = self.new_profile_name.text().strip()
        if not name:
            return
        if name in self.config.data.get("profiles", {}):
            QMessageBox.warning(self, "Exists", "A profile with that name already exists!")
            return
        self.config.data["profiles"][name] = [
            {"name": "Undo", "chord": "ctrl+z", "mode": "tap", "color": "highlight"},
            {"name": "Redo", "chord": "shift+ctrl+z", "mode": "tap", "color": "highlight"},
            {"name": "Save", "chord": "ctrl+s", "mode": "tap", "color": "accent"},
        ]
        self.config.save()
        self.new_profile_name.clear()
        self.profile_combo.clear()
        self.profile_combo.addItems(list(self.config.data["profiles"].keys()))
        self.profile_combo.setCurrentText(name)
        self.refresh_profiles_tab()
        self.sync_yaml_tab_content()

    def delete_profile(self, name):
        if name in self.config.data.get("profiles", {}):
            del self.config.data["profiles"][name]
            if self.config.active_profile_name == name:
                keys = list(self.config.data["profiles"].keys())
                self.config.active_profile_name = keys[0] if keys else "Blender 3D"
            self.config.save()
            self.profile_combo.clear()
            self.profile_combo.addItems(list(self.config.data["profiles"].keys()))
            self.profile_combo.setCurrentText(self.config.active_profile_name)
            self.refresh_profiles_tab()
            self.sync_yaml_tab_content()

    def setup_layout_gestures_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Columns
        layout.addWidget(QLabel("Grid Columns:"))
        cols_combo = QComboBox(tab)
        cols_combo.addItems(["1 Column", "2 Columns (Default)", "3 Columns", "4 Columns"])
        cols_combo.setCurrentIndex(max(0, min(3, self.config.columns - 1)))
        cols_combo.currentIndexChanged.connect(lambda idx: self.set_cols(idx + 1))
        layout.addWidget(cols_combo)

        # Button Size
        layout.addWidget(QLabel("Button Size (Touch Comfort):"))
        size_combo = QComboBox(tab)
        size_combo.addItems(["Compact (54px)", "Standard (66px - Touch)", "Large (80px)"])
        cur_size = self.config.button_size
        size_map = {"compact": 0, "standard": 1, "large": 2}
        size_combo.setCurrentIndex(size_map.get(cur_size, 1))
        size_combo.currentIndexChanged.connect(self.set_btn_size)
        layout.addWidget(size_combo)

        # Opacity
        layout.addWidget(QLabel("Default Opacity (PureRef Style):"))
        opacity_slider = QSlider(Qt.Orientation.Horizontal, tab)
        opacity_slider.setRange(20, 100)
        opacity_slider.setValue(int(self.config.opacity * 100))
        opacity_slider.valueChanged.connect(lambda val: self.set_opacity(val / 100.0))
        layout.addWidget(opacity_slider)

        # 4 / 5-Finger Gesture Configuration
        layout.addSpacing(6)
        layout.addWidget(QLabel("<b>Multi-Finger Pinch Inward Gesture:</b>"))

        fingers_row = QHBoxLayout()
        fingers_row.addWidget(QLabel("Fingers:"))
        self.fingers_combo = QComboBox(tab)
        self.fingers_combo.addItems(["4 or 5 Fingers (Recommended)", "4 Fingers Only", "5 Fingers Only"])
        cur_min_f = self.config.data.get("gestures", {}).get("min_fingers", 4)
        cur_max_f = self.config.data.get("gestures", {}).get("max_fingers", 5)
        if cur_min_f == 4 and cur_max_f == 5:
            self.fingers_combo.setCurrentIndex(0)
        elif cur_min_f == 4 and cur_max_f == 4:
            self.fingers_combo.setCurrentIndex(1)
        elif cur_min_f == 5 and cur_max_f == 5:
            self.fingers_combo.setCurrentIndex(2)
        self.fingers_combo.currentIndexChanged.connect(self.set_fingers)
        fingers_row.addWidget(self.fingers_combo, 1)
        layout.addLayout(fingers_row)

        sens_row = QHBoxLayout()
        sens_row.addWidget(QLabel("Sensitivity:"))
        sens_combo = QComboBox(tab)
        sens_combo.addItems(["Normal (Balanced)", "High (Instant Trigger)", "Low (Deliberate Pinch)"])
        sens_map = {"normal": 0, "high": 1, "low": 2}
        cur_sens = self.config.gesture_sensitivity
        sens_combo.setCurrentIndex(sens_map.get(cur_sens, 0))
        sens_combo.currentIndexChanged.connect(self.set_sensitivity)
        sens_row.addWidget(sens_combo, 1)
        layout.addLayout(sens_row)

        layout.addSpacing(10)
        layout.addWidget(QLabel("<b>Keyboard Shortcut:</b> <span style='color: #EDEDF0'>Super + O</span> (or run <code>yogatouch --toggle</code>)"))

        layout.addStretch()
        self.tabs.addTab(tab, "Layout & Gestures")

    def set_cols(self, cols):
        self.config.columns = cols
        self.main_window.rebuild_buttons()
        self.sync_yaml_tab_content()

    def set_btn_size(self, idx):
        sizes = ["compact", "standard", "large"]
        self.config.button_size = sizes[idx]
        self.main_window.rebuild_buttons()
        self.sync_yaml_tab_content()

    def set_opacity(self, val):
        self.config.opacity = val
        self.main_window.setWindowOpacity(val)
        self.sync_yaml_tab_content()

    def set_fingers(self, idx):
        if "gestures" not in self.config.data:
            self.config.data["gestures"] = {}
        if idx == 0:
            self.config.data["gestures"]["min_fingers"] = 4
            self.config.data["gestures"]["max_fingers"] = 5
        elif idx == 1:
            self.config.data["gestures"]["min_fingers"] = 4
            self.config.data["gestures"]["max_fingers"] = 4
        elif idx == 2:
            self.config.data["gestures"]["min_fingers"] = 5
            self.config.data["gestures"]["max_fingers"] = 5
        self.config.save()
        if self.main_window.gesture_monitor:
            self.main_window.gesture_monitor.update_settings(
                min_fingers=self.config.data["gestures"]["min_fingers"],
                max_fingers=self.config.data["gestures"]["max_fingers"]
            )
        self.sync_yaml_tab_content()

    def set_sensitivity(self, idx):
        sens_list = ["normal", "high", "low"]
        sens = sens_list[idx]
        self.config.gesture_sensitivity = sens
        if self.main_window.gesture_monitor:
            self.main_window.gesture_monitor.update_settings(sensitivity=sens)
        self.sync_yaml_tab_content()

    def setup_yaml_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        path_lbl = QLabel(f"<b>Config File:</b> <span style='color: #EDEDF0'>{CONFIG_FILE}</span>")
        path_lbl.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        layout.addWidget(path_lbl)

        btn_row = QHBoxLayout()
        open_ext_btn = QPushButton("Open in Text Editor", tab)
        open_ext_btn.clicked.connect(self.open_yaml_externally)
        btn_row.addWidget(open_ext_btn)

        reload_btn = QPushButton("Reload from Disk", tab)
        reload_btn.clicked.connect(self.sync_yaml_tab_content)
        btn_row.addWidget(reload_btn)

        btn_row.addStretch()

        apply_btn = QPushButton("Save & Apply YAML", tab)
        apply_btn.setStyleSheet("background-color: #2D3A30; border: 1px solid #3E5A44; color: #FFFFFF; font-weight: bold;")
        apply_btn.clicked.connect(self.save_and_apply_yaml)
        btn_row.addWidget(apply_btn)
        layout.addLayout(btn_row)

        self.yaml_editor = QPlainTextEdit(tab)
        font = QFont("monospace", 10)
        self.yaml_editor.setFont(font)
        self.yaml_editor.setStyleSheet("""
            QPlainTextEdit {
                background-color: #0E0E10;
                color: #EDEDF0;
                border: 1px solid #28282E;
                border-radius: 6px;
                padding: 6px;
                line-height: 1.3;
            }
        """)
        layout.addWidget(self.yaml_editor, 1)

        self.sync_yaml_tab_content()
        self.tabs.addTab(tab, "YAML Config")

    def sync_yaml_tab_content(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    content = f.read()
                self.yaml_editor.setPlainText(content)
            except Exception as e:
                self.yaml_editor.setPlainText(f"# Error reading YAML: {e}")

    def open_yaml_externally(self):
        import subprocess
        try:
            subprocess.Popen(["xdg-open", CONFIG_FILE])
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Could not launch editor: {e}")

    def save_and_apply_yaml(self):
        import yaml
        raw_text = self.yaml_editor.toPlainText()
        try:
            parsed = yaml.safe_load(raw_text)
            if not isinstance(parsed, dict):
                raise ValueError("YAML root must be a mapping (dictionary).")
        except Exception as e:
            QMessageBox.critical(self, "YAML Syntax Error", f"Failed to parse YAML:\n\n{e}")
            return

        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                f.write(raw_text)
            self.main_window.config.load()
            self.main_window.apply_config_update()
            self.refresh_buttons_list()
            self.refresh_profiles_tab()
            QMessageBox.information(self, "Applied", "YAML configuration saved and applied successfully!")
        except Exception as e:
            QMessageBox.critical(self, "Save Error", f"Failed to save file: {e}")


class GestureBridge(QObject):
    gesture_triggered = pyqtSignal()


class YogaTouchWindow(QMainWindow):
    """Main PureRef-style floating touch express window."""
    def __init__(self):
        super().__init__()
        self.config = ConfigManager()
        self.emitter = InputEmitter()
        self.bridge = GestureBridge()
        self.bridge.gesture_triggered.connect(self.toggle_visibility)

        self.gesture_monitor = None
        self.buttons = []
        self._last_mtime = 0

        self.setup_window()
        self.setup_ui()
        self.start_gesture_monitor()
        self.setup_file_watcher()
        self.setup_ipc()

        trim_memory()

    def setup_window(self):
        self.setWindowFlags(
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.Tool |
            Qt.WindowType.WindowDoesNotAcceptFocus
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents, True)
        self.setWindowOpacity(self.config.opacity)

    def setup_ui(self):
        self.container = QFrame(self)
        self.container.setStyleSheet("""
            QFrame#mainContainer {
                background-color: #121214;
                border: 1.5px solid #28282E;
                border-radius: 13px;
            }
        """)
        self.container.setObjectName("mainContainer")

        self.setCentralWidget(self.container)

        self.main_layout = QVBoxLayout(self.container)
        self.main_layout.setContentsMargins(0, 0, 0, 8)
        self.main_layout.setSpacing(6)

        # Header bar
        self.header = HeaderBar(self)
        self.main_layout.addWidget(self.header)

        # Buttons grid container
        self.grid_widget = QWidget(self.container)
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setContentsMargins(8, 0, 8, 0)
        self.grid_layout.setSpacing(6)
        self.main_layout.addWidget(self.grid_widget)

        self.rebuild_buttons()
        self.restore_or_default_position()

    def rebuild_buttons(self):
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self.buttons.clear()

        btn_items = self.config.current_buttons
        cols = max(1, self.config.columns)
        btn_size = self.config.button_size

        # Touch-friendly dimensions
        height_map = {"compact": 54, "standard": 66, "large": 80}
        width_map = {"compact": 112, "standard": 132, "large": 154}

        btn_height = height_map.get(btn_size, 66)
        width_per_col = width_map.get(btn_size, 132)

        for idx, item in enumerate(btn_items):
            btn = TouchExpressButton(item, self.emitter, self.grid_widget)
            btn.setFixedHeight(btn_height)
            r = idx // cols
            c = idx % cols
            self.grid_layout.addWidget(btn, r, c)
            self.buttons.append(btn)

        total_width = max(180, (cols * width_per_col) + 16)
        self.setFixedWidth(total_width)
        self.adjustSize()

    def cycle_profile(self):
        self.config.cycle_profile()
        self.header.update_profile_title()
        self.rebuild_buttons()

    def open_settings(self):
        dlg = SettingsDialog(self)
        dlg.exec()
        dlg.deleteLater()
        trim_memory()

    def open_settings_profiles(self):
        dlg = SettingsDialog(self)
        dlg.tabs.setCurrentIndex(1)
        dlg.exec()
        dlg.deleteLater()
        trim_memory()

    def open_new_profile_dialog(self):
        from PyQt6.QtWidgets import QInputDialog
        name, ok = QInputDialog.getText(self, "New Profile", "Enter software profile name:")
        if ok and name.strip():
            name = name.strip()
            if name in self.config.data.get("profiles", {}):
                QMessageBox.warning(self, "Exists", "A profile with that name already exists!")
                return
            self.config.data.setdefault("profiles", {})[name] = [
                {"name": "Undo", "chord": "ctrl+z", "mode": "tap", "color": "highlight"},
                {"name": "Redo", "chord": "shift+ctrl+z", "mode": "tap", "color": "highlight"},
                {"name": "Save", "chord": "ctrl+s", "mode": "tap", "color": "accent"},
            ]
            self.config.active_profile_name = name
            self.config.save()
            self.header.update_profile_title()
            self.rebuild_buttons()

    def snap_to_corner(self, corner="top-right"):
        screen = QApplication.primaryScreen()
        geom = screen.availableGeometry() if screen else None
        if not geom:
            return

        w, h = self.width(), self.height()
        margin = 24

        if corner == "top-right":
            x = geom.x() + geom.width() - w - margin
            y = geom.y() + 36
        elif corner == "top-left":
            x = geom.x() + margin
            y = geom.y() + 36
        elif corner == "bottom-right":
            x = geom.x() + geom.width() - w - margin
            y = geom.y() + geom.height() - h - margin
        elif corner == "bottom-left":
            x = geom.x() + margin
            y = geom.y() + geom.height() - h - margin
        else:
            x = geom.x() + (geom.width() - w) // 2
            y = geom.y() + (geom.height() - h) // 2

        self.move(x, y)
        self.save_current_position()

    def restore_or_default_position(self):
        pos = self.config.data.get("appearance", {}).get("position", {"x": -1, "y": -1})
        x = pos.get("x", -1)
        y = pos.get("y", -1)

        screen = QApplication.primaryScreen()
        if screen:
            geom = screen.availableGeometry()
            dock_w = self.width()
            dock_h = self.height()

            # Sanity check: Ensure position is comfortably within screen and not trapped in top-left corner
            is_valid = (
                x >= geom.x() + 20 and
                x + dock_w <= geom.x() + geom.width() + 10 and
                y >= geom.y() + 20 and
                y + dock_h <= geom.y() + geom.height() + 10 and
                not (x < 120 and y < 100)
            )
            if is_valid and self.config.data.get("appearance", {}).get("remember_position", True):
                self.move(x, y)
                return

        self.snap_to_corner("top-right")

    def save_current_position(self):
        if "appearance" not in self.config.data:
            self.config.data["appearance"] = {}
        self.config.data["appearance"]["position"] = {"x": self.x(), "y": self.y()}
        self.config.save()

    def wheelEvent(self, event):
        delta = event.angleDelta().y()
        cur_op = self.windowOpacity()
        new_op = max(0.20, min(1.0, cur_op + (0.05 if delta > 0 else -0.05)))
        self.setWindowOpacity(new_op)
        self.config.opacity = new_op
        event.accept()

    def contextMenuEvent(self, event):
        menu = QMenu(self)
        menu.setStyleSheet("""
            QMenu {
                background-color: #121214;
                color: #EDEDF0;
                border: 1px solid #28282E;
                border-radius: 8px;
                padding: 4px;
            }
            QMenu::item {
                padding: 6px 18px;
                border-radius: 4px;
                font-size: 12px;
                color: #D4D4D8;
            }
            QMenu::item:selected {
                background-color: #24242A;
                color: #FFFFFF;
            }
        """)

        profile_menu = menu.addMenu("Switch Profile")
        current_prof = self.config.active_profile_name
        for p in self.config.data.get("profiles", {}).keys():
            prefix = "●  " if p == current_prof else "    "
            btn_count = len(self.config.data.get("profiles", {}).get(p, []))
            action = profile_menu.addAction(f"{prefix}{p.upper()}  ({btn_count})")
            if p == current_prof:
                f = action.font()
                f.setBold(True)
                action.setFont(f)
            action.triggered.connect(lambda _, name=p: self.switch_profile(name))

        menu.addSeparator()

        settings_act = menu.addAction("Settings & YAML...")
        settings_act.triggered.connect(self.open_settings)

        snap_menu = menu.addMenu("Snap to Corner")
        snap_menu.addAction("Top-Right (Default)").triggered.connect(lambda: self.snap_to_corner("top-right"))
        snap_menu.addAction("Top-Left").triggered.connect(lambda: self.snap_to_corner("top-left"))
        snap_menu.addAction("Bottom-Right").triggered.connect(lambda: self.snap_to_corner("bottom-right"))
        snap_menu.addAction("Bottom-Left").triggered.connect(lambda: self.snap_to_corner("bottom-left"))

        op_menu = menu.addMenu("Opacity")
        op_menu.addAction("100%").triggered.connect(lambda: self.set_opacity_direct(1.0))
        op_menu.addAction("80%").triggered.connect(lambda: self.set_opacity_direct(0.80))
        op_menu.addAction("60%").triggered.connect(lambda: self.set_opacity_direct(0.60))
        op_menu.addAction("40%").triggered.connect(lambda: self.set_opacity_direct(0.40))

        menu.addSeparator()

        hide_act = menu.addAction("Hide Overlay (Pinch to Reopen)")
        hide_act.triggered.connect(self.hide)

        quit_act = menu.addAction("Quit YogaTouch")
        quit_act.triggered.connect(self.quit_app)

        menu.exec(event.globalPos())

    def switch_profile(self, name):
        self.config.active_profile_name = name
        self.header.update_profile_title()
        self.rebuild_buttons()

    def set_opacity_direct(self, val):
        self.setWindowOpacity(val)
        self.config.opacity = val

    def toggle_visibility(self):
        if self.isVisible():
            self.hide()
            trim_memory()
        else:
            self.show()
            self.raise_()

    def start_gesture_monitor(self):
        g_conf = self.config.data.get("gestures", {})
        min_f = g_conf.get("min_fingers", 4)
        max_f = g_conf.get("max_fingers", 5)
        sens = g_conf.get("sensitivity", "normal")
        cd = g_conf.get("cooldown_seconds", 0.80)

        self.gesture_monitor = GestureMonitor(
            callback=self.bridge.gesture_triggered.emit,
            sensitivity=sens,
            min_fingers=min_f,
            max_fingers=max_f,
            cooldown=cd
        )
        self.gesture_monitor.start()

    def setup_file_watcher(self):
        self.watcher = QFileSystemWatcher(self)
        if os.path.exists(CONFIG_FILE):
            self.watcher.addPath(CONFIG_FILE)
            self._last_mtime = os.path.getmtime(CONFIG_FILE)
        self.watcher.fileChanged.connect(self.on_file_changed)

    def on_file_changed(self, path):
        QTimer.singleShot(150, self._reload_from_external_edit)

    def _reload_from_external_edit(self):
        if not os.path.exists(CONFIG_FILE):
            return
        mtime = os.path.getmtime(CONFIG_FILE)
        if mtime != self._last_mtime:
            self._last_mtime = mtime
            print("[YogaTouch] Detected external change in config.yaml. Reloading...")
            self.config.load()
            self.apply_config_update()
            if CONFIG_FILE not in self.watcher.files():
                self.watcher.addPath(CONFIG_FILE)

    def apply_config_update(self):
        self.setWindowOpacity(self.config.opacity)
        self.header.update_profile_title()
        self.rebuild_buttons()
        if self.gesture_monitor:
            g_conf = self.config.data.get("gestures", {})
            self.gesture_monitor.update_settings(
                sensitivity=g_conf.get("sensitivity", "normal"),
                min_fingers=g_conf.get("min_fingers", 4),
                max_fingers=g_conf.get("max_fingers", 5),
                cooldown=g_conf.get("cooldown_seconds", 0.80)
            )

    def setup_ipc(self):
        self.ipc_server = QLocalServer(self)
        self.ipc_server.removeServer(IPC_SERVER_NAME)
        self.ipc_server.newConnection.connect(self.handle_ipc_connection)
        self.ipc_server.listen(IPC_SERVER_NAME)

    def handle_ipc_connection(self):
        socket = self.ipc_server.nextPendingConnection()
        if not socket:
            return
        socket.readyRead.connect(lambda: self.process_ipc_message(socket))

    def process_ipc_message(self, socket):
        cmd = bytes(socket.readAll()).decode("utf-8").strip()
        if cmd == "toggle":
            self.toggle_visibility()
            socket.write(b"ok:toggled\n")
        elif cmd == "show":
            self.show()
            self.raise_()
            socket.write(b"ok:shown\n")
        elif cmd == "hide":
            self.hide()
            trim_memory()
            socket.write(b"ok:hidden\n")
        elif cmd.startswith("profile:"):
            prof = cmd.split(":", 1)[1]
            self.switch_profile(prof)
            socket.write(b"ok:profile_switched\n")
        elif cmd == "ping":
            socket.write(b"pong\n")
        socket.flush()
        socket.disconnectFromServer()

    def quit_app(self):
        if self.gesture_monitor:
            self.gesture_monitor.stop()
        self.emitter.close()
        QApplication.quit()

    def closeEvent(self, event):
        self.hide()
        trim_memory()
        event.ignore()


def send_ipc_command(cmd):
    socket = QLocalSocket()
    socket.connectToServer(IPC_SERVER_NAME)
    if socket.waitForConnected(600):
        socket.write(f"{cmd}\n".encode("utf-8"))
        socket.waitForBytesWritten(500)
        if socket.waitForReadyRead(500):
            reply = bytes(socket.readAll()).decode("utf-8").strip()
            print(f"[YogaTouch] Daemon response: {reply}")
        socket.disconnectFromServer()
        return True
    return False


def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in ["--toggle", "-t", "toggle"]:
            if send_ipc_command("toggle"):
                sys.exit(0)
        elif arg in ["--show", "-s", "show"]:
            if send_ipc_command("show"):
                sys.exit(0)
        elif arg in ["--hide", "-h", "hide"]:
            if send_ipc_command("hide"):
                sys.exit(0)
        elif arg in ["--profile", "-p"] and len(sys.argv) > 2:
            if send_ipc_command(f"profile:{sys.argv[2]}"):
                sys.exit(0)
        elif arg in ["--status"]:
            if send_ipc_command("ping"):
                print("YogaTouch is running.")
                sys.exit(0)
            else:
                print("YogaTouch is not running.")
                sys.exit(1)

    if send_ipc_command("toggle"):
        print("[YogaTouch] Existing instance toggled.")
        sys.exit(0)

    app = QApplication(sys.argv)
    app.setApplicationName("YogaTouch")
    app.setApplicationDisplayName("YogaTouch ExpressKeys")

    window = YogaTouchWindow()
    window.show()

    try:
        sys.exit(app.exec())
    finally:
        window.quit_app()


if __name__ == "__main__":
    main()
