import customtkinter as ctk
import pyautogui
import keyboard
import threading
import time
import sys
import win32api
import win32con
import numpy as np
import pyperclip

class RobloxAFKOverlay(ctk.CTk):
    def __init__(self):
        super().__init__()

        # Настройки окна: убираем стандартную рамку Windows и делаем поверх всех окон
        self.overrideredirect(True)
        self.attributes("-topmost", True)
        self.geometry("380x365+100+100") # компактный размер
        
        # Переменные состояния макроса
        self.is_running = False
        self.macro_thread = None
        self.capture_target = None
        
        # Дефолтные координаты для реконнекта
        self.reconnect_x1 = 967
        self.reconnect_y1 = 599
        self.reconnect_x2 = 1138
        self.reconnect_y2 = 631
        
        # Настройка темы CustomTkinter
        ctk.set_appearance_mode("dark")
        
        # Наша собственная минималистичная палитра (но не "кибер")
        self.bg_color = "#161618"          # Глубокий матовый темный фон
        self.border_color = "#2c2c2e"      # Очень тонкая нейтральная рамка
        self.header_color = "#1c1c1e"      # Чуть более светлый заголовок
        self.accent_color = "#3a86ff"      # Спокойный синий акцент
        self.text_main = "#f2f2f7"         # Мягкий белый для текста
        self.text_muted = "#8e8e93"        # Серый приглушенный для деталей
        self.btn_green = "#34c759"         # Спокойный зеленый (iOS стиль)
        self.btn_red = "#ff3b30"           # Спокойный красный (iOS стиль)

        # Основной контейнер с рамкой
        self.main_frame = ctk.CTkFrame(
            self, 
            corner_radius=10, 
            border_width=1, 
            border_color=self.border_color,
            fg_color=self.bg_color
        )
        self.main_frame.pack(fill="both", expand=True)

        # --- Минималистичный заголовок для перетаскивания (Drag Bar) ---
        self.drag_bar = ctk.CTkFrame(self.main_frame, height=35, fg_color=self.header_color, corner_radius=0)
        self.drag_bar.pack(fill="x", side="top")
        self.drag_bar.pack_propagate(False)

        # Бинд перетаскивания окна мышкой
        self.drag_bar.bind("<Button-1>", self.start_drag)
        self.drag_bar.bind("<B1-Motion>", self.drag_window)

        self.title_label = ctk.CTkLabel(
            self.drag_bar, 
            text="Roblox AFK Utility", 
            font=("Segoe UI", 11, "bold"),
            text_color=self.text_main
        )
        self.title_label.pack(side="left", padx=12)
        self.title_label.bind("<Button-1>", self.start_drag)
        self.title_label.bind("<B1-Motion>", self.drag_window)

        # Кнопка закрытия
        self.close_btn = ctk.CTkButton(
            self.drag_bar, 
            text="✕", 
            width=24, 
            height=24,
            fg_color="transparent",
            hover_color="#e03e3e",
            text_color=self.text_muted,
            font=("Segoe UI", 11),
            command=self.on_closing
        )
        self.close_btn.pack(side="right", padx=6, pady=5)

        # --- Содержимое оверлея ---
        self.content_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.content_frame.pack(fill="both", expand=True, padx=15, pady=10)

        # --- Строка: OpenAll ---
        self.row_openall = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_openall.pack(fill="x", pady=4)

        self.cb_openall_var = ctk.StringVar(value="on")
        self.cb_openall = ctk.CTkCheckBox(
            self.row_openall, 
            text="Клик OpenAll", 
            variable=self.cb_openall_var, 
            onvalue="on", 
            offvalue="off",
            font=("Segoe UI", 11, "bold"),
            text_color=self.text_main,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            checkmark_color=self.accent_color,
            width=100
        )
        self.cb_openall.pack(side="left")

        self.btn_pick_openall = ctk.CTkButton(
            self.row_openall, 
            text="Захват", 
            width=50, 
            height=20,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            text_color=self.text_main,
            font=("Segoe UI", 10),
            command=lambda: self.start_capture("openall")
        )
        self.btn_pick_openall.pack(side="right")

        self.entry_y_openall = ctk.CTkEntry(self.row_openall, width=42, height=20, font=("Segoe UI", 10), fg_color="#1c1c1e", border_color="#2c2c2e")
        self.entry_y_openall.insert(0, "158")
        self.entry_y_openall.pack(side="right", padx=(2, 8))
        self.label_y_oa = ctk.CTkLabel(self.row_openall, text="Y:", font=("Segoe UI", 10), text_color=self.text_muted)
        self.label_y_oa.pack(side="right", padx=1)

        self.entry_x_openall = ctk.CTkEntry(self.row_openall, width=42, height=20, font=("Segoe UI", 10), fg_color="#1c1c1e", border_color="#2c2c2e")
        self.entry_x_openall.insert(0, "735")
        self.entry_x_openall.pack(side="right", padx=2)
        self.label_x_oa = ctk.CTkLabel(self.row_openall, text="X:", font=("Segoe UI", 10), text_color=self.text_muted)
        self.label_x_oa.pack(side="right", padx=1)

        # --- Строка: Чат ---
        self.row_chat = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_chat.pack(fill="x", pady=4)

        self.cb_chat_var = ctk.StringVar(value="on")
        self.cb_chat = ctk.CTkCheckBox(
            self.row_chat, 
            text="Клик Чат", 
            variable=self.cb_chat_var, 
            onvalue="on", 
            offvalue="off",
            font=("Segoe UI", 11, "bold"),
            text_color=self.text_main,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            checkmark_color=self.accent_color,
            width=100
        )
        self.cb_chat.pack(side="left")

        self.btn_pick_chat = ctk.CTkButton(
            self.row_chat, 
            text="Захват", 
            width=50, 
            height=20,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            text_color=self.text_main,
            font=("Segoe UI", 10),
            command=lambda: self.start_capture("chat")
        )
        self.btn_pick_chat.pack(side="right")

        self.entry_y_chat = ctk.CTkEntry(self.row_chat, width=42, height=20, font=("Segoe UI", 10), fg_color="#1c1c1e", border_color="#2c2c2e")
        self.entry_y_chat.insert(0, "351")
        self.entry_y_chat.pack(side="right", padx=(2, 8))
        self.label_y_ch = ctk.CTkLabel(self.row_chat, text="Y:", font=("Segoe UI", 10), text_color=self.text_muted)
        self.label_y_ch.pack(side="right", padx=1)

        self.entry_x_chat = ctk.CTkEntry(self.row_chat, width=42, height=20, font=("Segoe UI", 10), fg_color="#1c1c1e", border_color="#2c2c2e")
        self.entry_x_chat.insert(0, "215")
        self.entry_x_chat.pack(side="right", padx=2)
        self.label_x_ch = ctk.CTkLabel(self.row_chat, text="X:", font=("Segoe UI", 10), text_color=self.text_muted)
        self.label_x_ch.pack(side="right", padx=1)

        # --- Строка: Реконнект ---
        self.row_reconnect = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_reconnect.pack(fill="x", pady=4)

        self.cb_reconnect_var = ctk.StringVar(value="on")
        self.cb_reconnect = ctk.CTkCheckBox(
            self.row_reconnect, 
            text="Авто-Реконнект", 
            variable=self.cb_reconnect_var, 
            onvalue="on", 
            offvalue="off",
            font=("Segoe UI", 11, "bold"),
            text_color=self.text_main,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            checkmark_color=self.accent_color,
            width=120
        )
        self.cb_reconnect.pack(side="left")

        self.btn_pick_reconnect = ctk.CTkButton(
            self.row_reconnect, 
            text="Захват", 
            width=50, 
            height=20,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            text_color=self.text_main,
            font=("Segoe UI", 10),
            command=self.start_reconnect_capture
        )
        self.btn_pick_reconnect.pack(side="right")

        self.entry_reconnect_interval = ctk.CTkEntry(
            self.row_reconnect, 
            width=35, 
            height=20, 
            font=("Segoe UI", 10), 
            fg_color="#1c1c1e", 
            border_color="#2c2c2e"
        )
        self.entry_reconnect_interval.insert(0, "3.0")
        self.entry_reconnect_interval.pack(side="right", padx=(2, 6))

        self.label_rec_int = ctk.CTkLabel(
            self.row_reconnect, 
            text="Инт:", 
            font=("Segoe UI", 10), 
            text_color=self.text_muted
        )
        self.label_rec_int.pack(side="right", padx=1)

        self.label_reconnect_coords = ctk.CTkLabel(
            self.row_reconnect, 
            text="967,599 | 1138,631", 
            font=("Segoe UI", 10), 
            text_color=self.text_muted
        )
        self.label_reconnect_coords.pack(side="right", padx=10)

        # --- Строка: Настройка Команды ---
        self.row_cmd = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_cmd.pack(fill="x", pady=4)

        self.label_cmd = ctk.CTkLabel(self.row_cmd, text="Команда чата:", font=("Segoe UI", 11), text_color=self.text_main)
        self.label_cmd.pack(side="left")

        self.entry_cmd_text = ctk.CTkEntry(self.row_cmd, width=120, height=22, font=("Segoe UI", 11), fg_color="#1c1c1e", border_color="#2c2c2e")
        self.entry_cmd_text.insert(0, ";clear")
        self.entry_cmd_text.pack(side="right", padx=(0, 5))

        # --- Строка: Настройки Интервала ---
        self.row_interval = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_interval.pack(fill="x", pady=4)

        self.label_interval = ctk.CTkLabel(self.row_interval, text="Интервал (сек):", font=("Segoe UI", 11), text_color=self.text_main)
        self.label_interval.pack(side="left")

        self.entry_interval = ctk.CTkEntry(self.row_interval, width=60, height=22, font=("Segoe UI", 11), fg_color="#1c1c1e", border_color="#2c2c2e")
        self.entry_interval.insert(0, "5.0")
        self.entry_interval.pack(side="right", padx=(0, 5))

        # --- Строка чекбоксов: Фокус и Поверх окон ---
        self.row_toggles = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_toggles.pack(fill="x", pady=4)

        self.cb_focus_var = ctk.StringVar(value="on")
        self.cb_focus = ctk.CTkCheckBox(
            self.row_toggles, 
            text="Фокус Roblox", 
            variable=self.cb_focus_var, 
            onvalue="on", 
            offvalue="off",
            font=("Segoe UI", 11),
            text_color=self.text_main,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            checkmark_color=self.accent_color
        )
        self.cb_focus.pack(side="left", padx=5)

        self.cb_topmost_var = ctk.StringVar(value="on")
        self.cb_topmost = ctk.CTkCheckBox(
            self.row_toggles, 
            text="Поверх окон", 
            variable=self.cb_topmost_var, 
            onvalue="on", 
            offvalue="off",
            font=("Segoe UI", 11),
            text_color=self.text_main,
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            checkmark_color=self.accent_color,
            command=self.toggle_topmost
        )
        self.cb_topmost.pack(side="right", padx=5)

        # --- Строка кнопок управления ---
        self.row_controls = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.row_controls.pack(fill="x", pady=(10, 5))

        self.btn_start = ctk.CTkButton(
            self.row_controls, 
            text="СТАРТ", 
            font=("Segoe UI", 11, "bold"),
            fg_color=self.btn_green,
            hover_color="#248a3d",
            text_color="#ffffff",
            width=140,
            height=28,
            command=self.start_macro
        )
        self.btn_start.pack(side="left", padx=5)

        self.btn_stop = ctk.CTkButton(
            self.row_controls, 
            text="СТОП", 
            font=("Segoe UI", 11, "bold"),
            fg_color=self.btn_red,
            hover_color="#b5221b",
            text_color="#ffffff",
            width=140,
            height=28,
            command=self.stop_macro
        )
        self.btn_stop.pack(side="right", padx=5)

        # Статус
        self.status_label = ctk.CTkLabel(
            self.content_frame, 
            text="Статус: Остановлен", 
            font=("Segoe UI", 11, "bold"),
            text_color=self.text_muted
        )
        self.status_label.pack(pady=(5, 0))

        # Языковые кнопки в правом нижнем углу
        self.lang_frame = ctk.CTkFrame(self.content_frame, fg_color="transparent")
        self.lang_frame.place(relx=1.0, rely=1.0, x=0, y=0, anchor="se")

        self.btn_rus = ctk.CTkButton(
            self.lang_frame,
            text="RUS",
            width=30,
            height=18,
            font=("Segoe UI", 9, "bold"),
            fg_color=self.accent_color,
            hover_color="#2c2c2e",
            text_color="#ffffff",
            command=self.set_lang_ru
        )
        self.btn_rus.pack(side="left", padx=2)

        self.btn_eng = ctk.CTkButton(
            self.lang_frame,
            text="ENG",
            width=30,
            height=18,
            font=("Segoe UI", 9, "bold"),
            fg_color="#2c2c2e",
            hover_color="#3a3a3c",
            text_color=self.text_muted,
            command=self.set_lang_en
        )
        self.btn_eng.pack(side="left", padx=2)

        # Словарь перевода
        self.translations = {
            "ru": {
                "title": "Roblox AFK Utility",
                "cb_openall": "Клик OpenAll",
                "btn_pick": "Захват",
                "cb_chat": "Клик Чат",
                "label_cmd": "Команда чата:",
                "label_interval": "Интервал (сек):",
                "cb_focus": "Фокус Roblox",
                "cb_topmost": "Поверх окон",
                "btn_start": "СТАРТ",
                "btn_stop": "СТОП",
                "cb_reconnect": "Авто-Реконнект",
                "label_rec_int": "Инт:",
                "status_stopped": "Статус: Остановлен",
                "status_running": "Статус: Работает...",
                "status_error": "Ошибка: проверьте настройки!",
                "status_capture": "Захват: CTRL+ALT+X | Отмена: ESC",
                "status_capture_p1": "Клик 1 (Левый-Верх): CTRL+ALT+X | ESC",
                "status_captured": "захвачен:",
                "status_rec_captured": "Реконнект захвачен!",
                "status_cancel": "Выбор отменен",
                "status_fail_safe": "Прервано (Fail-Safe!)"
            },
            "en": {
                "title": "Roblox AFK Utility",
                "cb_openall": "Click OpenAll",
                "btn_pick": "Capture",
                "cb_chat": "Click Chat",
                "label_cmd": "Chat command:",
                "label_interval": "Interval (sec):",
                "cb_focus": "Focus Roblox",
                "cb_topmost": "Always on top",
                "btn_start": "START",
                "btn_stop": "STOP",
                "cb_reconnect": "Auto-Reconnect",
                "label_rec_int": "Int:",
                "status_stopped": "Status: Stopped",
                "status_running": "Status: Running...",
                "status_error": "Error: check settings!",
                "status_capture": "Capture: CTRL+ALT+X | Cancel: ESC",
                "status_capture_p1": "Click 1 (Top-Left): CTRL+ALT+X | ESC",
                "status_captured": "captured:",
                "status_rec_captured": "Reconnect captured!",
                "status_cancel": "Capture cancelled",
                "status_fail_safe": "Interrupted (Fail-Safe!)"
            }
        }
        self.current_lang = "ru"
        self.update_ui_language()

        # Навешиваем глобальные хоткеи
        keyboard.add_hotkey('f6', lambda: self.after(0, self.start_macro))
        keyboard.add_hotkey('f7', lambda: self.after(0, self.stop_macro))

        # Переменные для перетаскивания окна
        self._drag_start_x = 0
        self._drag_start_y = 0

    # --- Логика перемещения окна ---
    def start_drag(self, event):
        self._drag_start_x = event.x
        self._drag_start_y = event.y

    def drag_window(self, event):
        x = self.winfo_x() + event.x - self._drag_start_x
        y = self.winfo_y() + event.y - self._drag_start_y
        self.geometry(f"+{x}+{y}")

    def toggle_topmost(self):
        is_topmost = self.cb_topmost_var.get() == "on"
        self.attributes("-topmost", is_topmost)

    # --- Логика захвата координат ---
    def start_capture(self, target):
        if self.is_running:
            return
        
        self.capture_target = target
        t = self.translations[self.current_lang]
        self.status_label.configure(
            text=t["status_capture"], 
            text_color="#ff9f0a"
        )
        
        self.withdraw() # Скрываем окно на время выбора
        
        keyboard.add_hotkey('ctrl+alt+x', self.on_captured)
        keyboard.add_hotkey('esc', self.on_cancel_capture)

    def on_captured(self):
        x, y = pyautogui.position()
        keyboard.remove_hotkey('ctrl+alt+x')
        keyboard.remove_hotkey('esc')
        self.after(0, lambda: self.finish_capture(x, y))

    def on_cancel_capture(self):
        keyboard.remove_hotkey('ctrl+alt+x')
        keyboard.remove_hotkey('esc')
        self.after(0, lambda: self.finish_capture(None, None))

    def finish_capture(self, x, y):
        self.deiconify() # Показываем окно обратно
        t = self.translations[self.current_lang]
        if x is not None and y is not None:
            if self.capture_target == "openall":
                self.entry_x_openall.delete(0, 'end')
                self.entry_x_openall.insert(0, str(x))
                self.entry_y_openall.delete(0, 'end')
                self.entry_y_openall.insert(0, str(y))
                self.status_label.configure(text=f"OpenAll {t['status_captured']} {x}, {y}", text_color=self.btn_green)
            elif self.capture_target == "chat":
                self.entry_x_chat.delete(0, 'end')
                self.entry_x_chat.insert(0, str(x))
                self.entry_y_chat.delete(0, 'end')
                self.entry_y_chat.insert(0, str(y))
                self.status_label.configure(text=f"Чат {t['status_captured']} {x}, {y}", text_color=self.btn_green)
        else:
            self.status_label.configure(text=t["status_cancel"], text_color=self.btn_red)
        self.capture_target = None

    # --- Управление макросом ---
    def start_macro(self):
        if self.is_running:
            return
        
        params = self.get_macro_params()
        t = self.translations[self.current_lang]
        if not params:
            self.status_label.configure(text=t["status_error"], text_color="#ff9f0a")
            return
        
        self.is_running = True
        self.status_label.configure(text=t["status_running"], text_color=self.btn_green)
        self.toggle_inputs(False)
        
        self.macro_thread = threading.Thread(target=self.macro_loop, args=params, daemon=True)
        self.macro_thread.start()

    def stop_macro(self):
        if not self.is_running:
            return
        
        self.is_running = False
        t = self.translations[self.current_lang]
        self.status_label.configure(text=t["status_stopped"], text_color=self.text_muted)
        self.toggle_inputs(True)

    def handle_macro_error(self, message):
        self.is_running = False
        t = self.translations[self.current_lang]
        if "Fail-Safe" in message:
            message = t["status_fail_safe"]
        self.status_label.configure(text=message, text_color="#ff9f0a")
        self.toggle_inputs(True)

    def toggle_inputs(self, enabled):
        state = "normal" if enabled else "disabled"
        self.entry_x_openall.configure(state=state)
        self.entry_y_openall.configure(state=state)
        self.entry_x_chat.configure(state=state)
        self.entry_y_chat.configure(state=state)
        self.entry_cmd_text.configure(state=state)
        self.entry_interval.configure(state=state)
        self.cb_openall.configure(state=state)
        self.cb_chat.configure(state=state)
        self.btn_pick_openall.configure(state=state)
        self.btn_pick_chat.configure(state=state)
        self.cb_focus.configure(state=state)
        self.cb_reconnect.configure(state=state)
        self.btn_pick_reconnect.configure(state=state)
        self.entry_reconnect_interval.configure(state=state)

    def get_macro_params(self):
        try:
            oa_active = self.cb_openall_var.get() == "on"
            chat_active = self.cb_chat_var.get() == "on"
            focus_active = self.cb_focus_var.get() == "on"
            reconnect_active = self.cb_reconnect_var.get() == "on"
            
            x_oa = int(self.entry_x_openall.get()) if oa_active else None
            y_oa = int(self.entry_y_openall.get()) if oa_active else None
            
            x_chat = int(self.entry_x_chat.get()) if chat_active else None
            y_chat = int(self.entry_y_chat.get()) if chat_active else None
            
            cmd_text = self.entry_cmd_text.get()
            interval = float(self.entry_interval.get())
            rec_interval = float(self.entry_reconnect_interval.get())
            
            if interval <= 0.1:
                interval = 0.1
            if rec_interval <= 0.1:
                rec_interval = 0.1
                
            return (oa_active, x_oa, y_oa, chat_active, x_chat, y_chat, cmd_text, interval, focus_active, reconnect_active, rec_interval)
        except ValueError:
            return None

    def update_ui_language(self):
        lang = self.current_lang
        t = self.translations[lang]
        
        self.title_label.configure(text=t["title"])
        self.cb_openall.configure(text=t["cb_openall"])
        self.btn_pick_openall.configure(text=t["btn_pick"])
        self.cb_chat.configure(text=t["cb_chat"])
        self.btn_pick_chat.configure(text=t["btn_pick"])
        self.label_cmd.configure(text=t["label_cmd"])
        self.label_interval.configure(text=t["label_interval"])
        self.cb_focus.configure(text=t["cb_focus"])
        self.cb_topmost.configure(text=t["cb_topmost"])
        self.btn_start.configure(text=t["btn_start"])
        self.btn_stop.configure(text=t["btn_stop"])
        self.cb_reconnect.configure(text=t["cb_reconnect"])
        self.btn_pick_reconnect.configure(text=t["btn_pick"])
        self.label_rec_int.configure(text=t["label_rec_int"])
        
        if not self.is_running:
            if "Остановлен" in self.status_label.cget("text") or "Stopped" in self.status_label.cget("text"):
                self.status_label.configure(text=t["status_stopped"])
        else:
            if "Работает" in self.status_label.cget("text") or "Running" in self.status_label.cget("text"):
                self.status_label.configure(text=t["status_running"])

        if lang == "ru":
            self.btn_rus.configure(fg_color=self.accent_color, text_color="#ffffff")
            self.btn_eng.configure(fg_color="#2c2c2e", text_color=self.text_muted)
        else:
            self.btn_rus.configure(fg_color="#2c2c2e", text_color=self.text_muted)
            self.btn_eng.configure(fg_color=self.accent_color, text_color="#ffffff")

    def set_lang_ru(self):
        self.current_lang = "ru"
        self.update_ui_language()

    def set_lang_en(self):
        self.current_lang = "en"
        self.update_ui_language()

    def interruptible_sleep(self, duration):
        start_sleep = time.time()
        while self.is_running and (time.time() - start_sleep) < duration:
            time.sleep(0.1)

    def sleep_and_check_reconnect(self, duration, rec_interval, reconnect_active):
        start_time = time.time()
        last_rec_check = 0.0
        
        while self.is_running and (time.time() - start_time) < duration:
            current_time = time.time()
            # Проверяем реконнект каждые rec_interval секунд
            if reconnect_active and (current_time - last_rec_check) >= rec_interval:
                if self.is_reconnect_button_present():
                    x_center = (self.reconnect_x1 + self.reconnect_x2) // 2
                    y_center = (self.reconnect_y1 + self.reconnect_y2) // 2
                    self.lerp_move(x_center, y_center)
                    time.sleep(0.1)
                    self.direct_click()
                    # После нажатия ждем пока игра перезагрузится
                    self.interruptible_sleep(15.0)
                    return True # Сигнализируем, что был реконнект
                last_rec_check = current_time
            time.sleep(0.1)
        return False

    def is_reconnect_button_present(self):
        try:
            x_left = self.reconnect_x1 + int((self.reconnect_x2 - self.reconnect_x1) * 0.15)
            x_right = self.reconnect_x1 + int((self.reconnect_x2 - self.reconnect_x1) * 0.85)
            y_mid = (self.reconnect_y1 + self.reconnect_y2) // 2
            
            p_left = pyautogui.pixel(x_left, y_mid)
            p_right = pyautogui.pixel(x_right, y_mid)
            
            # Проверяем, что оба пикселя белые (RGB > 220)
            is_left_white = p_left[0] > 220 and p_left[1] > 220 and p_left[2] > 220
            is_right_white = p_right[0] > 220 and p_right[1] > 220 and p_right[2] > 220
            
            return is_left_white and is_right_white
        except Exception as e:
            print(f"Ошибка при проверке кнопки реконнекта: {e}")
            return False

    def start_reconnect_capture(self):
        if self.is_running:
            return
        
        self.capture_target = "reconnect_p1"
        t = self.translations[self.current_lang]
        self.status_label.configure(
            text=t["status_capture_p1"], 
            text_color="#ff9f0a"
        )
        
        self.withdraw()
        
        keyboard.add_hotkey('ctrl+alt+x', self.on_reconnect_captured)
        keyboard.add_hotkey('esc', self.on_cancel_reconnect_capture)

    def on_reconnect_captured(self):
        x, y = pyautogui.position()
        keyboard.remove_hotkey('ctrl+alt+x')
        keyboard.remove_hotkey('esc')
        
        try:
            win32api.MessageBeep(win32con.MB_OK)
        except Exception:
            pass
            
        if self.capture_target == "reconnect_p1":
            self.temp_x1, self.temp_y1 = x, y
            self.capture_target = "reconnect_p2"
            self.after(0, self.prompt_capture_p2)
        elif self.capture_target == "reconnect_p2":
            x2, y2 = x, y
            self.after(0, lambda: self.finish_reconnect_capture(self.temp_x1, self.temp_y1, x2, y2))

    def prompt_capture_p2(self):
        keyboard.add_hotkey('ctrl+alt+x', self.on_reconnect_captured)
        keyboard.add_hotkey('esc', self.on_cancel_reconnect_capture)

    def on_cancel_reconnect_capture(self):
        keyboard.remove_hotkey('ctrl+alt+x')
        keyboard.remove_hotkey('esc')
        self.after(0, lambda: self.finish_reconnect_capture(None, None, None, None))

    def finish_reconnect_capture(self, x1, y1, x2, y2):
        self.deiconify()
        t = self.translations[self.current_lang]
        if x1 is not None and y1 is not None and x2 is not None and y2 is not None:
            self.reconnect_x1 = min(x1, x2)
            self.reconnect_y1 = min(y1, y2)
            self.reconnect_x2 = max(x1, x2)
            self.reconnect_y2 = max(y1, y2)
            
            self.label_reconnect_coords.configure(
                text=f"{self.reconnect_x1},{self.reconnect_y1} | {self.reconnect_x2},{self.reconnect_y2}"
            )
            self.status_label.configure(
                text=t["status_rec_captured"], 
                text_color=self.btn_green
            )
        else:
            self.status_label.configure(text=t["status_cancel"], text_color=self.btn_red)
        self.capture_target = None

    # --- Метод фокусировки Roblox ---
    def focus_roblox_window(self):
        try:
            import pygetwindow as gw
            windows = gw.getAllWindows()
            for w in windows:
                if 'roblox' in w.title.lower() and 'overlay' not in w.title.lower():
                    if w.isMinimized:
                        w.restore()
                    try:
                        w.activate()
                    except Exception:
                        pass
                    return True
        except Exception as e:
            print(f"Ошибка при поиске/активации Roblox: {e}")
        return False

    # --- Методы перемещения мыши DirectInput (из sl_auto_lemons.py) ---
    def sync_directinput(self):
        """Принудительно заставляет движок DirectInput зарегистрировать новые аппаратные координаты"""
        try:
            win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 0, 0, 0)
            time.sleep(0.002)
            win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, 0, 0, 0)
            time.sleep(0.002)
        except Exception as e:
            print(f"Ошибка sync_directinput: {e}")

    def lerp_move(self, target_x, target_y):
        """Плавное перемещение мыши с использованием линейной интерполяции (LERP)"""
        smooth_speed = 0.22         # Скорость сглаживания из sl_auto_lemons.py
        min_distance_step = 2       # Минимальный порог расстояния
        try:
            while self.is_running:
                curr_x, curr_y = win32api.GetCursorPos()
                dx = target_x - curr_x
                dy = target_y - curr_y
                distance = np.sqrt(dx**2 + dy**2)
                
                if distance < min_distance_step:
                    win32api.SetCursorPos((target_x, target_y))
                    self.sync_directinput()
                    break
                    
                next_x = curr_x + int(dx * smooth_speed)
                next_y = curr_y + int(dy * smooth_speed)
                
                if next_x == curr_x and dx != 0: next_x += 1 if dx > 0 else -1
                if next_y == curr_y and dy != 0: next_y += 1 if dy > 0 else -1
                    
                win32api.SetCursorPos((next_x, next_y))
                time.sleep(0.003)
        except Exception as e:
            print(f"Ошибка lerp_move: {e}")

    def direct_click(self):
        """Имитирует DirectInput нажатие с легким смещением курсора для 100% срабатывания в играх"""
        try:
            win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
            time.sleep(0.03)
            
            # Легкое движение, чтобы игра гарантированно зафиксировала клик
            win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
            time.sleep(0.02)
            win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
            time.sleep(0.02)
            
            win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
            time.sleep(0.03)
        except Exception as e:
            print(f"Ошибка direct_click: {e}")

    # --- Цикл макроса ---
    def macro_loop(self, oa_active, x_oa, y_oa, chat_active, x_chat, y_chat, cmd_text, interval, focus_active, reconnect_active, rec_interval):
        time.sleep(1.5)
        
        while self.is_running:
            try:
                # 0. Авто-фокусировка Roblox
                if focus_active:
                    self.focus_roblox_window()
                    time.sleep(0.3)

                # Проверка и нажатие Reconnect перед основными действиями
                if reconnect_active and self.is_running:
                    if self.is_reconnect_button_present():
                        x_center = (self.reconnect_x1 + self.reconnect_x2) // 2
                        y_center = (self.reconnect_y1 + self.reconnect_y2) // 2
                        self.lerp_move(x_center, y_center)
                        time.sleep(0.1)
                        self.direct_click()
                        # Ждем пока игра перезагрузится
                        self.interruptible_sleep(15.0)
                        continue

                # 1. Клик по кнопке OpenAll
                if oa_active and self.is_running:
                    self.lerp_move(x_oa, y_oa)
                    time.sleep(0.1)
                    self.direct_click()
                    time.sleep(0.5)

                # 2. Клик по Чату и ввод команды
                if chat_active and self.is_running:
                    self.lerp_move(x_chat, y_chat)
                    time.sleep(0.1)
                    self.direct_click()
                    time.sleep(0.3)
                    
                    # Используем буфер обмена для защиты от смены раскладки (RU/EN) и потери символов
                    pyperclip.copy(cmd_text)
                    time.sleep(0.05)
                    keyboard.send('ctrl+v')
                    time.sleep(0.2)
                    
                    keyboard.send('enter')
                    time.sleep(0.5)
            except pyautogui.FailSafeException:
                self.after(0, lambda: self.handle_macro_error("Прервано (Fail-Safe!)"))
                break
            except Exception as e:
                print(f"Временный сбой макроса: {e}")
                time.sleep(1.0)
                
            # Сон между циклами с периодической проверкой реконнекта
            reconnected = self.sleep_and_check_reconnect(interval, rec_interval, reconnect_active)
            if reconnected:
                continue

    def on_closing(self):
        self.is_running = False
        keyboard.unhook_all()
        self.destroy()
        sys.exit()

if __name__ == "__main__":
    app = RobloxAFKOverlay()
    app.mainloop()
