import pyautogui
import cv2
import numpy as np
import time
import keyboard
import win32api
import win32con
import tkinter as tk
from tkinter import ttk
import threading

# --- GLOBAL CONFIGURATION (ADJUSTABLE VIA MENU) ---
FOV_RADIUS = 160            # Radius of the FOV circle around the mouse
DELAY_BETWEEN_FRUITS = 0.5  # Delay between collections (in seconds)
MIN_FRUIT_AREA = 100        # Minimum object size (filters out leaves)
SMOOTH_SPEED = 0.22         # Mouse movement smoothness (LERP)

MIN_DISTANCE_STEP = 2       
LOWER_YELLOW = np.array([20, 130, 130])
UPPER_YELLOW = np.array([32, 255, 255])

# YOUR RECORDED MOUSE PATTERN
RAW_PATTERN = [
    (892, 510), (891, 510), (890, 510), (890, 509), (889, 509), (889, 508), (889, 507), 
    (888, 507), (887, 506), (886, 506), (885, 505), (886, 505), (887, 505), (889, 505)
]
base_x, base_y = RAW_PATTERN[0]
OFFSETS = [(x - base_x, y - base_y) for x, y in RAW_PATTERN]

running = True

def sync_directinput():
    """Forces DirectInput engine to register the new mouse hardware position"""
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 0, 0, 0)
    time.sleep(0.002)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, 0, 0, 0)
    time.sleep(0.002)

def lerp_move(target_x, target_y):
    """Smoothly moves the mouse to the target using Linear Interpolation"""
    while True:
        curr_x, curr_y = win32api.GetCursorPos()
        dx = target_x - curr_x
        dy = target_y - curr_y
        distance = np.sqrt(dx**2 + dy**2)
        
        if distance < MIN_DISTANCE_STEP:
            win32api.SetCursorPos((target_x, target_y))
            sync_directinput()
            break
            
        next_x = curr_x + int(dx * SMOOTH_SPEED)
        next_y = curr_y + int(dy * SMOOTH_SPEED)
        
        if next_x == curr_x and dx != 0: next_x += 1 if dx > 0 else -1
        if next_y == curr_y and dy != 0: next_y += 1 if dy > 0 else -1
            
        win32api.SetCursorPos((next_x, next_y))
        time.sleep(0.003)

def execute_smooth_action(target_x, target_y):
    """Moves to the edge point, plays recorded shake, and triggers the click"""
    start_mouse_x, start_mouse_y = win32api.GetCursorPos()
    
    lerp_move(target_x, target_y)
    
    for ox, oy in OFFSETS:
        win32api.SetCursorPos((target_x + ox, target_y + oy))
        time.sleep(0.002)
    
    sync_directinput()
        
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.03)
    
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, 1, 0, 0)
    time.sleep(0.02)
    win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, -1, -1, 0, 0)
    time.sleep(0.02)
    
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.03)
    
    lerp_move(start_mouse_x, start_mouse_y)
    sync_directinput()

def bot_loop():
    """Main screen scanning loop"""
    global running
    print("Bot engine active! Use the dashboard to configure settings.")
    
    while running:
        if keyboard.is_pressed('delete'):
            running = False
            break

        mouse_x, mouse_y = win32api.GetCursorPos()
        screen_width, screen_height = pyautogui.size()

        left = mouse_x - FOV_RADIUS
        top = mouse_y - FOV_RADIUS
        
        if left < 0: left = 0
        if top < 0: top = 0
        if left + FOV_RADIUS * 2 > screen_width: left = screen_width - FOV_RADIUS * 2
        if top + FOV_RADIUS * 2 > screen_height: top = screen_height - FOV_RADIUS * 2

        win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 0, 0, 0, 0)

        screenshot = pyautogui.screenshot(region=(left, top, FOV_RADIUS * 2, FOV_RADIUS * 2))
        frame = np.array(screenshot)
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        mask = cv2.inRange(hsv, LOWER_YELLOW, UPPER_YELLOW)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if contours:
            best_fruit_coords = None
            max_area = 0

            for contour in contours:
                area = cv2.contourArea(contour)
                if area > MIN_FRUIT_AREA:
                    min_contour_dist = float('inf')
                    closest_pt_on_fruit = None
                    
                    for pt in contour:
                        pt_x = pt[0][0] + left
                        pt_y = pt[0][1] + top
                        d_squared = (pt_x - mouse_x)**2 + (pt_y - mouse_y)**2
                        if d_squared < min_contour_dist:
                            min_contour_dist = d_squared
                            closest_pt_on_fruit = (pt_x, pt_y)
                    
                    if closest_pt_on_fruit:
                        dist_to_fov = np.sqrt(min_contour_dist)
                        if dist_to_fov <= FOV_RADIUS:
                            if area > max_area:
                                max_area = area
                                best_fruit_coords = closest_pt_on_fruit

            if best_fruit_coords:
                execute_smooth_action(best_fruit_coords[0], best_fruit_coords[1])
                time.sleep(DELAY_BETWEEN_FRUITS)
                            
        time.sleep(0.02)

