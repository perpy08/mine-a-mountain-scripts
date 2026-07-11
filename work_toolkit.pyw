import sys
import os
import time
import json
import threading
import subprocess
import random
import wave
import math
import struct
from datetime import datetime, timedelta
from plyer import notification

# PyQt6 Core, Web, GUI & Audio Imports
from PyQt6.QtCore import QUrl, QTimer, QTime, QDate, pyqtSignal, QObject, Qt
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QTextEdit, QPushButton, QLabel, 
                             QStackedWidget, QFrame, QFileDialog, QTabWidget,
                             QLineEdit, QComboBox, QCheckBox, QTimeEdit, QColorDialog, QSlider,
                             QScrollArea)
from PyQt6.QtWebEngineCore import QWebEngineProfile
from PyQt6.QtWebEngineWidgets import QWebEngineView
from PyQt6.QtMultimedia import QMediaPlayer, QAudioOutput

# Absolute Path Configuration for Config Files
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(SCRIPT_DIR, "history.txt")
PATH_CONFIG_FILE = os.path.join(SCRIPT_DIR, "screenshot_path.txt")
SHIFT_CONFIG_FILE = os.path.join(SCRIPT_DIR, "shift_config.txt")
CUSTOM_CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")
AUDIO_CONFIG_FILE = os.path.join(SCRIPT_DIR, "audio_config.json")

# Selenium Imports for Dashboard Monitor
from selenium import webdriver
from selenium.webdriver.chrome.options import Options as SeleniumOptions

# Signal helpers
class InspectorWorkerSignals(QObject):
    status_update = pyqtSignal(str)
    switch_tab = pyqtSignal(int)
    request_screenshot = pyqtSignal(str)
    bulk_finished = pyqtSignal()

class MonitorSignals(QObject):
    status_update = pyqtSignal(str)

# =====================================================================
#  CENTRALIZED MULTIMEDIA AUDIO ENGINE
# =====================================================================
class GlobalAudioManager:
    """Manages workspace alerts with dynamic volume amplification up to 200% using QMediaPlayer."""
    def __init__(self):
        self.player = QMediaPlayer()
        self.audio_output = QAudioOutput()
        self.player.setAudioOutput(self.audio_output)
        
        self.config = self.load_audio_config()
        self.generate_builtin_frequencies()

    def generate_builtin_frequencies(self):
        """Generates real physical .wav files for built-in audio targets so QMediaPlayer can scale volume cleanly."""
        sounds_to_build = {
            "clear_ascending.wav": [(600, 0.1), (850, 0.1), (1100, 0.15)],
            "descending_melancholy.wav": [(900, 0.12), (700, 0.12), (500, 0.2)],
            "critical_pulse.wav": [(440, 0.08), (0, 0.04), (440, 0.08), (0, 0.04), (440, 0.2)],
            "buzz_drop.wav": [(180, 0.15), (140, 0.15), (100, 0.3)],
            "beep_triple.wav": [(800, 0.07), (0, 0.05), (800, 0.07), (0, 0.05), (800, 0.07)],
            "classic_gong.wav": [(330, 0.4), (220, 0.4)]
        }

        sample_rate = 22050
        for filename, patterns in sounds_to_build.items():
            file_path = os.path.join(SCRIPT_DIR, filename)
            if os.path.exists(file_path): 
                continue
                
            try:
                with wave.open(file_path, 'wb') as wav_file:
                    wav_file.setnchannels(1)
                    wav_file.setsampwidth(2)
                    wav_file.setframerate(sample_rate)
                    
                    for freq, duration in patterns:
                        num_samples = int(sample_rate * duration)
                        if freq == 0:
                            for _ in range(num_samples):
                                wav_file.writeframesraw(struct.pack('<h', 0))
                        else:
                            for i in range(num_samples):
                                value = int(32767 * math.sin(2.0 * math.pi * freq * i / sample_rate))
                                wav_file.writeframesraw(struct.pack('<h', value))
            except Exception as e:
                print(f"Failed generating audio track fallback file: {e}")

    def load_audio_config(self):
        defaults = {
            "volume": 100,
            "monitor_start": "Chime: Clear Ascending",
            "monitor_stop": "Chime: Descending Melancholy",
            "monitor_trigger": "Siren: Critical Pulse",
            "monitor_crash": "Alarm: Buzz Drop",
            "break_end": "Digital: Beep Triple",
            "shift_end": "Classic: Ring Gong"
        }
        if os.path.exists(AUDIO_CONFIG_FILE):
            try:
                with open(AUDIO_CONFIG_FILE, "r", encoding="utf-8") as f:
                    saved = json.load(f)
                    defaults.update(saved)
            except: pass
        return defaults

    def save_audio_config(self):
        try:
            with open(AUDIO_CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=4)
        except: pass

    def set_volume_percentage(self, percent):
        self.config["volume"] = percent
        self.save_audio_config()
        float_vol = (percent / 100.0)
        self.audio_output.setVolume(float_vol)

    def play_system_alert(self, feature_key):
        sound_selection = self.config.get(feature_key, "")
        
        if os.path.exists(sound_selection):
            self.player.setSource(QUrl.fromLocalFile(sound_selection))
            self.player.play()
            return

        file_map = {
            "Clear Ascending": "clear_ascending.wav",
            "Descending Melancholy": "descending_melancholy.wav",
            "Critical Pulse": "critical_pulse.wav",
            "Buzz Drop": "buzz_drop.wav",
            "Beep Triple": "beep_triple.wav",
            "Ring Gong": "classic_gong.wav"
        }

        matched_filename = "clear_ascending.wav"
        for core_phrase, target_file in file_map.items():
            if core_phrase in sound_selection:
                matched_filename = target_file
                break

        full_wav_path = os.path.join(SCRIPT_DIR, matched_filename)
        if os.path.exists(full_wav_path):
            self.player.setSource(QUrl.fromLocalFile(full_wav_path))
            self.player.play()

AUDIO_ENGINE = GlobalAudioManager()


