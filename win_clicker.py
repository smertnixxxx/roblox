import ctypes
import time
import threading
import tkinter as tk

# Try to make process DPI aware to avoid coordinate scaling issues on high-DPI screens
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2) # PROCESS_PER_MONITOR_DPI_AWARE
except:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except:
        pass

# Windows API Constants
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
VK_F8 = 0x77   # F8 key to lock detector position
VK_F9 = 0x78   # F9 key to reset to auto mode
VK_F10 = 0x79  # F10 to pause/resume
VK_ESC = 0x1B  # ESC to exit

class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long)
    ]

class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]

# Global State Dictionary for Thread Communication
bot_state = {
    "enabled": True,
    "armed": True,
    "status_text": "ИНИЦИАЛИЗАЦИЯ...",
    "status_color": "#ff9100",  # Orange
    "running": True,
    "last_rgb": (0, 0, 0),
    "detector_pos": None  # Coordinates to monitor if manually locked
}

def get_mouse_pos():
    pt = POINT()
    ctypes.windll.user32.GetCursorPos(ctypes.byref(pt))
    return pt.x, pt.y

def get_pixel_color(x, y):
    hdc = ctypes.windll.user32.GetDC(0)
    color = ctypes.windll.gdi32.GetPixel(hdc, x, y)
    ctypes.windll.user32.ReleaseDC(0, hdc)
    r = color & 0xff
    g = (color >> 8) & 0xff
    b = (color >> 16) & 0xff
    return r, g, b

def click_at(x, y):
    # To prevent DPI scaling issues and cursor jumping, we simulate a click 
    # directly at the current mouse position (since you keep it on the button).
    ctypes.windll.user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.001)  # 1ms hold time (fastest possible)
    ctypes.windll.user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)

def is_key_pressed(vk):
    return (ctypes.windll.user32.GetAsyncKeyState(vk) & 0x8000) != 0

def find_roblox_window():
    hwnd = ctypes.windll.user32.FindWindowW(None, "Roblox")
    if hwnd:
        return hwnd
    
    hwnd_holder = []
    def enum_windows_callback(h, lParam):
        length = ctypes.windll.user32.GetWindowTextLengthW(h)
        if length > 0:
            buffer = ctypes.create_unicode_buffer(length + 1)
            ctypes.windll.user32.GetWindowTextW(h, buffer, length + 1)
            if "Roblox" in buffer.value:
                hwnd_holder.append(h)
                return False
        return True
    
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    ctypes.windll.user32.EnumWindows(WNDENUMPROC(enum_windows_callback), 0)
    return hwnd_holder[0] if hwnd_holder else None

def is_green(r, g, b):
    return g > 130 and g > r + 50 and g > b + 50

def check_green_around(hdc, cx, cy, width, height):
    # Determine a safe offset that is small enough to stay within the monitor screen
    # e.g., 20 pixels or 2% of the width, whichever is smaller, but at least 10 pixels.
    offset_x = max(10, min(30, int(width * 0.02)))
    offset_y = max(10, min(30, int(height * 0.02)))
    
    # 5 test points: Center, Top-Left, Top-Right, Bottom-Left, Bottom-Right
    # This ensures that even if text is at the center, we will hit the green background on the sides
    points = [
        (cx - offset_x, cy - offset_y),
        (cx + offset_x, cy - offset_y),
        (cx - offset_x, cy + offset_y),
        (cx + offset_x, cy + offset_y),
        (cx, cy - offset_y)
    ]
    
    # Check each point
    for x, y in points:
        color = ctypes.windll.gdi32.GetPixel(hdc, x, y)
        r = color & 0xff
        g = (color >> 8) & 0xff
        b = (color >> 16) & 0xff
        if is_green(r, g, b):
            return True, (r, g, b)
            
    # If not green, return False and the color at the first point
    color = ctypes.windll.gdi32.GetPixel(hdc, points[0][0], points[0][1])
    r = color & 0xff
    g = (color >> 8) & 0xff
    b = (color >> 16) & 0xff
    return False, (r, g, b)

