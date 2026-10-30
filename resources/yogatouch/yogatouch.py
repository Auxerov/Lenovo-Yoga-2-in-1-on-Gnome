#!/usr/bin/env python3
# ==============================================================================
# YogaTouch - PureRef-Style Always-On-Top Floating ExpressKeys for 2-in-1 Linux
# Author: Auxerov
# ==============================================================================

import os
import sys

# Force XCB (XWayland) for reliable Always-on-Top and Non-Focus-Stealing in GNOME Wayland
os.environ["QT_QPA_PLATFORM"] = "xcb"

import json
import time
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QGridLayout, QPushButton, QLabel, QMenu, QDialog, QTabWidget,
    QLineEdit, QComboBox, QSlider, QSpinBox, QCheckBox, QScrollArea,
    QColorDialog, QMessageBox, QFrame, QGraphicsDropShadowEffect
)
from PyQt6.QtCore import Qt, QPoint, QSize, pyqtSignal, QObject
from PyQt6.QtGui import QColor, QFont, QIcon, QAction, QCursor
from PyQt6.QtNetwork import QLocalServer, QLocalSocket

from config import ConfigManager
from uinput_emitter import InputEmitter
from gesture_daemon import GestureMonitor

IPC_SERVER_NAME = f"yogatouch_ipc_{os.getuid()}"


class TouchExpressButton(QPushButton):
    """
    A touch-friendly express key button with dual Tap and Hold/Latch modes.
    Never steals focus from the active workspace (Blender, Affinity, etc.).
    """
    def __init__(self, item, emitter, parent=None):
        super().__init__(parent)
        self.item = item
        self.emitter = emitter
        self.is_latched = False
        self.press_start_time = 0
        
        # NEVER steal keyboard/window focus
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents, True)
        
        self.setup_ui()

    def setup_ui(self):
        name = self.item.get("name", "Key")
        icon = self.item.get("icon", "")
        chord = self.item.get("chord", "")
        mode = self.item.get("mode", "tap")
        color = self.item.get("color", "zinc")

        display_text = f"{icon} {name}".strip() if icon else name
        sub_text = chord.upper() if mode == "tap" else f"{chord.upper()} (HOLD)"
        
        # Dual-line label
        self.setText(f"{display_text}\n{sub_text}")
        self.update_style()

    def update_style(self):
        color = self.item.get("color", "zinc")
        mode = self.item.get("mode", "tap")
        
        # Color palette
        color_accents = {
            "blue": ("#1E293B", "#3B82F6", "#60A5FA", "#2563EB"),
            "purple": ("#2E1065", "#A855F7", "#C084FC", "#7C3AED"),
            "emerald": ("#064E3B", "#10B981", "#34D399", "#059669"),
            "red": ("#450A0A", "#EF4444", "#F87171", "#DC2626"),
            "zinc": ("#18181B", "#3F3F46", "#71717A", "#27272A"),
        }
        bg, border, text_sub, active_border = color_accents.get(color, color_accents["zinc"])

        if self.is_latched:
            self.setStyleSheet(f"""
                QPushButton {{
                    background-color: {active_border};
                    color: #FFFFFF;
                    border: 2px solid #FFFFFF;
                    border-radius: 10px;
                    font-size: 13px;
                    font-weight: 600;
                    padding: 4px;
                    text-align: center;
                }}
            """)
        else:
            self.setStyleSheet(f"""
                QPushButton {{
                    background-color: {bg};
                    color: #F4F4F5;
                    border: 1px solid {border};
                    border-radius: 10px;
                    font-size: 13px;
                    font-weight: 500;
                    padding: 4px;
                    text-align: center;
                }}
                QPushButton:hover {{
                    background-color: #27272A;
                    border: 1px solid {active_border};
                    color: #FFFFFF;
                }}
                QPushButton:pressed {{
                    background-color: {active_border};
                    color: #FFFFFF;
                }}
            """)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.press_start_time = time.time()
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

    def mouseReleaseEvent(self, event):
        # Momentary release if held for a moment
        super().mouseReleaseEvent(event)