# Start bot thread
bot_thread = threading.Thread(target=bot_loop, daemon=True)
bot_thread.start()


# --- GUI INITIALIZATION (Tkinter) ---
root = tk.Tk()
screen_width, screen_height = pyautogui.size()

# 1. Clear Transparent FOV Overlay
root.geometry(f"{screen_width}x{screen_height}+0+0")
root.overrideredirect(True)
root.wm_attributes("-topmost", True)
root.wm_attributes("-disabled", True)
root.wm_attributes("-transparentcolor", "black")

canvas = tk.Canvas(root, width=screen_width, height=screen_height, bg="black", highlightthickness=0)
canvas.pack()
fov_circle = canvas.create_oval(0, 0, 0, 0, outline="green", width=1)


# 2. Minimalist Control Panel (Standard Windows/Office Style)
menu = tk.Toplevel(root)
menu.title("Fruit Collector Dashboard")
menu.geometry("360x420+60+60") 
menu.attributes("-topmost", True) 
menu.resizable(False, False)

# Real-time config updates
def on_fov_change(val):
    global FOV_RADIUS
    FOV_RADIUS = int(float(val))
    lbl_fov.config(text=f"FOV Radius: {FOV_RADIUS} px")

def on_delay_change(val):
    global DELAY_BETWEEN_FRUITS
    DELAY_BETWEEN_FRUITS = round(float(val), 2)
    lbl_delay.config(text=f"Click Delay: {DELAY_BETWEEN_FRUITS} s")

def on_area_change(val):
    global MIN_FRUIT_AREA
    MIN_FRUIT_AREA = int(float(val))
    lbl_area.config(text=f"Min Object Size: {MIN_FRUIT_AREA} px")

def on_speed_change(val):
    global SMOOTH_SPEED
    SMOOTH_SPEED = round(float(val), 2)
    lbl_speed.config(text=f"Mouse Smoothness (LERP): {SMOOTH_SPEED}")

# Clean native layout styling
style = ttk.Style()
style.theme_use('alt') # Standard clean system style

main_frame = ttk.Frame(menu, padding=15)
main_frame.pack(fill=tk.BOTH, expand=True)

# Main Title Label
ttk.Label(main_frame, text="COLLECTOR UTILITY PANEL", font=("Segoe UI", 11, "bold")).pack(pady=(0, 5))

# --- SECTION 1: TARGETING ---
group_target = ttk.LabelFrame(main_frame, text=" Targeting Settings ", padding=10)
group_target.pack(fill="x", pady=5)

lbl_fov = ttk.Label(group_target, text=f"FOV Radius: {FOV_RADIUS} px", font=("Segoe UI", 9))
lbl_fov.pack(anchor="w")
scale_fov = ttk.Scale(group_target, from_=50, to=350, value=FOV_RADIUS, command=on_fov_change)
scale_fov.pack(fill="x", pady=(2, 8))

lbl_area = ttk.Label(group_target, text=f"Min Object Size: {MIN_FRUIT_AREA} px", font=("Segoe UI", 9))
lbl_area.pack(anchor="w")
scale_area = ttk.Scale(group_target, from_=20, to=400, value=MIN_FRUIT_AREA, command=on_area_change)
scale_area.pack(fill="x", pady=(2, 2))

# --- SECTION 2: MOUSE & TIMING ---
group_mouse = ttk.LabelFrame(main_frame, text=" Mouse & Timing Settings ", padding=10)
group_mouse.pack(fill="x", pady=5)

lbl_speed = ttk.Label(group_mouse, text=f"Mouse Smoothness (LERP): {SMOOTH_SPEED}", font=("Segoe UI", 9))
lbl_speed.pack(anchor="w")
scale_speed = ttk.Scale(group_mouse, from_=0.05, to=0.6, value=SMOOTH_SPEED, command=on_speed_change)
scale_speed.pack(fill="x", pady=(2, 8))

lbl_delay = ttk.Label(group_mouse, text=f"Click Delay: {DELAY_BETWEEN_FRUITS} s", font=("Segoe UI", 9))
lbl_delay.pack(anchor="w")
scale_delay = ttk.Scale(group_mouse, from_=0.1, to=2.0, value=DELAY_BETWEEN_FRUITS, command=on_delay_change)
scale_delay.pack(fill="x", pady=(2, 2))

# Footer Information (Font size 8.5 changed to integer 9)
ttk.Label(main_frame, text="Press 'DELETE' key anytime to terminate the script safely.", 
          font=("Segoe UI", 9, "italic"), foreground="dimgray").pack(pady=(15, 0))

# Continuous overlay synchronization loop
def update_overlay():
    global running
    if keyboard.is_pressed('delete') or not running or not menu.winfo_exists():
        running = False
        root.destroy()
        return

    mx, my = win32api.GetCursorPos()
    canvas.coords(fov_circle, mx - FOV_RADIUS, my - FOV_RADIUS, mx + FOV_RADIUS, my + FOV_RADIUS)
    root.after(15, update_overlay)

root.after(15, update_overlay)
root.mainloop()