# =====================================================================
#  TAB 1: DASHBOARD MONITOR INTERFACE
# =====================================================================
class DashboardMonitorTab(QWidget):
    def __init__(self):
        super().__init__()
        self.monitoring = False
        self.monitor_thread = None
        self.driver = None
        
        self.signals = MonitorSignals()
        self.signals.status_update.connect(self.safe_update_status)
        
        self.setStyleSheet("""
            QLabel { color: #e0e0e0; font-family: 'Arial'; font-size: 12px; }
            QLineEdit { background-color: #222; color: white; border: 1px solid #444; padding: 6px; border-radius: 4px; }
            QCheckBox { color: #e0e0e0; }
            QPushButton { font-weight: bold; font-size: 13px; padding: 10px; border-radius: 5px; }
        """)
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        layout.addWidget(QLabel("Target URL (Dashboard/Inbox):"))
        self.url_entry = QLineEdit()
        self.url_entry.setText("https://example.com/dashboard")
        layout.addWidget(self.url_entry)

        layout.addWidget(QLabel("Activation Keyword (e.g., 9m to start fast scanning):"))
        self.activate_entry = QLineEdit()
        self.activate_entry.setText("9m")
        layout.addWidget(self.activate_entry)

        layout.addWidget(QLabel("Alert Trigger Keyword / Phrase (e.g., 10m):"))
        self.keyword_entry = QLineEdit()
        self.keyword_entry.setText("10m")
        layout.addWidget(self.keyword_entry)

        layout.addWidget(QLabel("Fast Mode Check Interval Speed (Seconds):"))
        self.interval_entry = QLineEdit()
        self.interval_entry.setText("30")
        layout.addWidget(self.interval_entry)

        self.realtime_check = QCheckBox("Enable Real-Time Mode (No Delay Stream)")
        self.realtime_check.stateChanged.connect(self.toggle_time_fields)
        layout.addWidget(self.realtime_check)

        self.headless_check = QCheckBox("Hide browser window (Uncheck this first to log in!)")
        layout.addWidget(self.headless_check)

        self.lbl_status = QLabel("Status: IDLE")
        self.lbl_status.setStyleSheet("font-style: italic; color: #888;")
        layout.addWidget(self.lbl_status)

        self.btn_control = QPushButton("Start Monitor")
        self.btn_control.setStyleSheet("background-color: #007acc; color: white;")
        self.btn_control.clicked.connect(self.toggle_monitoring)
        layout.addWidget(self.btn_control)
        layout.addStretch()

    def safe_update_status(self, text):
        self.lbl_status.setText(text)

    def toggle_time_fields(self):
        state = not self.realtime_check.isChecked()
        self.interval_entry.setEnabled(state)
        self.activate_entry.setEnabled(state)

    def toggle_monitoring(self):
        if not self.monitoring:
            url = self.url_entry.text().strip()
            activate_word = self.activate_entry.text().strip()
            keyword = self.keyword_entry.text().strip()
            is_realtime = self.realtime_check.isChecked()
            headless = self.headless_check.isChecked()
            
            interval = 30
            if not is_realtime:
                try:
                    interval = int(self.interval_entry.text().strip())
                    if interval < 2: raise ValueError
                except ValueError:
                    self.signals.status_update.emit("⚠️ Interval must be at least 2 seconds.")
                    return

            if not url or not keyword:
                self.signals.status_update.emit("⚠️ URL and Target fields are mandatory.")
                return

            self.monitoring = True
            self.btn_control.setText("STOP Monitoring")
            self.btn_control.setStyleSheet("background-color: #dc3545; color: white;")
            
            AUDIO_ENGINE.play_system_alert("monitor_start")
            
            self.monitor_thread = threading.Thread(
                target=self.monitor_loop, 
                args=(url, activate_word, keyword, interval, is_realtime, headless), 
                daemon=True
            )
            self.monitor_thread.start()
        else:
            self.monitoring = False
            self.signals.status_update.emit("Status: IDLE")
            self.btn_control.setText("Start Monitor")
            self.btn_control.setStyleSheet("background-color: #007acc; color: white;")
            
            AUDIO_ENGINE.play_system_alert("monitor_stop")

    def kill_background_locks(self):
        if os.name == 'nt':
            try:
                subprocess.run("taskkill /f /im chromedriver.exe", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=True)
                subprocess.run('wmic process where "name=\'chrome.exe\' and CommandLine like \'%MonitorDataProfile_Unique%\'" call terminate', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=True)
            except:
                pass

    def monitor_loop(self, url, activate_word, keyword, interval, is_realtime, headless):
        self.signals.status_update.emit("Clearing stale session locks...")
        self.kill_background_locks()
        time.sleep(1)

        options = SeleniumOptions()
        user_data_dir = os.path.join(SCRIPT_DIR, "MonitorDataProfile_Unique")
        options.add_argument(f"--user-data-dir={user_data_dir}")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-extensions")
        options.add_argument("--remote-allow-origins=*")
        options.add_argument("--disk-cache-size=1")
        options.add_argument("--disable-gpu-program-cache")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option('useAutomationExtension', False)
        
        if headless:
            options.add_argument("--headless=new")
            options.add_argument("--disable-gpu")
            
        try:
            self.signals.status_update.emit("Launching Chrome...")
            self.driver = webdriver.Chrome(options=options)
            self.driver.implicitly_wait(5)
            self.driver.get(url)
            
            if not headless:
                self.signals.status_update.emit("⚠️ Log in now if needed (25s buffer)...")
                time.sleep(25)
            
            last_keyword_count = 0
            while self.monitoring:
                self.driver.refresh()
                time.sleep(4)
                
                page_text = self.driver.find_element(by="tag name", value="body").text
                lower_text = page_text.lower()
                current_keyword_count = lower_text.count(keyword.lower())
                current_time_str = time.strftime('%H:%M:%S')
                
                if current_keyword_count > 0 and current_keyword_count > last_keyword_count:
                    last_keyword_count = current_keyword_count
                    self.signals.status_update.emit(f"🔥 ALERT: Found {current_keyword_count} x '{keyword}' at {current_time_str}!")
                    notification.notify(
                        title="🚨 NEW TRIGGER DETECTED!", 
                        message=f"Active count is now: {current_keyword_count} items ({keyword})", 
                        timeout=10
                    )
                    AUDIO_ENGINE.play_system_alert("monitor_trigger")
                    time.sleep(5)
                    continue
                
                if current_keyword_count < last_keyword_count:
                    last_keyword_count = current_keyword_count
                
                if is_realtime:
                    self.signals.status_update.emit(f"Streaming live at {current_time_str}... [{current_keyword_count} active]")
                    time.sleep(0.5)
                    continue
                
                if activate_word and activate_word.lower() in lower_text:
                    self.signals.status_update.emit(f"🚀 Fast Mode ({interval}s) at {current_time_str} | Active keys: {current_keyword_count}")
                    current_delay = interval
                else:
                    self.signals.status_update.emit(f"💤 Standby Mode (60s check) at {current_time_str}")
                    current_delay = 60
                
                for _ in range(current_delay):
                    if not self.monitoring: break
                    time.sleep(1)
        except Exception as e:
            self.signals.status_update.emit(f"⚠️ Session issue: {str(e)[:45]}...")
            self.monitoring = False
            self.btn_control.setText("Start Monitor")
            self.btn_control.setStyleSheet("background-color: #007acc; color: white;")
            AUDIO_ENGINE.play_system_alert("monitor_crash")
        finally:
            if self.driver:
                try: self.driver.quit()
                except: pass