class HeaderBar(QFrame):
    """Sleek PureRef-style header with profile pill, drag handle, and quick controls."""
    def __init__(self, main_window):
        super().__init__(main_window)
        self.main_window = main_window
        self.dragging = False
        self.drag_start_pos = QPoint()
        self.setup_ui()

    def setup_ui(self):
        self.setFixedHeight(38)
        self.setStyleSheet("""
            QFrame {
                background-color: #0A0A0A;
                border-top-left-radius: 14px;
                border-top-right-radius: 14px;
                border-bottom: 1px solid #1F1F23;
            }
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 0, 8, 0)
        layout.setSpacing(6)

        # Profile Pill Button
        self.profile_btn = QPushButton(self)
        self.profile_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.profile_btn.setStyleSheet("""
            QPushButton {
                background-color: #18181B;
                color: #60A5FA;
                border: 1px solid #27272A;
                border-radius: 12px;
                font-size: 11px;
                font-weight: 600;
                padding: 3px 10px;
            }
            QPushButton:hover {
                background-color: #27272A;
                border-color: #3B82F6;
                color: #FFFFFF;
            }
        """)
        self.profile_btn.clicked.connect(self.main_window.cycle_profile)
        layout.addWidget(self.profile_btn)

        # Drag handle icon in center
        grip = QLabel("⋮⋮⋮", self)
        grip.setStyleSheet("color: #52525B; font-size: 14px; font-weight: bold;")
        grip.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(grip, 1)

        # Settings button
        settings_btn = QPushButton("⚙", self)
        settings_btn.setFixedSize(24, 24)
        settings_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        settings_btn.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                color: #A1A1AA;
                border: none;
                font-size: 13px;
                border-radius: 12px;
            }
            QPushButton:hover {
                background-color: #27272A;
                color: #FFFFFF;
            }
        """)
        settings_btn.clicked.connect(self.main_window.open_settings)
        layout.addWidget(settings_btn)

        # Close / Hide button
        close_btn = QPushButton("✕", self)
        close_btn.setFixedSize(24, 24)
        close_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        close_btn.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                color: #71717A;
                border: none;
                font-size: 12px;
                border-radius: 12px;
            }
            QPushButton:hover {
                background-color: #EF4444;
                color: #FFFFFF;
            }
        """)
        close_btn.clicked.connect(self.main_window.hide)
        layout.addWidget(close_btn)

        self.update_profile_title()

    def update_profile_title(self):
        current = self.main_window.config.active_profile_name
        self.profile_btn.setText(f"⚡ {current}")

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
        # Double click snaps to top-right corner
        self.main_window.snap_to_corner("top-right")


class SettingsDialog(QDialog):
    """Full settings and configuration window for profiles, buttons, layout, and gestures."""
    def __init__(self, main_window):
        super().__init__(main_window)
        self.main_window = main_window
        self.config = main_window.config
        self.setWindowTitle("YogaTouch Settings")
        self.setFixedSize(540, 520)
        self.setStyleSheet("""
            QDialog {
                background-color: #0D0D11;
                color: #E4E4E7;
            }
            QTabWidget::pane {
                border: 1px solid #27272A;
                background-color: #121216;
                border-radius: 8px;
            }
            QTabBar::tab {
                background-color: #18181B;
                color: #A1A1AA;
                padding: 8px 16px;
                border: 1px solid #27272A;
                border-bottom: none;
                border-top-left-radius: 6px;
                border-top-right-radius: 6px;
                margin-right: 2px;
            }
            QTabBar::tab:selected {
                background-color: #27272A;
                color: #60A5FA;
                font-weight: bold;
            }
            QLabel {
                color: #D4D4D8;
                font-size: 13px;
            }
            QLineEdit, QComboBox, QSpinBox {
                background-color: #18181B;
                color: #FFFFFF;
                border: 1px solid #3F3F46;
                border-radius: 6px;
                padding: 6px;
            }
            QPushButton {
                background-color: #2563EB;
                color: #FFFFFF;
                border-radius: 6px;
                padding: 6px 14px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #3B82F6;
            }
        """)
        self.setup_ui()

    def setup_ui(self):
        main_layout = QVBoxLayout(self)

        self.tabs = QTabWidget(self)
        self.setup_buttons_tab()
        self.setup_profiles_tab()
        self.setup_appearance_tab()
        main_layout.addWidget(self.tabs)

        # Bottom buttons
        btn_layout = QHBoxLayout()
        btn_layout.addStretch()

        close_btn = QPushButton("Done", self)
        close_btn.clicked.connect(self.accept)
        btn_layout.addWidget(close_btn)
        main_layout.addLayout(btn_layout)

    def setup_buttons_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        top_bar = QHBoxLayout()
        top_bar.addWidget(QLabel("Active Profile:"))
        self.profile_combo = QComboBox(tab)
        self.profile_combo.addItems(list(self.config.data["profiles"].keys()))
        self.profile_combo.setCurrentText(self.config.active_profile_name)
        self.profile_combo.currentTextChanged.connect(self.on_profile_switched)
        top_bar.addWidget(self.profile_combo, 1)

        add_btn = QPushButton("+ Add Button", tab)
        add_btn.clicked.connect(self.add_button_dialog)
        top_bar.addWidget(add_btn)
        layout.addLayout(top_bar)

        # Scroll area for current buttons
        scroll = QScrollArea(tab)
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("background-color: transparent; border: none;")
        self.buttons_container = QWidget()
        self.buttons_vbox = QVBoxLayout(self.buttons_container)
        self.buttons_vbox.setSpacing(6)
        scroll.setWidget(self.buttons_container)
        layout.addWidget(scroll)

        self.refresh_buttons_list()
        self.tabs.addTab(tab, "Buttons & Keys")

    def refresh_buttons_list(self):
        # Clear layout
        while self.buttons_vbox.count():
            item = self.buttons_vbox.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        profile = self.profile_combo.currentText()
        buttons = self.config.data["profiles"].get(profile, [])

        for idx, btn in enumerate(buttons):
            row = QFrame()
            row.setStyleSheet("""
                QFrame {
                    background-color: #18181B;
                    border: 1px solid #27272A;
                    border-radius: 8px;
                    padding: 6px;
                }
            """)
            rl = QHBoxLayout(row)
            rl.setContentsMargins(8, 4, 8, 4)

            icon = btn.get("icon", "")
            name = btn.get("name", "")
            chord = btn.get("chord", "")
            mode = btn.get("mode", "tap")
            color = btn.get("color", "zinc")

            label = QLabel(f"{icon} <b>{name}</b>  <span style='color: #A1A1AA'>[{chord.upper()}]</span>  <span style='color: #60A5FA; font-size:11px'>({mode.upper()})</span>")
            rl.addWidget(label, 1)

            del_btn = QPushButton("✕", row)
            del_btn.setFixedSize(26, 26)
            del_btn.setStyleSheet("background-color: #7F1D1D; color: #FCA5A5; border: none; border-radius: 4px;")
            del_btn.clicked.connect(lambda _, i=idx: self.delete_button(i))
            rl.addWidget(del_btn)

            self.buttons_vbox.addWidget(row)

        self.buttons_vbox.addStretch()

    def on_profile_switched(self, name):
        self.config.active_profile_name = name
        self.refresh_buttons_list()
        self.main_window.rebuild_buttons()
        self.main_window.header.update_profile_title()

    def delete_button(self, index):
        profile = self.profile_combo.currentText()
        buttons = self.config.data["profiles"].get(profile, [])
        if 0 <= index < len(buttons):
            del buttons[index]
            self.config.save()
            self.refresh_buttons_list()
            self.main_window.rebuild_buttons()

    def add_button_dialog(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Add Express Button")
        dlg.setFixedSize(360, 300)
        dlg.setStyleSheet(self.styleSheet())
        layout = QVBoxLayout(dlg)

        layout.addWidget(QLabel("Button Name:"))
        name_in = QLineEdit(dlg)
        name_in.setPlaceholderText("e.g. Undo, Brush, Pan, Shift")
        layout.addWidget(name_in)

        layout.addWidget(QLabel("Icon / Symbol (optional):"))
        icon_in = QLineEdit(dlg)
        icon_in.setPlaceholderText("e.g. ↶, 🖌️, 🖐️, ⇧, 💾")
        layout.addWidget(icon_in)

        layout.addWidget(QLabel("Key Shortcut (e.g. ctrl+z, b, space, shift):"))
        chord_in = QLineEdit(dlg)
        chord_in.setPlaceholderText("ctrl+z, shift+ctrl+z, space, b...")
        layout.addWidget(chord_in)

        layout.addWidget(QLabel("Mode:"))
        mode_combo = QComboBox(dlg)
        mode_combo.addItems(["tap", "hold"])
        layout.addWidget(mode_combo)

        layout.addWidget(QLabel("Color Accent:"))
        color_combo = QComboBox(dlg)
        color_combo.addItems(["blue", "purple", "emerald", "red", "zinc"])
        layout.addWidget(color_combo)

        btn_box = QHBoxLayout()
        ok_btn = QPushButton("Add", dlg)
        ok_btn.clicked.connect(dlg.accept)
        btn_box.addWidget(ok_btn)
        layout.addLayout(btn_box)

        if dlg.exec():
            name = name_in.text().strip() or "Key"
            icon = icon_in.text().strip()
            chord = chord_in.text().strip().lower() or "ctrl+z"
            mode = mode_combo.currentText()
            color = color_combo.currentText()

            profile = self.profile_combo.currentText()
            self.config.data["profiles"][profile].append({
                "name": name,
                "icon": icon,
                "chord": chord,
                "mode": mode,
                "color": color
            })
            self.config.save()
            self.refresh_buttons_list()
            self.main_window.rebuild_buttons()

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

        for name in list(self.config.data["profiles"].keys()):
            row = QFrame()
            row.setStyleSheet("background-color: #18181B; border: 1px solid #27272A; border-radius: 8px; padding: 4px;")
            rl = QHBoxLayout(row)
            rl.addWidget(QLabel(f"<b>{name}</b> ({len(self.config.data['profiles'][name])} buttons)"), 1)

            if len(self.config.data["profiles"]) > 1:
                del_btn = QPushButton("Delete", row)
                del_btn.setStyleSheet("background-color: #7F1D1D; color: #FFFFFF; font-size: 11px;")
                del_btn.clicked.connect(lambda _, n=name: self.delete_profile(n))
                rl.addWidget(del_btn)

            self.profiles_vbox.addWidget(row)

    def create_profile(self):
        name = self.new_profile_name.text().strip()
        if not name:
            return
        if name in self.config.data["profiles"]:
            QMessageBox.warning(self, "Exists", "A profile with that name already exists!")
            return
        self.config.data["profiles"][name] = [
            {"name": "Undo", "icon": "↶", "chord": "ctrl+z", "mode": "tap", "color": "blue"},
            {"name": "Redo", "icon": "↷", "chord": "ctrl+y", "mode": "tap", "color": "blue"},
            {"name": "Save", "icon": "💾", "chord": "ctrl+s", "mode": "tap", "color": "emerald"},
        ]
        self.config.save()
        self.new_profile_name.clear()
        self.profile_combo.clear()
        self.profile_combo.addItems(list(self.config.data["profiles"].keys()))
        self.profile_combo.setCurrentText(name)
        self.refresh_profiles_tab()

    def delete_profile(self, name):
        if name in self.config.data["profiles"]:
            del self.config.data["profiles"][name]
            if self.config.active_profile_name == name:
                self.config.active_profile_name = list(self.config.data["profiles"].keys())[0]
            self.config.save()
            self.profile_combo.clear()
            self.profile_combo.addItems(list(self.config.data["profiles"].keys()))
            self.profile_combo.setCurrentText(self.config.active_profile_name)
            self.refresh_profiles_tab()

    def setup_appearance_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Columns
        layout.addWidget(QLabel("Grid Columns:"))
        cols_combo = QComboBox(tab)
        cols_combo.addItems(["1 Column", "2 Columns (Default)", "3 Columns", "4 Columns"])
        cols_combo.setCurrentIndex(self.config.data.get("columns", 2) - 1)
        cols_combo.currentIndexChanged.connect(lambda idx: self.set_cols(idx + 1))
        layout.addWidget(cols_combo)

        # Button Size
        layout.addWidget(QLabel("Button Size (Touch Comfort):"))
        size_combo = QComboBox(tab)
        size_combo.addItems(["Compact (46px)", "Standard (54px)", "Large (64px)"])
        cur_size = self.config.data.get("button_size", "standard")
        size_map = {"compact": 0, "standard": 1, "large": 2}
        size_combo.setCurrentIndex(size_map.get(cur_size, 1))
        size_combo.currentIndexChanged.connect(self.set_btn_size)
        layout.addWidget(size_combo)

        # Opacity
        layout.addWidget(QLabel("Default Opacity (PureRef Style):"))
        opacity_slider = QSlider(Qt.Orientation.Horizontal, tab)
        opacity_slider.setRange(20, 100)
        opacity_slider.setValue(int(self.config.data.get("opacity", 0.94) * 100))
        opacity_slider.valueChanged.connect(lambda val: self.set_opacity(val / 100.0))
        layout.addWidget(opacity_slider)

        # 4-Finger Gesture Sensitivity
        layout.addWidget(QLabel("4-Finger Pinch Inward Sensitivity:"))
        sens_combo = QComboBox(tab)
        sens_combo.addItems(["Low (Harder Pinch)", "Normal (Balanced)", "High (Instant Trigger)"])
        sens_map = {"low": 0, "normal": 1, "high": 2}
        cur_sens = self.config.data.get("pinch_sensitivity", "normal")
        sens_combo.setCurrentIndex(sens_map.get(cur_sens, 1))
        sens_combo.currentIndexChanged.connect(self.set_sensitivity)
        layout.addWidget(sens_combo)

        layout.addSpacing(10)
        layout.addWidget(QLabel("<b>Keyboard Shortcut to Toggle:</b> <span style='color: #60A5FA'>Super + O</span> (or run <code>yogatouch --toggle</code>)"))

        layout.addStretch()
        self.tabs.addTab(tab, "Layout & Gestures")

    def set_cols(self, cols):
        self.config.data["columns"] = cols
        self.config.save()
        self.main_window.rebuild_buttons()

    def set_btn_size(self, idx):
        sizes = ["compact", "standard", "large"]
        self.config.data["button_size"] = sizes[idx]
        self.config.save()
        self.main_window.rebuild_buttons()

    def set_opacity(self, val):
        self.config.data["opacity"] = val
        self.config.save()
        self.main_window.setWindowOpacity(val)

    def set_sensitivity(self, idx):
        sens = ["low", "normal", "high"]
        self.config.data["pinch_sensitivity"] = sens[idx]
        self.config.save()
        if self.main_window.gesture_monitor:
            for _, state in self.main_window.gesture_monitor.devices.values():
                state.set_sensitivity(sens[idx])


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

        self.setup_window()
        self.setup_ui()
        self.start_gesture_monitor()
        self.setup_ipc()

    def setup_window(self):
        # Set XWayland window flags: Always on top, frameless, non-focus-stealing
        self.setWindowFlags(
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.Tool |
            Qt.WindowType.WindowDoesNotAcceptFocus
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents, True)
        self.setWindowOpacity(self.config.data.get("opacity", 0.94))

        # Position at top right by default
        self.restore_or_default_position()

    def setup_ui(self):
        # Container frame for rounded border and pure black background
        self.container = QFrame(self)
        self.container.setStyleSheet("""
            QFrame#mainContainer {
                background-color: #000000;
                border: 1px solid #27272A;
                border-radius: 14px;
            }
        """)
        self.container.setObjectName("mainContainer")

        # Soft drop shadow (PureRef feel)
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(24)
        shadow.setColor(QColor(0, 0, 0, 160))
        shadow.setOffset(0, 8)
        self.container.setGraphicsEffect(shadow)

        self.setCentralWidget(self.container)

        self.main_layout = QVBoxLayout(self.container)
        self.main_layout.setContentsMargins(0, 0, 0, 8)
        self.main_layout.setSpacing(8)

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

    def rebuild_buttons(self):
        # Clear existing buttons
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self.buttons.clear()

        btn_items = self.config.current_buttons
        cols = self.config.data.get("columns", 2)
        btn_size = self.config.data.get("button_size", "standard")
        height_map = {"compact": 46, "standard": 54, "large": 64}
        btn_height = height_map.get(btn_size, 54)

        for idx, item in enumerate(btn_items):
            btn = TouchExpressButton(item, self.emitter, self.grid_widget)
            btn.setFixedHeight(btn_height)
            r = idx // cols
            c = idx % cols
            self.grid_layout.addWidget(btn, r, c)
            self.buttons.append(btn)

        width_per_col = 96 if btn_size == "compact" else 108 if btn_size == "standard" else 120
        total_width = max(180, (cols * width_per_col) + 20)
        self.setFixedWidth(total_width)
        self.adjustSize()

    def cycle_profile(self):
        self.config.cycle_profile()
        self.header.update_profile_title()
        self.rebuild_buttons()

    def open_settings(self):
        dlg = SettingsDialog(self)
        dlg.exec()

    def snap_to_corner(self, corner="top-right"):
        screen = QApplication.primaryScreen().availableGeometry()
        w, h = self.width(), self.height()
        margin = 24

        if corner == "top-right":
            x = screen.x() + screen.width() - w - margin
            y = screen.y() + 40
        elif corner == "top-left":
            x = screen.x() + margin
            y = screen.y() + 40
        elif corner == "bottom-right":
            x = screen.x() + screen.width() - w - margin
            y = screen.y() + screen.height() - h - margin
        elif corner == "bottom-left":
            x = screen.x() + margin
            y = screen.y() + screen.height() - h - margin
        else:
            x = screen.x() + (screen.width() - w) // 2
            y = screen.y() + (screen.height() - h) // 2

        self.move(x, y)
        self.save_current_position()

    def restore_or_default_position(self):
        pos = self.config.data.get("position", {"x": -1, "y": -1})
        if pos.get("x", -1) != -1 and pos.get("y", -1) != -1 and self.config.data.get("remember_position", True):
            self.move(pos["x"], pos["y"])
        else:
            self.snap_to_corner("top-right")

    def save_current_position(self):
        self.config.data["position"] = {"x": self.x(), "y": self.y()}
        self.config.save()

    def wheelEvent(self, event):
        # PureRef-style scroll wheel to adjust opacity
        delta = event.angleDelta().y()
        cur_op = self.windowOpacity()
        new_op = max(0.20, min(1.0, cur_op + (0.05 if delta > 0 else -0.05)))
        self.setWindowOpacity(new_op)
        self.config.data["opacity"] = new_op
        self.config.save()
        event.accept()

    def contextMenuEvent(self, event):
        menu = QMenu(self)
        menu.setStyleSheet("""
            QMenu {
                background-color: #121216;
                color: #F4F4F5;
                border: 1px solid #27272A;
                border-radius: 8px;
                padding: 4px;
            }
            QMenu::item {
                padding: 6px 20px;
                border-radius: 4px;
            }
            QMenu::item:selected {
                background-color: #2563EB;
                color: #FFFFFF;
            }
        """)

        # Profiles submenu
        profile_menu = menu.addMenu("📁 Switch Profile")
        for p in self.config.data["profiles"].keys():
            action = profile_menu.addAction(p)
            if p == self.config.active_profile_name:
                action.setIcon(QIcon.fromTheme("emblem-default"))
            action.triggered.connect(lambda _, name=p: self.switch_profile(name))

        menu.addSeparator()

        settings_act = menu.addAction("⚙ Settings & Buttons...")
        settings_act.triggered.connect(self.open_settings)

        snap_menu = menu.addMenu("📍 Snap to Corner")
        snap_menu.addAction("Top-Right (Default)").triggered.connect(lambda: self.snap_to_corner("top-right"))
        snap_menu.addAction("Top-Left").triggered.connect(lambda: self.snap_to_corner("top-left"))
        snap_menu.addAction("Bottom-Right").triggered.connect(lambda: self.snap_to_corner("bottom-right"))
        snap_menu.addAction("Bottom-Left").triggered.connect(lambda: self.snap_to_corner("bottom-left"))

        op_menu = menu.addMenu("🔍 Opacity")
        op_menu.addAction("100%").triggered.connect(lambda: self.set_opacity(1.0))
        op_menu.addAction("80%").triggered.connect(lambda: self.set_opacity(0.80))
        op_menu.addAction("60%").triggered.connect(lambda: self.set_opacity(0.60))
        op_menu.addAction("40%").triggered.connect(lambda: self.set_opacity(0.40))

        menu.addSeparator()

        hide_act = menu.addAction("✕ Hide Overlay (4-Finger Pinch to Reopen)")
        hide_act.triggered.connect(self.hide)

        quit_act = menu.addAction("🚪 Quit YogaTouch")
        quit_act.triggered.connect(self.quit_app)

        menu.exec(event.globalPos())

    def switch_profile(self, name):
        self.config.active_profile_name = name
        self.header.update_profile_title()
        self.rebuild_buttons()

    def set_opacity(self, val):
        self.setWindowOpacity(val)
        self.config.data["opacity"] = val
        self.config.save()

    def toggle_visibility(self):
        if self.isVisible():
            self.hide()
        else:
            self.show()
            self.raise_()

    def start_gesture_monitor(self):
        sens = self.config.data.get("pinch_sensitivity", "normal")
        self.gesture_monitor = GestureMonitor(
            callback=self.bridge.gesture_triggered.emit,
            sensitivity=sens
        )
        self.gesture_monitor.start()

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
        # PureRef style: close hides to background instead of destroying daemon
        self.hide()
        event.ignore()


def send_ipc_command(cmd):
    """Sends a command to an already running YogaTouch process."""
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
    # CLI command parsing
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

    # If already running and launched without args, toggle it
    if send_ipc_command("toggle"):
        print("[YogaTouch] Existing instance toggled.")
        sys.exit(0)

    # Start main application
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