# Background Worker Thread for fast pixel monitoring
def bot_worker():
    last_f10 = False
    last_f8 = False
    last_f9 = False
    last_rect_update = 0.0
    rect = RECT()
    width, height, cx, cy = 0, 0, 0, 0
    
    while bot_state["running"]:
        # Check ESC key for exit
        if is_key_pressed(VK_ESC):
            bot_state["running"] = False
            break

        # Check pause/resume hotkey
        f10_pressed = is_key_pressed(VK_F10)
        if f10_pressed and not last_f10:
            bot_state["enabled"] = not bot_state["enabled"]
            bot_state["armed"] = True
        last_f10 = f10_pressed

        if not bot_state["enabled"]:
            bot_state["status_text"] = "ПАУЗА [F10]"
            bot_state["status_color"] = "#ff1744"  # Neon Red
            time.sleep(0.05)
            continue

        # Handle F8 (Lock detector position to current mouse position)
        f8_pressed = is_key_pressed(VK_F8)
        if f8_pressed and not last_f8:
            mx, my = get_mouse_pos()
            bot_state["detector_pos"] = (mx, my)
            bot_state["status_text"] = "ДЕТЕКТОР ЗАДАН!"
            bot_state["status_color"] = "#00b0ff"  # Electric Blue
            bot_state["armed"] = True
            time.sleep(0.1)  # Debounce
        last_f8 = f8_pressed

        # Handle F9 (Reset to Auto-Center mode)
        f9_pressed = is_key_pressed(VK_F9)
        if f9_pressed and not last_f9:
            bot_state["detector_pos"] = None
            bot_state["status_text"] = "РЕЖИМ: АВТО-ЦЕНТР"
            bot_state["status_color"] = "#ff9100"  # Orange
            bot_state["armed"] = True
            time.sleep(0.1)  # Debounce
        last_f9 = f9_pressed

        # Get window info
        hwnd = find_roblox_window()
        if not hwnd:
            bot_state["status_text"] = "ЗАПУСТИТЕ ROBLOX"
            bot_state["status_color"] = "#ff9100"  # Orange
            time.sleep(0.2)
            continue

        # Check if active
        active_hwnd = ctypes.windll.user32.GetForegroundWindow()
        if active_hwnd != hwnd:
            bot_state["status_text"] = "ROBLOX НА ЗАДНЕМ ПЛАНЕ"
            bot_state["status_color"] = "#757575"  # Grey
            time.sleep(0.1)
            continue

        # Check for green color
        if bot_state["detector_pos"] is not None:
            # MANUAL MODE: Check only the specific locked pixel coordinate
            dx, dy = bot_state["detector_pos"]
            hdc = ctypes.windll.user32.GetDC(0)
            color = ctypes.windll.gdi32.GetPixel(hdc, dx, dy)
            ctypes.windll.user32.ReleaseDC(0, hdc)
            r = color & 0xff
            g = (color >> 8) & 0xff
            b = (color >> 16) & 0xff
            is_screen_green = is_green(r, g, b)
            last_rgb = (r, g, b)
        else:
            # AUTO MODE: Check 5 points around the window center
            current_time = time.time()
            if current_time - last_rect_update > 0.5:
                ctypes.windll.user32.GetWindowRect(hwnd, ctypes.byref(rect))
                width = rect.right - rect.left
                height = rect.bottom - rect.top
                cx = rect.left + width // 2
                cy = rect.top + height // 2
                last_rect_update = current_time

            hdc = ctypes.windll.user32.GetDC(0)
            is_screen_green, last_rgb = check_green_around(hdc, cx, cy, width, height)
            ctypes.windll.user32.ReleaseDC(0, hdc)
            
        bot_state["last_rgb"] = last_rgb

        if bot_state["armed"]:
            if bot_state["detector_pos"] is not None:
                bot_state["status_text"] = "ТОЧКА ЗАДАНА: ЖДУ"
                bot_state["status_color"] = "#00e676"  # Green
            else:
                bot_state["status_text"] = "АВТО-РЕЖИМ: ЖДУ"
                bot_state["status_color"] = "#00e676"  # Green
            
            if is_screen_green:
                mx, my = get_mouse_pos()
                click_at(mx, my)
                bot_state["armed"] = False
                bot_state["status_text"] = "КЛИКНУЛ!"
                bot_state["status_color"] = "#29b6f6"  # Blue
                time.sleep(0.5)  # Cooldown
        else:
            bot_state["status_text"] = "СБРОС ДЛЯ СЛЕД. РАУНДА"
            bot_state["status_color"] = "#29b6f6"  # Blue
            if not is_screen_green:
                bot_state["armed"] = True

        time.sleep(0.001)  # 1ms high-speed loop (extremely accurate with timeBeginPeriod)