# =====================================================================
#  TAB 2: BULK MOBILE DOMAIN INSPECTOR INTERFACE
# =====================================================================
class MobileInspectorTab(QWidget):
    def __init__(self):
        super().__init__()
        self.domains_list = []
        self.current_index = 0
        self.is_bulk_capturing = False
        self.screenshot_dir = self.load_saved_folder_path()
        self.current_bar_color = "#1e293b"

        self.signals = InspectorWorkerSignals()
        self.signals.status_update.connect(self.update_status_text)
        self.signals.switch_tab.connect(self.change_tab_from_signal)
        self.signals.request_screenshot.connect(self.take_device_screenshot)
        self.signals.bulk_finished.connect(self.bulk_capture_completed)

        self.init_ui()
        self.load_custom_config()

    def init_ui(self):
        self.master_layout = QHBoxLayout(self)
        self.master_layout.setContentsMargins(0, 0, 0, 0)
        self.master_layout.setSpacing(0)

        self.work_stacked = QStackedWidget()
        self.master_layout.addWidget(self.work_stacked)

        self.init_input_layout()
        self.init_phone_layout()
        
        self.work_stacked.setCurrentIndex(0)

    def init_input_layout(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(20, 20, 20, 20)

        label = QLabel("Paste Domains / Links to Inspect (One per line):")
        label.setStyleSheet("font-weight: bold; font-size: 13px; color: white;")
        layout.addWidget(label)

        self.txt_domains = QTextEdit()
        self.txt_domains.setStyleSheet("font-family: 'Consolas'; font-size: 12px; background-color: #222; color: white;")
        layout.addWidget(self.txt_domains)

        btn_launch = QPushButton("Launch Mobile Device Emulator")
        btn_launch.setStyleSheet("font-weight: bold; padding: 10px; background-color: #007acc; color: white; border-radius: 5px;")
        btn_launch.clicked.connect(self.start_emulator)
        layout.addWidget(btn_launch)

        self.work_stacked.addWidget(widget)

    def init_phone_layout(self):
        self.phone_workspace = QWidget()
        layout = QHBoxLayout(self.phone_workspace)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        sidebar = QFrame()
        sidebar.setFixedWidth(210)
        sidebar.setStyleSheet("background-color: #1e1e1e; border-right: 1px solid #2d2d2d; color: #e0e0e0;")
        sb_layout = QVBoxLayout(sidebar)
        sb_layout.setContentsMargins(12, 15, 12, 15)
        sb_layout.setSpacing(10)

        lbl_title = QLabel("CONTROL PANEL")
        lbl_title.setStyleSheet("font-weight: bold; font-size: 13px; color: #007acc; border-bottom: 1px solid #333; padding-bottom: 5px;")
        sb_layout.addWidget(lbl_title)

        sb_layout.addWidget(QLabel("Destination folder:"))
        self.lbl_current_dir = QLabel(self.truncate_path(self.screenshot_dir))
        self.lbl_current_dir.setStyleSheet("font-size: 11px; background-color: #2a2a2a; padding: 6px; border-radius: 4px; color: #ccc;")
        sb_layout.addWidget(self.lbl_current_dir)

        btn_dir = QPushButton("📂 Change Folder")
        btn_dir.setStyleSheet("background-color: #333; padding: 5px; color: white; font-weight: bold;")
        btn_dir.clicked.connect(self.change_destination_folder)
        sb_layout.addWidget(btn_dir)

        btn_open_folder = QPushButton("👁️ View Folder")
        btn_open_folder.setStyleSheet("background-color: #2b5b84; padding: 5px; color: white; font-weight: bold;")
        btn_open_folder.clicked.connect(self.open_screenshot_directory)
        sb_layout.addWidget(btn_open_folder)

        sb_layout.addSpacing(5)
        self.btn_toggle_custom = QPushButton("▼ Customize System Tray")
        self.btn_toggle_custom.setCheckable(True)
        self.btn_toggle_custom.setChecked(True)
        self.btn_toggle_custom.setStyleSheet("background-color: #2d2d2d; color: #007acc; text-align: left; padding: 6px; font-weight: bold; border-radius: 4px;")
        sb_layout.addWidget(self.btn_toggle_custom)

        self.custom_dropdown_frame = QFrame()
        self.custom_dropdown_frame.setStyleSheet("background-color: #171717; border-radius: 4px; padding: 4px;")
        custom_inner_layout = QVBoxLayout(self.custom_dropdown_frame)
        custom_inner_layout.setContentsMargins(6, 6, 6, 6)
        custom_inner_layout.setSpacing(6)

        custom_inner_layout.addWidget(QLabel("Workspace Badge:"))
        self.input_username = QLineEdit()
        self.input_username.setPlaceholderText("Enter name or code...")
        self.input_username.setStyleSheet("background-color: #262626; border: 1px solid #3a3a3a; padding: 4px; color: white;")
        self.input_username.textChanged.connect(self.handle_username_change)
        custom_inner_layout.addWidget(self.input_username)

        self.btn_pick_color = QPushButton("🎨 Tray Theme Color")
        self.btn_pick_color.setStyleSheet("background-color: #3a3a3a; color: white; padding: 5px;")
        self.btn_pick_color.clicked.connect(self.handle_color_picker)
        custom_inner_layout.addWidget(self.btn_pick_color)

        sb_layout.addWidget(self.custom_dropdown_frame)
        self.btn_toggle_custom.clicked.connect(lambda checked: self.custom_dropdown_frame.setVisible(checked))

        sb_layout.addSpacing(5)
        self.btn_screenshot = QPushButton("📸 Capture Current")
        self.btn_screenshot.setStyleSheet("background-color: #333; color: white; padding: 8px; font-weight: bold;")
        self.btn_screenshot.clicked.connect(lambda: self.take_device_screenshot("MobileSnap"))
        sb_layout.addWidget(self.btn_screenshot)

        self.btn_bulk_screenshot = QPushButton("⚡ Capture All Links")
        self.btn_bulk_screenshot.setStyleSheet("background-color: #28a745; color: white; padding: 10px; font-weight: bold;")
        self.btn_bulk_screenshot.clicked.connect(self.start_bulk_capture)
        sb_layout.addWidget(self.btn_bulk_screenshot)

        self.lbl_status = QLabel("")
        self.lbl_status.setStyleSheet("font-size: 11px; font-style: italic; color: #28a745;")
        self.lbl_status.setWordWrap(True)
        sb_layout.addWidget(self.lbl_status)

        sb_layout.addStretch()
        layout.addWidget(sidebar)

        self.phone_container = QFrame()
        self.phone_container.setStyleSheet("background-color: #1a1a1a;")
        p_layout = QVBoxLayout(self.phone_container)
        p_layout.setContentsMargins(0, 0, 0, 0)
        p_layout.setSpacing(0)

        self.status_bar = QFrame()
        self.status_bar.setFixedHeight(28)
        self.apply_notify_bar_style()
        
        st_layout = QHBoxLayout(self.status_bar)
        st_layout.setContentsMargins(12, 0, 12, 0)
        st_layout.setSpacing(10)

        self.lbl_time = QLabel("12:00")
        self.lbl_time.setStyleSheet("font-weight: bold; font-size: 11px; color: white; background: transparent; border: none;")
        st_layout.addWidget(self.lbl_time)
        st_layout.addStretch()

        center_ticker_widget = QWidget()
        center_ticker_widget.setStyleSheet("background: transparent; border: none;")
        center_layout = QVBoxLayout(center_ticker_widget)
        center_layout.setContentsMargins(0, 2, 0, 2)
        center_layout.setSpacing(0)
        center_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.lbl_display_user = QLabel("Agent_Root")
        self.lbl_display_user.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_display_user.setStyleSheet("font-weight: bold; font-size: 9px; color: white; background: transparent; line-height: 10px;")
        
        current_date_str = QDate.currentDate().toString("MMM dd, yyyy")
        self.lbl_display_date = QLabel(current_date_str)
        self.lbl_display_date.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_display_date.setStyleSheet("font-size: 8px; color: #cbd5e1; background: transparent; line-height: 9px;")

        center_layout.addWidget(self.lbl_display_user)
        center_layout.addWidget(self.lbl_display_date)
        st_layout.addWidget(center_ticker_widget)

        st_layout.addStretch()
        self.lbl_battery = QLabel("📶 🛜 🔋 100%")
        self.lbl_battery.setStyleSheet("font-size: 11px; color: white; background: transparent; border: none;")
        st_layout.addWidget(self.lbl_battery)
        p_layout.addWidget(self.status_bar)

        url_frame = QFrame()
        url_frame.setFixedHeight(40)
        url_frame.setStyleSheet("background-color: #2d2d2d;")
        url_layout = QHBoxLayout(url_frame)
        url_layout.setContentsMargins(10, 5, 10, 5)
        self.lbl_url = QLabel("")
        self.lbl_url.setStyleSheet("background-color: #121212; color: #a6a6a6; padding: 4px; border-radius: 4px; font-size: 11px;")
        url_layout.addWidget(self.lbl_url)
        p_layout.addWidget(url_frame)

        self.browser_stack = QStackedWidget()
        p_layout.addWidget(self.browser_stack)

        nav_bar = QFrame()
        nav_bar.setFixedHeight(50)
        nav_bar.setStyleSheet("background-color: #1a1a1a; border-top: 1px solid #2d2d2d;")
        nv_layout = QHBoxLayout(nav_bar)
        self.btn_prev = QPushButton("◀ Prev")
        self.btn_prev.clicked.connect(self.navigate_prev)
        nv_layout.addWidget(self.btn_prev)
        self.lbl_counter = QLabel("1 / 1")
        nv_layout.addWidget(self.lbl_counter)
        self.btn_next = QPushButton("Next ▶")
        self.btn_next.clicked.connect(self.navigate_next)
        nv_layout.addWidget(self.btn_next)
        p_layout.addWidget(nav_bar)

        layout.addWidget(self.phone_container)
        self.work_stacked.addWidget(self.phone_workspace)

    def apply_notify_bar_style(self):
        if hasattr(self, 'status_bar') and self.status_bar:
            self.status_bar.setStyleSheet(f"QFrame {{ background-color: {self.current_bar_color}; border-bottom: 1px solid rgba(255,255,255,0.12); }}")

    def handle_username_change(self, text):
        clean_text = text.strip()
        self.lbl_display_user.setText(clean_text if clean_text else "Workspace User")
        self.save_custom_config()

    def handle_color_picker(self):
        initial_color = QColorDialog.getColor(Qt.GlobalColor.darkGray, self, "Choose System Tray Background Color")
        if initial_color.isValid():
            self.current_bar_color = initial_color.name()
            self.apply_notify_bar_style()
            self.save_custom_config()

    def save_custom_config(self):
        try:
            config_payload = {"saved_username": self.input_username.text(), "saved_hex_color": self.current_bar_color}
            with open(CUSTOM_CONFIG_FILE, "w", encoding="utf-8") as f: json.dump(config_payload, f, indent=4)
        except: pass

    def load_custom_config(self):
        if os.path.exists(CUSTOM_CONFIG_FILE):
            try:
                with open(CUSTOM_CONFIG_FILE, "r", encoding="utf-8") as f: data = json.load(f)
                username = data.get("saved_username", "")
                color = data.get("saved_hex_color", "#1e293b")
                self.input_username.setText(username)
                self.current_bar_color = color
                self.apply_notify_bar_style()
                if username.strip(): self.lbl_display_user.setText(username.strip())
            except: pass

    def start_emulator(self):
        raw_text = self.txt_domains.toPlainText().strip()
        if not raw_text: return
        try:
            with open(HISTORY_FILE, "w", encoding="utf-8") as f: f.write(raw_text)
        except: pass

        self.domains_list = [line.strip() for line in raw_text.split("\n") if line.strip()]
        for i, url in enumerate(self.domains_list):
            if not url.startswith(("http://", "https://")): self.domains_list[i] = "https://" + url

        while self.browser_stack.count() > 0:
            w = self.browser_stack.widget(0)
            self.browser_stack.removeWidget(w)
            w.deleteLater()

        for target_url in self.domains_list:
            web_view = QWebEngineView()
            profile = QWebEngineProfile.defaultProfile()
            profile.setHttpUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1")
            web_view.setUrl(QUrl(target_url))
            self.browser_stack.addWidget(web_view)

        self.current_index = 0
        self.show_current_tab()
        self.work_stacked.setCurrentWidget(self.phone_workspace)

    def show_current_tab(self):
        if not self.domains_list: return
        self.browser_stack.setCurrentIndex(self.current_index)
        target_url = self.domains_list[self.current_index]
        self.lbl_url.setText(f" 🔒 {target_url}")
        self.lbl_counter.setText(f"{self.current_index + 1} / {len(self.domains_list)}")

    def navigate_next(self):
        if self.current_index < len(self.domains_list) - 1:
            self.current_index += 1
            self.show_current_tab()

    def navigate_prev(self):
        if self.current_index > 0:
            self.current_index -= 1
            self.show_current_tab()

    def load_saved_folder_path(self):
        if os.path.exists(PATH_CONFIG_FILE):
            try:
                with open(PATH_CONFIG_FILE, "r", encoding="utf-8") as f:
                    saved_path = f.read().strip()
                    if os.path.isdir(saved_path): return saved_path
            except: pass
        return os.path.join(os.path.expanduser("~"), "Downloads")

    def change_destination_folder(self):
        if self.is_bulk_capturing: return
        d = QFileDialog.getExistingDirectory(self, "Select Directory", self.screenshot_dir)
        if d:
            self.screenshot_dir = d
            self.lbl_current_dir.setText(self.truncate_path(d))
            try:
                with open(PATH_CONFIG_FILE, "w", encoding="utf-8") as f: f.write(d)
            except: pass

    def open_screenshot_directory(self):
        if os.path.exists(self.screenshot_dir):
            if os.name == 'nt': os.startfile(self.screenshot_dir)
            else: subprocess.Popen(['xdg-open', self.screenshot_dir])

    def take_device_screenshot(self, prefix="MobileSnap"):
        QApplication.processEvents()
        pix = self.phone_container.grab()
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        if self.current_index < len(self.domains_list):
            clean_domain = self.domains_list[self.current_index].replace("https://", "").replace("http://", "").replace("/", "_").strip("_")[:20]
        else:
            clean_domain = "Unknown"
        filename = f"{prefix}_{clean_domain}_{timestamp}.png"
        full_path = os.path.join(self.screenshot_dir, filename)
        pix.save(full_path, "PNG")

    def start_bulk_capture(self):
        if self.is_bulk_capturing or not self.domains_list: return
        self.is_bulk_capturing = True
        self.toggle_ui_elements(False)
        threading.Thread(target=self.bulk_capture_worker, daemon=True).start()

    def bulk_capture_worker(self):
        total = len(self.domains_list)
        for i in range(total):
            self.signals.switch_tab.emit(i)
            self.signals.status_update.emit(f"Loading ({i+1}/{total})...")
            time.sleep(3.0)
            self.signals.status_update.emit(f"Saving ({i+1}/{total})...")
            self.signals.request_screenshot.emit(f"Bulk_{i+1}")
            time.sleep(0.5)
        self.signals.bulk_finished.emit()

    def change_tab_from_signal(self, index):
        self.current_index = index
        QTimer.singleShot(0, self.show_current_tab)

    def update_status_text(self, text):
        self.lbl_status.setText(text)

    def bulk_capture_completed(self):
        self.is_bulk_capturing = False
        self.toggle_ui_elements(True)
        self.lbl_status.setText(f"✅ Captured {len(self.domains_list)} views!")

    def toggle_ui_elements(self, enabled):
        self.btn_screenshot.setEnabled(enabled)
        self.btn_bulk_screenshot.setEnabled(enabled)
        self.btn_prev.setEnabled(enabled)
        self.btn_next.setEnabled(enabled)

    def truncate_path(self, path):
        if len(path) > 25: return "..." + path[-22:]
        return path

    def load_saved_history(self):
        if os.path.exists(HISTORY_FILE):
            try:
                with open(HISTORY_FILE, "r", encoding="utf-8") as f: links = f.read().strip()
                if links: self.txt_domains.setText(links)
            except: pass


# =====================================================================
#  TAB 3: SHIFT BREAK TIMER & SETTINGS INTERFACE
# =====================================================================
class BreakTimerTab(QWidget):
    lock_confirmed = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.total_seconds = 0
        self.timer_running = False
        self.shift_ended_notified = False

        self.countdown_timer = QTimer(self)
        self.countdown_timer.timeout.connect(self.update_countdown)

        self.setStyleSheet("""
            QLabel { color: #e0e0e0; font-family: 'Arial'; }
            QLineEdit { background-color: #222; color: white; border: 1px solid #444; padding: 6px; border-radius: 4px; font-size: 14px; }
            QComboBox { background-color: #222; color: white; border: 1px solid #444; padding: 6px; border-radius: 4px; }
            QTimeEdit { background-color: #222; color: white; border: 1px solid #444; padding: 5px; border-radius: 4px; font-size: 13px; }
            QPushButton { font-weight: bold; font-size: 13px; padding: 10px; border-radius: 5px; }
        """)
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)

        lbl_shift_title = QLabel("Shift Hours Config (Controls Simulator Battery & End Alerts):")
        lbl_shift_title.setStyleSheet("font-weight: bold; font-size: 13px; color: #007acc; border-bottom: 1px solid #333; padding-bottom: 4px;")
        layout.addWidget(lbl_shift_title)

        shift_panel = QFrame()
        shift_panel.setStyleSheet("background-color: #1a1a1a; padding: 10px; border-radius: 6px;")
        sp_layout = QVBoxLayout(shift_panel)

        times_layout = QHBoxLayout()
        times_layout.addWidget(QLabel("Shift Start:"))
        self.time_start = QTimeEdit()
        self.time_start.setDisplayFormat("HH:mm")
        self.time_start.setTime(QTime(8, 0))
        times_layout.addWidget(self.time_start)

        times_layout.addSpacing(10)
        times_layout.addWidget(QLabel("Shift End:"))
        self.time_end = QTimeEdit()
        self.time_end.setDisplayFormat("HH:mm")
        self.time_end.setTime(QTime(17, 0))
        times_layout.addWidget(self.time_end)
        sp_layout.addLayout(times_layout)

        self.btn_lock_shift = QPushButton("🔐 Lock-In Shift Hours")
        self.btn_lock_shift.setStyleSheet("background-color: #007acc; color: white; margin-top: 5px; padding: 6px;")
        self.btn_lock_shift.clicked.connect(self.lock_in_pressed)
        sp_layout.addWidget(self.btn_lock_shift)

        layout.addWidget(shift_panel)
        layout.addSpacing(10)

        lbl_title = QLabel("Set Break Duration:")
        lbl_title.setStyleSheet("font-weight: bold; font-size: 13px; color: #007acc;")
        layout.addWidget(lbl_title)

        input_frame = QWidget()
        input_layout = QHBoxLayout(input_frame)
        input_layout.setContentsMargins(0, 0, 0, 0)
        
        self.txt_duration = QLineEdit()
        self.txt_duration.setText("15")
        input_layout.addWidget(self.txt_duration)

        self.combo_unit = QComboBox()
        self.combo_unit.addItems(["Minutes", "Hours"])
        input_layout.addWidget(self.combo_unit)
        layout.addWidget(input_frame)

        self.lbl_countdown = QLabel("00:00:00")
        self.lbl_countdown.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_countdown.setStyleSheet("font-size: 36px; font-weight: bold; color: #a6a6a6; font-family: 'Consolas'; margin: 10px 0;")
        layout.addWidget(self.lbl_countdown)

        self.btn_control = QPushButton("🚀 Start Break")
        self.btn_control.setStyleSheet("background-color: #28a745; color: white;")
        self.btn_control.clicked.connect(self.toggle_timer)
        layout.addWidget(self.btn_control)
        layout.addStretch()
        self.load_saved_shift_hours()

    def lock_in_pressed(self):
        t1 = self.time_start.time().toString("HH:mm")
        t2 = self.time_end.time().toString("HH:mm")
        try:
            with open(SHIFT_CONFIG_FILE, "w", encoding="utf-8") as f: f.write(f"{t1},{t2}")
        except: pass
        self.lock_confirmed.emit()
        self.btn_lock_shift.setText("✅ Shift Hours Synchronized!")
        self.btn_lock_shift.setStyleSheet("background-color: #28a745; color: white; margin-top: 5px; padding: 6px;")
        QTimer.singleShot(2500, self.reset_lock_button_style)

    def reset_lock_button_style(self):
        self.btn_lock_shift.setText("🔐 Lock-In Shift Hours")
        self.btn_lock_shift.setStyleSheet("background-color: #007acc; color: white; margin-top: 5px; padding: 6px;")

    def load_saved_shift_hours(self):
        if os.path.exists(SHIFT_CONFIG_FILE):
            try:
                with open(SHIFT_CONFIG_FILE, "r", encoding="utf-8") as f:
                    data = f.read().strip().split(",")
                    if len(data) == 2:
                        self.time_start.setTime(QTime.fromString(data[0], "HH:mm"))
                        self.time_end.setTime(QTime.fromString(data[1], "HH:mm"))
            except: pass

    def toggle_timer(self):
        if not self.timer_running:
            try:
                val = float(self.txt_duration.text().strip())
                if val <= 0: raise ValueError
            except:
                self.lbl_countdown.setText("Invalid Time!")
                return

            self.total_seconds = int(val * 60) if self.combo_unit.currentText() == "Minutes" else int(val * 3600)
            self.timer_running = True
            self.txt_duration.setEnabled(False)
            self.combo_unit.setEnabled(False)
            self.btn_control.setText("⏱️ Stop / Reset")
            self.btn_control.setStyleSheet("background-color: #dc3545; color: white;")
            self.lbl_countdown.setStyleSheet("font-size: 36px; font-weight: bold; color: #007acc; font-family: 'Consolas';")
            self.update_display()
            self.countdown_timer.start(1000)
        else:
            self.reset_timer()

    def update_countdown(self):
        if self.total_seconds > 1:
            self.total_seconds -= 1
            self.update_display()
        else:
            self.reset_timer()
            self.lbl_countdown.setStyleSheet("font-size: 26px; color: #28a745; font-weight: bold;")
            self.lbl_countdown.setText("Break Over!")
            notification.notify(title="⏱️ Break Time Over!", message="Time to jump back on shift!", timeout=12)
            AUDIO_ENGINE.play_system_alert("break_end")

    def update_display(self):
        h = self.total_seconds // 3600
        m = (self.total_seconds % 3600) // 60
        s = self.total_seconds % 60
        self.lbl_countdown.setText(f"{h:02d}:{m:02d}:{s:02d}")

    def reset_timer(self):
        self.countdown_timer.stop()
        self.timer_running = False
        self.txt_duration.setEnabled(True)
        self.combo_unit.setEnabled(True)
        self.btn_control.setText("🚀 Start Break")
        self.btn_control.setStyleSheet("background-color: #28a745; color: white;")
        self.lbl_countdown.setStyleSheet("font-size: 36px; font-weight: bold; color: #a6a6a6; font-family: 'Consolas';")
        self.lbl_countdown.setText("00:00:00")