# GUI Setup
class OverlayApp:
    def __init__(self, root):
        self.root = root
        
        # Borderless, always-on-top, and semi-transparent
        root.overrideredirect(True)
        root.attributes("-topmost", True)
        root.attributes("-alpha", 0.90)  # Sleek translucency
        
        # Dark Modern Design
        root.config(bg="#18181c")
        
        # Geometry: 280 width, 45 height, positioned top-middle of the screen
        screen_width = root.winfo_screenwidth()
        w = 280
        h = 45
        x = (screen_width // 2) - (w // 2)
        y = 10
        root.geometry(f"{w}x{h}+{x}+{y}")

        # Drag event bindings (allows user to drag the overlay anywhere)
        self.drag_data = {"x": 0, "y": 0}
        root.bind("<Button-1>", self.start_drag)
        root.bind("<B1-Motion>", self.drag)

        # Title Label
        self.title_label = tk.Label(
            root, 
            text="ROBLOX AUTO-CLICKER", 
            fg="#8e8e93", 
            bg="#18181c", 
            font=("Segoe UI", 7, "bold")
        )
        self.title_label.place(x=10, y=4)

        # Status Text Label
        self.status_label = tk.Label(
            root, 
            text="ИНИЦИАЛИЗАЦИЯ...", 
            fg="#ff9100", 
            bg="#18181c", 
            font=("Segoe UI", 9, "bold")
        )
        self.status_label.place(x=10, y=20)

        # Hotkey Info Label
        self.info_label = tk.Label(
            root, 
            text="[F8] Задать | [F9] Авто", 
            fg="#636366", 
            bg="#18181c", 
            font=("Segoe UI", 7)
        )
        self.info_label.place(x=135, y=4)

        # RGB Color Display Label
        self.rgb_label = tk.Label(
            root, 
            text="RGB: (---, ---, ---)", 
            fg="#8e8e93", 
            bg="#18181c", 
            font=("Segoe UI", 8, "bold")
        )
        self.rgb_label.place(x=150, y=20)

        # Close Button (✕)
        self.close_btn = tk.Label(
            root, 
            text="✕", 
            fg="#8e8e93", 
            bg="#18181c", 
            cursor="hand2", 
            font=("Segoe UI", 10, "bold")
        )
        self.close_btn.place(x=260, y=10)
        self.close_btn.bind("<Button-1>", self.exit_app)
        self.close_btn.bind("<Enter>", lambda e: self.close_btn.config(fg="#ff1744"))
        self.close_btn.bind("<Leave>", lambda e: self.close_btn.config(fg="#8e8e93"))

        # Visual Neon Line at the bottom representing status
        self.neon_bar = tk.Frame(root, height=4, bg="#ff9100")
        self.neon_bar.pack(side="bottom", fill="x")

        # Periodically update the GUI based on background thread state
        self.update_gui()

    def start_drag(self, event):
        self.drag_data["x"] = event.x
        self.drag_data["y"] = event.y

    def drag(self, event):
        dx = event.x - self.drag_data["x"]
        dy = event.y - self.drag_data["y"]
        x = self.root.winfo_x() + dx
        y = self.root.winfo_y() + dy
        self.root.geometry(f"+{x}+{y}")

    def exit_app(self, event=None):
        bot_state["running"] = False
        self.root.destroy()

    def update_gui(self):
        # If the background thread requested termination
        if not bot_state["running"]:
            self.root.destroy()
            return
            
        color = bot_state["status_color"]
        text = bot_state["status_text"]
        rgb = bot_state["last_rgb"]
        
        self.status_label.config(text=text, fg=color)
        self.rgb_label.config(text=f"RGB: ({rgb[0]}, {rgb[1]}, {rgb[2]})", fg=color)
        self.neon_bar.config(bg=color)
        
        # Schedule next update in 50ms (responsive, low overhead)
        self.root.after(50, self.update_gui)

def main():
    # Set Windows timer resolution to 1ms for ultra-fast sleeps
    try:
        ctypes.windll.winmm.timeBeginPeriod(1)
    except:
        pass

    # Start the clicker loop in a daemon thread
    thread = threading.Thread(target=bot_worker, daemon=True)
    thread.start()

    # Start the Tkinter Overlay App
    root = tk.Tk()
    app = OverlayApp(root)
    root.mainloop()

    # Restore default Windows timer resolution on exit
    try:
        ctypes.windll.winmm.timeEndPeriod(1)
    except:
        pass

if __name__ == "__main__":
    main()