# =====================================================================
#  TAB 4: DYNAMIC CUSTOMER SUPPORT TICKETING FORMS GENERATOR
# =====================================================================
import os
import json
from datetime import datetime
from PyQt6.QtCore import Qt, QTimer, QPoint
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                             QLineEdit, QTextEdit, QCheckBox, QComboBox, 
                             QFrame, QScrollArea, QPushButton, QMenu, QApplication)

class FormsGeneratorTab(QWidget):
    def __init__(self):
        super().__init__()
        
        # 1. Try to get the actual directory where the script file lives
        if "__file__" in locals() or globals().get("__file__"):
            self.script_dir = os.path.dirname(os.path.abspath(__file__))
        else:
            self.script_dir = os.getcwd()
            
        # 2. SAFETY CHECK: If the path points to system32, or is completely unwriteable, force override to User Home
        if "system32" in self.script_dir.lower() or not os.access(self.script_dir, os.W_OK):
            self.script_dir = os.path.expanduser("~")
            
        self.saved_forms_file = os.path.join(self.script_dir, "saved_forms_history.json")
        
        self.setStyleSheet("""
            QLabel { color: #f1f5f9; font-size: 12px; font-family: 'Arial'; }
            QLineEdit, QTextEdit { background-color: #1e1e1e; color: #ffffff; border: 1px solid #3a3a3a; padding: 5px; border-radius: 4px; font-family: 'Consolas'; font-size: 12px; }
            QCheckBox { color: #cbd5e1; font-size: 11px; font-weight: bold; }
            QComboBox { background-color: #262626; color: white; border: 1px solid #444; padding: 4px; border-radius: 4px; }
            QFrame#PreviewBox { border: 2px dashed #007acc; background-color: #111111; border-radius: 6px; }
            QScrollArea { border: none; background: transparent; }
            
            /* History & Action Button Styles */
            QPushButton#BtnCircle { background-color: #1e293b; border: 1px solid #475569; color: #cbd5e1; border-radius: 14px; font-size: 14px; font-weight: bold; }
            QPushButton#BtnCircle:hover { background-color: #334155; border-color: #3b82f6; color: #3b82f6; }
            QPushButton#BtnReset { background-color: #3f3f46; color: white; font-weight: bold; font-size: 11px; border-radius: 4px; padding: 5px; }
            QPushButton#BtnReset:hover { background-color: #52525b; }
            QPushButton#BtnSave { background-color: #0b5ed7; color: white; font-weight: bold; font-size: 11px; border-radius: 4px; padding: 5px; }
            QPushButton#BtnSave:hover { background-color: #0a58ca; }
            
            QMenu { background-color: #1e1e1e; color: white; border: 1px solid #333; }
            QMenu::item { padding: 6px 20px; }
            QMenu::item:selected { background-color: #007acc; }
        """)
        self.init_ui()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(15, 15, 15, 15)
        main_layout.setSpacing(10)

        opts_frame = QFrame()
        opts_frame.setStyleSheet("background-color: #1a1a1a; border-radius: 6px; padding: 8px;")
        opts_layout = QVBoxLayout(opts_frame)

        ft_title = QLabel("📁 CHOOSE SYSTEM FORM PROFILE TYPES (MULTIPLE ALLOWED):")
        ft_title.setStyleSheet("font-weight: bold; color: #007acc; font-size: 11px;")
        opts_layout.addWidget(ft_title)

        form_types_layout = QHBoxLayout()
        self.chk_phone = QCheckBox("Change Phone Number")
        self.chk_wallet = QCheckBox("Change Wallet")
        self.chk_temp_pass = QCheckBox("Request Temporary Password")
        self.chk_forgot_user = QCheckBox("Forgot Username")
        self.chk_forgot_phone = QCheckBox("Forgot Phone Number")

        for chk in [self.chk_phone, self.chk_wallet, self.chk_temp_pass, self.chk_forgot_user, self.chk_forgot_phone]:
            chk.stateChanged.connect(self.refresh_form_matrix_state)
            form_types_layout.addWidget(chk)
        opts_layout.addLayout(form_types_layout)

        self.wallet_dropdown_container = QWidget()
        wd_layout = QHBoxLayout(self.wallet_dropdown_container)
        wd_layout.setContentsMargins(0, 5, 0, 0)
        wd_layout.addWidget(QLabel("Select Old Wallet Profile Type:"))
        self.combo_old_wallet = QComboBox()
        self.combo_old_wallet.addItems(["Gcash", "Paymaya", "Bank"])
        self.combo_old_wallet.currentTextChanged.connect(self.trigger_live_render)
        wd_layout.addWidget(self.combo_old_wallet)

        wd_layout.addSpacing(15)
        wd_layout.addWidget(QLabel("Select New Wallet Profile Type:"))
        self.combo_new_wallet = QComboBox()
        self.combo_new_wallet.addItems(["Gcash", "Paymaya", "Bank"])
        self.combo_new_wallet.currentTextChanged.connect(self.trigger_live_render)
        wd_layout.addWidget(self.combo_new_wallet)
        self.wallet_dropdown_container.setVisible(False)
        opts_layout.addWidget(self.wallet_dropdown_container)

        req_title = QLabel("📋 COMPLIANCE AND DOCUMENT REQUIREMENTS ATTACHMENTS:")
        req_title.setStyleSheet("font-weight: bold; color: #007acc; font-size: 11px; margin-top: 4px;")
        opts_layout.addWidget(req_title)

        req_row_layout = QHBoxLayout()
        self.chk_req_id = QCheckBox("Valid ID")
        self.chk_req_video = QCheckBox("VIDEO")
        self.chk_req_sms = QCheckBox("Text SMS")
        self.chk_req_wallet_snap = QCheckBox("Wallet Screenshot")

        for r_chk in [self.chk_req_id, self.chk_req_video, self.chk_req_sms, self.chk_req_wallet_snap]:
            r_chk.stateChanged.connect(self.trigger_live_render)
            req_row_layout.addWidget(r_chk)
        opts_layout.addLayout(req_row_layout)
        main_layout.addWidget(opts_frame)

        workspace_layout = QHBoxLayout()
        
        # --- SCROLLABLE INPUT LAYOUT ---
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        
        scroll_content_widget = QWidget()
        scroll_content_widget.setStyleSheet("background: transparent;")
        left_input_col = QVBoxLayout(scroll_content_widget)
        left_input_col.setContentsMargins(0, 0, 8, 0)
        left_input_col.setSpacing(6)
        
        left_input_col.addWidget(QLabel("User Identifier:"))
        self.in_username = QLineEdit()
        left_input_col.addWidget(self.in_username)

        left_input_col.addWidget(QLabel("Full Name:"))
        self.in_fullname = QLineEdit()
        left_input_col.addWidget(self.in_fullname)

        self.lbl_in_reg_phone = QLabel("Registered Phone Number:")
        self.in_reg_phone = QLineEdit()
        left_input_col.addWidget(self.lbl_in_reg_phone)
        left_input_col.addWidget(self.in_reg_phone)

        left_input_col.addWidget(QLabel("Gender:"))
        self.in_gender = QLineEdit()
        left_input_col.addWidget(self.in_gender)

        left_input_col.addWidget(QLabel("Email :"))
        self.in_email = QLineEdit()
        left_input_col.addWidget(self.in_email)

        left_input_col.addWidget(QLabel("Birth Date"))
        self.in_birthdate = QLineEdit()
        left_input_col.addWidget(self.in_birthdate)

        self.phone_form_inputs_widget = QWidget()
        pfi_layout = QVBoxLayout(self.phone_form_inputs_widget)
        pfi_layout.setContentsMargins(0,0,0,0)
        pfi_layout.setSpacing(6)
        pfi_layout.addWidget(QLabel("Old Phone Number:"))
        self.in_old_phone = QLineEdit()
        pfi_layout.addWidget(self.in_old_phone)
        pfi_layout.addWidget(QLabel("New Phone Number:"))
        self.in_new_phone = QLineEdit()
        pfi_layout.addWidget(self.in_new_phone)
        self.phone_form_inputs_widget.setVisible(False)
        left_input_col.addWidget(self.phone_form_inputs_widget)

        self.wallet_form_inputs_widget = QWidget()
        wfi_layout = QVBoxLayout(self.wallet_form_inputs_widget)
        wfi_layout.setContentsMargins(0,0,0,0)
        wfi_layout.setSpacing(6)
        self.lbl_old_wallet_num = QLabel("Old Wallet Number:")
        self.in_old_wallet_num = QLineEdit()
        self.lbl_old_wallet_name = QLabel("Old Wallet Account Name:")
        self.in_old_wallet_name = QLineEdit()
        self.lbl_new_wallet_num = QLabel("New Wallet Number:")
        self.in_new_wallet_num = QLineEdit()
        self.lbl_new_wallet_name = QLabel("New Wallet Account Name:")
        self.in_new_wallet_name = QLineEdit()
        
        for w_widget in [self.lbl_old_wallet_num, self.in_old_wallet_num, self.lbl_old_wallet_name, self.in_old_wallet_name,
                         self.lbl_new_wallet_num, self.in_new_wallet_num, self.lbl_new_wallet_name, self.in_new_wallet_name]:
            wfi_layout.addWidget(w_widget)
        self.wallet_form_inputs_widget.setVisible(False)
        left_input_col.addWidget(self.wallet_form_inputs_widget)

        left_input_col.addWidget(QLabel("Reason:"))
        self.in_reason = QLineEdit()
        left_input_col.addWidget(self.in_reason)

        left_input_col.addWidget(QLabel("Comments:"))
        self.in_additional_details = QLineEdit()
        left_input_col.addWidget(self.in_additional_details)
        
        self.all_input_fields = [
            self.in_username, self.in_fullname, self.in_reg_phone, self.in_gender, self.in_email, 
            self.in_birthdate, self.in_old_phone, self.in_new_phone, self.in_old_wallet_num, 
            self.in_old_wallet_name, self.in_new_wallet_num, self.in_new_wallet_name, self.in_reason, 
            self.in_additional_details
        ]

        for input_field in self.all_input_fields:
            input_field.textChanged.connect(self.trigger_live_render)

        self.scroll_area.setWidget(scroll_content_widget)
        workspace_layout.addWidget(self.scroll_area, 4)

        right_preview_col = QVBoxLayout()
        lbl_preview_title = QLabel("📄 CLICK INSIDE PREVIEW DISPLAY TO INSTANTLY COPY FORM TEMPLATE:")
        lbl_preview_title.setStyleSheet("font-weight: bold; color: #10b981; font-size: 11px;")
        right_preview_col.addWidget(lbl_preview_title)

        self.txt_output_preview = QTextEdit()
        self.txt_output_preview.setObjectName("PreviewBox")
        self.txt_output_preview.setReadOnly(True)
        self.txt_output_preview.setPlaceholderText("Select form profiles above to populate structured queue scripts...")
        self.txt_output_preview.mousePressEvent = self.intercept_click_to_clipboard
        right_preview_col.addWidget(self.txt_output_preview)

        # --- ACTION CONTROL BAR INTEGRATIONS ---
        action_bar_layout = QHBoxLayout()
        
        self.btn_reset = QPushButton("🗑️ Reset Form")
        self.btn_reset.setObjectName("BtnReset")
        self.btn_reset.clicked.connect(self.reset_entire_form)
        action_bar_layout.addWidget(self.btn_reset, 2)

        self.btn_save = QPushButton("💾 Save Form")
        self.btn_save.setObjectName("BtnSave")
        self.btn_save.clicked.connect(self.save_current_form)
        action_bar_layout.addWidget(self.btn_save, 2)

        self.btn_history = QPushButton("⏳")
        self.btn_history.setObjectName("BtnCircle")
        self.btn_history.setFixedSize(28, 28)
        self.btn_history.setToolTip("View Saved History")
        self.btn_history.clicked.connect(self.show_history_popup_menu)
        action_bar_layout.addWidget(self.btn_history, 0)
        
        right_preview_col.addLayout(action_bar_layout)

        self.lbl_copy_toast = QLabel("")
        self.lbl_copy_toast.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_copy_toast.setStyleSheet("font-weight: bold; color: #10b981; font-size: 12px;")
        right_preview_col.addWidget(self.lbl_copy_toast)

        workspace_layout.addLayout(right_preview_col, 5)
        main_layout.addLayout(workspace_layout)
        
        self.trigger_live_render()

    def refresh_form_matrix_state(self):
        phone_checked = self.chk_phone.isChecked()
        wallet_checked = self.chk_wallet.isChecked()
        forgot_phone_checked = self.chk_forgot_phone.isChecked()

        self.wallet_dropdown_container.setVisible(wallet_checked)
        self.phone_form_inputs_widget.setVisible(phone_checked)
        self.wallet_form_inputs_widget.setVisible(wallet_checked)

        self.chk_req_sms.setEnabled(phone_checked)
        if not phone_checked:
            self.chk_req_sms.setChecked(False)

        self.chk_req_wallet_snap.setEnabled(wallet_checked)
        if not wallet_checked:
            self.chk_req_wallet_snap.setChecked(False)

        has_phone_removal_condition = (phone_checked or forgot_phone_checked)
        self.lbl_in_reg_phone.setVisible(not has_phone_removal_condition)
        self.in_reg_phone.setVisible(not has_phone_removal_condition)

        if wallet_checked:
            old_w_type = self.combo_old_wallet.currentText()
            new_w_type = self.combo_new_wallet.currentText()
            self.lbl_old_wallet_num.setText(f"Old {old_w_type} Account Number:")
            self.lbl_old_wallet_name.setText(f"Old {old_w_type} Account Name:")
            self.lbl_new_wallet_num.setText(f"New {new_w_type} Account Number:")
            self.lbl_new_wallet_name.setText(f"New {new_w_type} Account Name:")

        self.trigger_live_render()

    def trigger_live_render(self):
        phone_checked = self.chk_phone.isChecked()
        wallet_checked = self.chk_wallet.isChecked()
        temp_pass_checked = self.chk_temp_pass.isChecked()
        forgot_user_checked = self.chk_forgot_user.isChecked()
        forgot_phone_checked = self.chk_forgot_phone.isChecked()

        any_form_type_selected = (phone_checked or wallet_checked or temp_pass_checked or forgot_user_checked or forgot_phone_checked)

        if not any_form_type_selected:
            self.txt_output_preview.setPlainText("")
            return

        output_buffer = "Please fill in the following: Details ng may-ari ng Panaloko account\n\n"

        if not forgot_user_checked:
            output_buffer += f"Username: {self.in_username.text()}\n"
        
        output_buffer += f"Full name: {self.in_fullname.text()}\n"
        
        if not phone_checked and not forgot_phone_checked:
            output_buffer += f"Registered Phone Number: {self.in_reg_phone.text()}\n"
            
        output_buffer += f"Gender: {self.in_gender.text()}\n"
        output_buffer += f"Email add.: {self.in_email.text()}\n"
        output_buffer += f"Birthday: {self.in_birthdate.text()}\n"

        if phone_checked:
            output_buffer += f"\nOld Phone Number: {self.in_old_phone.text()}\n"
            output_buffer += f"New Phone Number: {self.in_new_phone.text()}\n"

        if wallet_checked:
            old_w = self.combo_old_wallet.currentText()
            new_w = self.combo_new_wallet.currentText()
            output_buffer += f"————-\n"
            output_buffer += f"OLD {old_w.upper()} NUMBER: {self.in_old_wallet_num.text()}\n"
            output_buffer += f"OLD {old_w.upper()} NAME: {self.in_old_wallet_name.text()}\n\n"
            output_buffer += f"NEW {new_w.upper()} NUMBER: {self.in_new_wallet_num.text()}\n"
            output_buffer += f"NEW {new_w.upper()} NAME: {self.in_new_wallet_name.text()}\n"
        
        if self.in_additional_details.text().strip():
            output_buffer += f"\nAdditional Comments: {self.in_additional_details.text().strip()}\n"

        if self.in_reason.text().strip():
            output_buffer += f"Reason: {self.in_reason.text().strip()}\n"

       
        has_requirements_header = False
        requirements_buffer = ""

        if self.chk_req_wallet_snap.isChecked() and wallet_checked:
            if not has_requirements_header:
                requirements_buffer += "\nPlease send:\n"
                has_requirements_header = True
            new_w = self.combo_new_wallet.currentText()
            requirements_buffer += f"🚨 Screenshot ng New {new_w} Profile\n"

        if self.chk_req_id.isChecked():
            if not has_requirements_header:
                requirements_buffer += "\nPlease send:\n"
                has_requirements_header = True
            requirements_buffer += "🚨 1 Valid ID (picture)\n"

        if self.chk_req_video.isChecked():
            if not has_requirements_header:
                requirements_buffer += "\nPlease send:\n"
                has_requirements_header = True
            requirements_buffer += "🚨 VIDEO hawak ang inyong valid ID habang sinasabi ang petsa ngayong araw (date today)\n"

        output_buffer += requirements_buffer

        if self.chk_req_sms.isChecked() and phone_checked:
            output_buffer += "\nPaki-text po ang 09941273599 paki lagay ang\n"
            output_buffer += "Username + OLD Phone Number + NEW Phone Number sa message po\n\n"
            output_buffer += "Gamitin po ang NEW number sa pagtext.\nSalamat po.\n"

        self.txt_output_preview.setPlainText(output_buffer.strip())

    def intercept_click_to_clipboard(self, event):
        text_to_copy = self.txt_output_preview.toPlainText().strip()
        if text_to_copy:
            clipboard = QApplication.clipboard()
            clipboard.setText(text_to_copy)
            
            self.lbl_copy_toast.setText("📋 TEMPLATE COPIED TO CLIPBOARD!")
            QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))
            
        QTextEdit.mousePressEvent(self.txt_output_preview, event)

    def reset_entire_form(self):
        for field in self.all_input_fields:
            field.blockSignals(True)
            field.clear()
            field.blockSignals(False)

        for chk in [self.chk_phone, self.chk_wallet, self.chk_temp_pass, self.chk_forgot_user, self.chk_forgot_phone,
                    self.chk_req_id, self.chk_req_video, self.chk_req_sms, self.chk_req_wallet_snap]:
            chk.blockSignals(True)
            chk.setChecked(False)
            chk.blockSignals(False)

        self.combo_old_wallet.setCurrentIndex(0)
        self.combo_new_wallet.setCurrentIndex(0)
        
        self.refresh_form_matrix_state()
        self.lbl_copy_toast.setText("🗑️ Form Cleaned and Reset!")
        QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))

    def save_current_form(self):
        username = self.in_username.text().strip()
        display_name = username if username else "Unnamed Account"
        
        form_snapshot = {
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "checkboxes": {
                "phone": self.chk_phone.isChecked(),
                "wallet": self.chk_wallet.isChecked(),
                "temp_pass": self.chk_temp_pass.isChecked(),
                "forgot_user": self.chk_forgot_user.isChecked(),
                "forgot_phone": self.chk_forgot_phone.isChecked(),
                "req_id": self.chk_req_id.isChecked(),
                "req_video": self.chk_req_video.isChecked(),
                "req_sms": self.chk_req_sms.isChecked(),
                "req_wallet_snap": self.chk_req_wallet_snap.isChecked()
            },
            "combos": {
                "old_wallet": self.combo_old_wallet.currentText(),
                "new_wallet": self.combo_new_wallet.currentText()
            },
            "fields": {
                "username": self.in_username.text(),
                "fullname": self.in_fullname.text(),
                "reg_phone": self.in_reg_phone.text(),
                "gender": self.in_gender.text(),
                "email": self.in_email.text(),
                "birthdate": self.in_birthdate.text(),
                "old_phone": self.in_old_phone.text(),
                "new_phone": self.in_new_phone.text(),
                "old_wallet_num": self.in_old_wallet_num.text(),
                "old_wallet_name": self.in_old_wallet_name.text(),
                "new_wallet_num": self.in_new_wallet_num.text(),
                "new_wallet_name": self.in_new_wallet_name.text(),
                "reason": self.in_reason.text(),
                "additional_details": self.in_additional_details.text()
            }
        }

        history = []
        if os.path.exists(self.saved_forms_file):
            try:
                with open(self.saved_forms_file, "r", encoding="utf-8") as f:
                    history = json.load(f)
            except Exception as e:
                print(f"[Form History Debug] Load warning: {e}")

        history.insert(0, form_snapshot)
        if len(history) > 20:
            history = history[:20]

        try:
            with open(self.saved_forms_file, "w", encoding="utf-8") as f:
                json.dump(history, f, indent=4)
            self.lbl_copy_toast.setText(f"💾 Form Saved ({display_name})")
        except Exception as e:
            # Prints the exact system error details directly to your terminal window
            print(f"[Form History Debug] Critical Write Failure: {e}")
            self.lbl_copy_toast.setText("❌ Error writing save files!")
        
        QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))

    def show_history_popup_menu(self):
        if not os.path.exists(self.saved_forms_file):
            self.lbl_copy_toast.setText("⏱️ History Log Empty")
            QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))
            return

        try:
            with open(self.saved_forms_file, "r", encoding="utf-8") as f:
                history = json.load(f)
        except:
            return

        if not history:
            self.lbl_copy_toast.setText("⏱️ History Log Empty")
            QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))
            return

        menu = QMenu(self)
        
        # Populate history records
        for idx, record in enumerate(history):
            usr = record["fields"].get("username", "").strip()
            ts = record.get("timestamp", "").split(" ")[1]
            label = f"👤 {usr} [{ts}]" if usr else f"👤 Unnamed Account [{ts}]"
            
            action = menu.addAction(label)
            action.triggered.connect(lambda checked=False, i=idx: self.load_selected_history_record(history[i]))
            
        # Add a separator and the Clear History button at the bottom
        menu.addSeparator()
        
        # Create a widget action to embed a styled QLabel inside the menu
        from PyQt6.QtWidgets import QWidgetAction, QLabel
        
        clear_action = QWidgetAction(menu)
        clear_label = QLabel("❌ Clear History")
        clear_label.setStyleSheet("""
            QLabel {
                color: #ef4444; 
                font-weight: bold; 
                padding: 6px 20px;
                background: transparent;
            }
            QLabel:hover {
                background-color: #007acc;
                color: white;
            }
        """)
        clear_action.setDefaultWidget(clear_label)
        
        # Connect the label's click behavior to trigger our file deletion function
        clear_label.mousePressEvent = lambda event: [self.clear_history_file(), menu.close()]
        
        menu.addAction(clear_action)
        
        menu.exec(self.btn_history.mapToGlobal(QPoint(0, self.btn_history.height())))

    def clear_history_file(self):
        try:
            if os.path.exists(self.saved_forms_file):
                os.remove(self.saved_forms_file)
            self.lbl_copy_toast.setText("🗑️ History Deleted Completely!")
        except Exception as e:
            print(f"[Form History Debug] Failed to delete history file: {e}")
            self.lbl_copy_toast.setText("❌ Failed to clear history file")
            
        QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))

    def load_selected_history_record(self, record):
        for field in self.all_input_fields:
            field.blockSignals(True)
        for chk in [self.chk_phone, self.chk_wallet, self.chk_temp_pass, self.chk_forgot_user, self.chk_forgot_phone]:
            chk.blockSignals(True)

        chks = record.get("checkboxes", {})
        self.chk_phone.setChecked(chks.get("phone", False))
        self.chk_wallet.setChecked(chks.get("wallet", False))
        self.chk_temp_pass.setChecked(chks.get("temp_pass", False))
        self.chk_forgot_user.setChecked(chks.get("forgot_user", False))
        self.chk_forgot_phone.setChecked(chks.get("forgot_phone", False))
        self.chk_req_id.setChecked(chks.get("req_id", False))
        self.chk_req_video.setChecked(chks.get("req_video", False))
        self.chk_req_sms.setChecked(chks.get("req_sms", False))
        self.chk_req_wallet_snap.setChecked(chks.get("req_wallet_snap", False))

        combos = record.get("combos", {})
        self.combo_old_wallet.setCurrentText(combos.get("old_wallet", "Gcash"))
        self.combo_new_wallet.setCurrentText(combos.get("new_wallet", "Gcash"))

        fields = record.get("fields", {})
        self.in_username.setText(fields.get("username", ""))
        self.in_fullname.setText(fields.get("fullname", ""))
        self.in_reg_phone.setText(fields.get("reg_phone", ""))
        self.in_gender.setText(fields.get("gender", ""))
        self.in_email.setText(fields.get("email", ""))
        self.in_birthdate.setText(fields.get("birthdate", ""))
        self.in_old_phone.setText(fields.get("old_phone", ""))
        self.in_new_phone.setText(fields.get("new_phone", ""))
        self.in_old_wallet_num.setText(fields.get("old_wallet_num", ""))
        self.in_old_wallet_name.setText(fields.get("old_wallet_name", ""))
        self.in_new_wallet_num.setText(fields.get("new_wallet_num", ""))
        self.in_new_wallet_name.setText(fields.get("new_wallet_name", ""))
        self.in_reason.setText(fields.get("reason", ""))
        self.in_additional_details.setText(fields.get("additional_details", ""))

        for field in self.all_input_fields:
            field.blockSignals(False)
        for chk in [self.chk_phone, self.chk_wallet, self.chk_temp_pass, self.chk_forgot_user, self.chk_forgot_phone]:
            chk.blockSignals(False)

        self.refresh_form_matrix_state()
        
        usr_lbl = self.in_username.text() if self.in_username.text().strip() else "Unnamed"
        self.lbl_copy_toast.setText(f"⚡ Loaded form: {usr_lbl}")
        QTimer.singleShot(2000, lambda: self.lbl_copy_toast.setText(""))


# =====================================================================
#  SOUND NOTIFICATION SETTINGS MODAL
# =====================================================================
class SoundNotificationSettingsTab(QWidget):
    def __init__(self):
        super().__init__()
        self.built_in_sounds = [
            "Chime: Clear Ascending",
            "Chime: Descending Melancholy",
            "Siren: Critical Pulse",
            "Alarm: Buzz Drop",
            "Digital: Beep Triple",
            "Classic: Ring Gong"
        ]
        
        self.feature_map = {
            "Monitor Scan Start": "monitor_start",
            "Monitor Manual Stop": "monitor_stop",
            "Dashboard Trigger Word Match": "monitor_trigger",
            "Monitor Crashes/Session Errors": "monitor_crash",
            "Break Duration Complete Alert": "break_end",
            "Shift Ending Warning Alert": "shift_end"
        }
        
        self.dropdowns = {}
        self.setStyleSheet("""
            QLabel { color: #f1f5f9; font-size: 12px; font-family: 'Arial'; }
            QComboBox { background-color: #1e293b; color: white; border: 1px solid #475569; padding: 6px; border-radius: 4px; }
            QPushButton { font-weight: bold; font-size: 11px; padding: 6px 10px; background-color: #334155; color: white; border-radius: 4px; }
            QPushButton:hover { background-color: #475569; }
            QSlider::groove:horizontal { border: 1px solid #334155; height: 6px; background: #1e293b; border-radius: 3px; }
            QSlider::handle:horizontal { background: #3b82f6; width: 14px; margin: -4px 0; border-radius: 7px; }
        """)
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(25, 20, 25, 20)
        layout.setSpacing(14)

        lbl_header = QLabel("🔔 SOUND NOTIFICATION INTEGRATION AUDIO MATRIX")
        lbl_header.setStyleSheet("font-weight: bold; font-size: 14px; color: #3b82f6; border-bottom: 1px solid #334155; padding-bottom: 6px;")
        layout.addWidget(lbl_header)

        vol_frame = QFrame()
        vol_frame.setStyleSheet("background-color: #0f172a; border: 1px solid #1e293b; border-radius: 6px; padding: 12px;")
        vol_layout = QVBoxLayout(vol_frame)
        
        vol_lbl_layout = QHBoxLayout()
        vol_lbl_layout.addWidget(QLabel("🎚️ Master Alert Output Amplification Slider:"))
        self.lbl_vol_value = QLabel(f"{AUDIO_ENGINE.config.get('volume', 100)}%")
        self.lbl_vol_value.setStyleSheet("font-weight: bold; color: #10b981; font-size: 13px; font-family: 'Consolas';")
        vol_lbl_layout.addWidget(self.lbl_vol_value)
        vol_layout.addLayout(vol_lbl_layout)

        self.slider_volume = QSlider(Qt.Orientation.Horizontal)
        self.slider_volume.setRange(0, 200)
        self.slider_volume.setValue(AUDIO_ENGINE.config.get('volume', 100))
        self.slider_volume.sliderReleased.connect(self.handle_volume_preview_trigger)
        self.slider_volume.valueChanged.connect(self.handle_volume_change_only)
        vol_layout.addWidget(self.slider_volume)
        layout.addWidget(vol_frame)

        scroll_widget = QWidget()
        grid_layout = QVBoxLayout(scroll_widget)
        grid_layout.setSpacing(10)
        grid_layout.setContentsMargins(0, 5, 0, 5)

        for label_text, config_key in self.feature_map.items():
            row_widget = QFrame()
            row_widget.setStyleSheet("background-color: #1e293b; border-radius: 5px; padding: 8px;")
            row_layout = QHBoxLayout(row_widget)
            
            lbl_feat = QLabel(label_text + ":")
            lbl_feat.setStyleSheet("font-weight: bold; color: #cbd5e1;")
            row_layout.addWidget(lbl_feat, 2)

            combo = QComboBox()
            combo.addItems(self.built_in_sounds)
            
            saved_sound = AUDIO_ENGINE.config.get(config_key, "")
            if saved_sound in self.built_in_sounds:
                combo.setCurrentText(saved_sound)
            elif saved_sound:
                combo.addItem(os.path.basename(saved_sound))
                combo.setCurrentText(os.path.basename(saved_sound))

            combo.currentTextChanged.connect(lambda text, key=config_key: self.sound_selection_changed(text, key))
            row_layout.addWidget(combo, 3)
            self.dropdowns[config_key] = combo

            btn_browse = QPushButton("📁 Load File")
            btn_browse.clicked.connect(lambda checked, key=config_key: self.browse_custom_audio(key))
            row_layout.addWidget(btn_browse, 1)

            grid_layout.addWidget(row_widget)
        
        layout.addWidget(scroll_widget)
        layout.addStretch()

    def handle_volume_change_only(self, value):
        self.lbl_vol_value.setText(f"{value}%")
        AUDIO_ENGINE.set_volume_percentage(value)

    def handle_volume_preview_trigger(self):
        AUDIO_ENGINE.play_system_alert("monitor_start")

    def sound_selection_changed(self, text, config_key):
        if text in self.built_in_sounds:
            AUDIO_ENGINE.config[config_key] = text
            AUDIO_ENGINE.save_audio_config()
            AUDIO_ENGINE.play_system_alert(config_key)

    def browse_custom_audio(self, config_key):
        file_filter = "Audio Media Files (*.mp3 *.wav *.ogg *.m4a *.wma *.flac)"
        chosen_path, _ = QFileDialog.getOpenFileName(self, "Select System Notification Audio Track", SCRIPT_DIR, file_filter)
        if chosen_path:
            AUDIO_ENGINE.config[config_key] = chosen_path
            AUDIO_ENGINE.save_audio_config()
            combo_box = self.dropdowns[config_key]
            short_name = os.path.basename(chosen_path)
            
            combo_box.blockSignals(True)
            if combo_box.findText(short_name) == -1:
                combo_box.addItem(short_name)
            combo_box.setCurrentText(short_name)
            combo_box.blockSignals(False)
            AUDIO_ENGINE.play_system_alert(config_key)


# =====================================================================
#  MASTER WINDOW APP CONTAINER
# =====================================================================
class WorkToolkitApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Unified Workspace Panel")
        self.setFixedSize(620, 850)
        self.setStyleSheet("QMainWindow { background-color: #121212; }")

        self.global_clock = QTimer(self)
        self.global_clock.timeout.connect(self.sync_global_time)
        self.global_clock.start(1000)

        self.tabs = QTabWidget()
        self.tabs.setStyleSheet("""
            QTabWidget::panel { border: none; background-color: #121212; }
            QTabBar::tab { background-color: #1a1a1a; color: #888; font-weight: bold; padding: 12px; border-right: 1px solid #252525; }
            QTabBar::tab:selected { background-color: #121212; color: #007acc; border-bottom: 2px solid #007acc; }
        """)
        self.setCentralWidget(self.tabs)

        self.monitor_tab = DashboardMonitorTab()
        self.inspector_tab = MobileInspectorTab()
        self.timer_tab = BreakTimerTab()
        self.forms_tab = FormsGeneratorTab()
        self.audio_settings_tab = SoundNotificationSettingsTab()

        self.timer_tab.lock_confirmed.connect(self.sync_global_time)

        self.tabs.addTab(self.monitor_tab, "🖥️ Dashboard Monitor")
        self.tabs.addTab(self.inspector_tab, "📱 Mobile Inspector")
        self.tabs.addTab(self.timer_tab, "⏱️ Break Timer")
        self.tabs.addTab(self.forms_tab, "📝 Forms Generator")
        
        self.settings_index = self.tabs.addTab(self.audio_settings_tab, "")
        self.tabs.setTabVisible(self.settings_index, False)

        self.corner_widget = QWidget()
        corner_layout = QHBoxLayout(self.corner_widget)
        corner_layout.setContentsMargins(0, 0, 8, 0)
        
        self.btn_bell_settings = QPushButton("🔔")
        self.btn_bell_settings.setFixedSize(30, 30)
        self.btn_bell_settings.setCheckable(True)
        self.btn_bell_settings.setStyleSheet("""
            QPushButton { background-color: #222; border: 1px solid #444; border-radius: 15px; color: #aaa; font-size: 13px; padding: 0px; }
            QPushButton:hover { background-color: #333; color: #007acc; border-color: #007acc; }
            QPushButton:checked { background-color: #007acc; color: white; border-color: #007acc; }
        """)
        self.btn_bell_settings.clicked.connect(self.handle_corner_settings_toggle)
        corner_layout.addWidget(self.btn_bell_settings)
        
        self.tabs.setCornerWidget(self.corner_widget, Qt.Corner.TopRightCorner)
        self.tabs.currentChanged.connect(self.handle_tab_changed_manually)

        self.inspector_tab.load_saved_history()
        AUDIO_ENGINE.set_volume_percentage(AUDIO_ENGINE.config.get("volume", 100))
        QTimer.singleShot(100, self.sync_global_time)

    def handle_corner_settings_toggle(self, checked):
        if checked: self.tabs.setCurrentIndex(self.settings_index)
        else: self.tabs.setCurrentIndex(0)

    def handle_tab_changed_manually(self, index):
        if index == self.settings_index:
            self.btn_bell_settings.blockSignals(True)
            self.btn_bell_settings.setChecked(True)
            self.btn_bell_settings.blockSignals(False)
        else:
            self.btn_bell_settings.blockSignals(True)
            self.btn_bell_settings.setChecked(False)
            self.btn_bell_settings.blockSignals(False)

    def get_random_battery_modifiers(self):
        now_dt = datetime.now()
        effective_date = now_dt - timedelta(days=1) if now_dt.hour < 8 else now_dt
        seed_key = int(effective_date.strftime("%Y%m%d"))
        random.seed(seed_key)

        variations = [
            {"start": 98, "min_end": 18, "curve": 0.95}, {"start": 100, "min_end": 26, "curve": 1.05},
            {"start": 95, "min_end": 15, "curve": 0.88}, {"start": 97, "min_end": 22, "curve": 1.00},
            {"start": 100, "min_end": 16, "curve": 0.92}, {"start": 94, "min_end": 20, "curve": 1.10},
            {"start": 99, "min_end": 24, "curve": 0.98}, {"start": 96, "min_end": 17, "curve": 1.02},
            {"start": 100, "min_end": 19, "curve": 0.85}, {"start": 93, "min_end": 15, "curve": 1.15}
        ]
        selected_mod = random.choice(variations)
        random.seed()
        return selected_mod

    def sync_global_time(self):
        now = QTime.currentTime()
        current_time_str = now.toString("HH:mm")
        start_time = self.timer_tab.time_start.time()
        end_time = self.timer_tab.time_end.time()
        
        if start_time <= end_time:
            total_shift_secs = start_time.secsTo(end_time)
            is_overnight = False
        else:
            total_shift_secs = start_time.secsTo(QTime(23, 59, 59)) + QTime(0, 0).secsTo(end_time) + 1
            is_overnight = True

        if not is_overnight:
            is_active = (start_time <= now <= end_time)
            has_ended = (now > end_time)
        else:
            is_active = (now >= start_time or now <= end_time)
            has_ended = (end_time < now < start_time)

        if has_ended:
            battery_pct = 15
            battery_icon = "🪫"
            if not self.timer_tab.shift_ended_notified:
                self.timer_tab.shift_ended_notified = True
                notification.notify(title="🎉 Shift Complete!", message="Your working hours have ended. Time to clock out!", timeout=15)
                AUDIO_ENGINE.play_system_alert("shift_end")
        elif not is_active:
            battery_pct = 100
            battery_icon = "🔋"
            self.timer_tab.shift_ended_notified = False
        else:
            self.timer_tab.shift_ended_notified = False
            if not is_overnight: elapsed_secs = start_time.secsTo(now)
            else: elapsed_secs = start_time.secsTo(QTime(23, 59, 59)) + QTime(0, 0).secsTo(now) + 1
            
            if total_shift_secs > 0:
                config = self.get_random_battery_modifiers()
                linear_ratio = elapsed_secs / total_shift_secs
                curved_ratio = pow(linear_ratio, config["curve"])
                max_depreciation = config["start"] - config["min_end"]
                battery_pct = int(config["start"] - (curved_ratio * max_depreciation))
            else:
                battery_pct = 100
                
            if battery_pct > 100: battery_pct = 100
            if battery_pct < 15: battery_pct = 15
            battery_icon = "🔋" if battery_pct > 35 else "🪫"
                
        self.inspector_tab.lbl_time.setText(current_time_str)
        self.inspector_tab.lbl_battery.setText(f"📶 🛜 {battery_icon} {battery_pct}%")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = WorkToolkitApp()
    window.show()
    sys.exit(app.exec())