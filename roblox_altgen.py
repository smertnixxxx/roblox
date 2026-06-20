import os
import json
import random
import string
import time
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

# Словарь геймерских ников
WORDS_1 = [
    "Dark", "Neon", "Epic", "Cyber", "Shadow", "Ghost", "Alpha", "Cosmic", "Quantum", "Astral", 
    "Frost", "Blaze", "Vortex", "Mystic", "Urban", "Retro", "Solar", "Lunar", "Sonic", "Omega", 
    "Toxic", "Savage", "Silent", "Hidden", "Hyper", "Turbo", "Giga", "Thunder", "Storm", "Viper", 
    "Cobra", "Rogue", "Fallen", "Primal", "Furious", "Liquid", "Crystal", "Phantom", "Pixel", "Apex"
]
WORDS_2 = [
    "Wolf", "Bear", "Fox", "Hawk", "Bot", "Cube", "Zone", "Clan", "King", "Hero", 
    "Star", "Wave", "Lion", "Tiger", "Gale", "Crew", "Host", "Knight", "Beast", "Hunter", 
    "Phoenix", "Dragon", "Titan", "Wraith", "Blade", "Edge", "Nexus", "Core", "Shard", "Pulse", 
    "Drive", "Vector", "Matrix", "Nomad", "Ranger", "Scout", "Slayer", "Lord", "Fiend", "Demon"
]

def generate_human_username():
    w1 = random.choice(WORDS_1)
    w2 = random.choice(WORDS_2)
    digits = "".join(random.choice(string.digits) for _ in range(3))
    return f"{w1}{w2}{digits}"

def save_to_desktop_json(account_data):
    desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")
    json_file_path = os.path.join(desktop_path, "roblox_alts.json")
    
    existing_accounts = []
    if os.path.exists(json_file_path):
        try:
            with open(json_file_path, "r", encoding="utf-8") as f:
                existing_accounts = json.load(f)
        except Exception:
            existing_accounts = []
            
    existing_accounts.append(account_data)
    
    # ТУТ БЫЛ БАГ: добавил пропущенную букву f (указатель на файл)
    with open(json_file_path, "w", encoding="utf-8") as f:
        json.dump(existing_accounts, f, indent=4, ensure_ascii=False)
    print(f"[*] Данные записаны в roblox_alts.json на Рабочем столе.")

def create_one_account(p, custom_password):
    browser = p.chromium.launch(
        headless=False, 
        slow_mo=100,
        ignore_default_args=["--enable-automation"],
        args=["--disable-blink-features=AutomationControlled"]
    )
    
    context = browser.new_context(
        viewport={'width': 1366, 'height': 768},
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    )
    
    context.add_init_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    
    page = context.new_page()
    success = False
    final_username = ""
    final_password = custom_password

    try:
        print("[*] Загрузка сайта Roblox...")
        page.goto("https://www.roblox.com/")
        time.sleep(3)

        # Проверка на уже вошедший аккаунт
        if "home" in page.url.lower():
            print("[!] Обнаружен активный аккаунт! Выходим...")
            page.goto("https://www.roblox.com/logout")
            time.sleep(3)
            page.goto("https://www.roblox.com/")
            time.sleep(2)

        if "login" in page.url.lower():
            signup_nav = page.locator('a:has-text("Sign Up"), a[href*="signup"]').first
            if signup_nav.is_visible():
                signup_nav.click()
                time.sleep(1.5)

        page.wait_for_selector('input[placeholder*="real name"]', timeout=15000)

        # 1. Дата рождения
        print("[*] Заполнение даты рождения...")
        dropdowns = page.query_selector_all('select[id*="Dropdown"]')
        if len(dropdowns) >= 3:
            dropdowns[0].select_option(label="January")
            time.sleep(0.3)
            dropdowns[1].select_option(label="01")
            time.sleep(0.3)
            dropdowns[2].select_option(label="2000")

        # 2. Подбор никнейма
        username_approved = False
        attempts = 0
        username_input = page.locator('input[placeholder*="real name"]').first
        password_input = page.locator('input[placeholder*="8 characters"]').first

        while not username_approved and attempts < 10:
            attempts += 1
            current_username = generate_human_username()
            
            username_input.click()
            page.keyboard.press("Control+A")
            page.keyboard.press("Backspace")
            username_input.type(current_username, delay=60)
            time.sleep(0.5)
            
            password_input.click()
            time.sleep(2.0)
            
            has_error = False
            error_keywords = ["private information", "not appropriate", "already in use", "is taken", "contain"]
            for keyword in error_keywords:
                if page.get_by_text(keyword).is_visible():
                    has_error = True
                    break
            
            if has_error:
                print(f"[-] Ник '{current_username}' отклонен. Ищем замену...")
            else:
                print(f"[+] Ник '{current_username}' одобрен!")
                final_username = current_username
                username_approved = True

        if not username_approved:
            print("[-] Не удалось подобрать ник. Пропуск.")
            browser.close()
            return False

        # 3. Ввод пароля
        if final_password.strip() == "":
            final_password = random.choice(string.ascii_uppercase) + "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(7)) + "!"

        print("[*] Ввод пароля...")
        password_input.click()
        page.keyboard.press("Control+A")
        page.keyboard.press("Backspace")
        password_input.type(final_password, delay=60)
        time.sleep(0.5)

        # 4. Пол
        male_button = page.locator('#MaleButton').first
        if male_button.is_visible():
            male_button.click()
            time.sleep(0.3)

        # 5. Клик Sign Up
        print("[*] Нажимаем кнопку 'Sign Up'...")
        signup_button = page.locator('button[id*="signup-button"], button:has-text("Sign Up")').first
        signup_button.click()

        print("-----------------------------------------")
        print("[!] Ожидание регистрации / решения капчи (До 3 минут)...")
        print("[!] ЕСЛИ СЕЙЧАС В ОКНЕ ХРОМА ВЫЛЕЗЕТ КАПЧА — РЕШИ ЕЁ РУКАМИ!")
        print("-----------------------------------------")
        
        try:
            page.wait_for_url("**/home", timeout=180000)
            success = True
        except PlaywrightTimeoutError:
            success = False

        if success:
            print(f"[+] АККАУНТ УСПЕШНО СОЗДАН: {final_username}")
            account_info = {"username": final_username, "password": final_password}
            save_to_desktop_json(account_info)
        else:
            print("[-] Время вышло. Регистрация не зафиксирована.")

    except PlaywrightTimeoutError:
        print("[-] Ошибка: Страница зависла.")
    except Exception as e:
        print(f"[-] Ошибка: {e}")
    finally:
        browser.close()
        
    return success

def main():
    print("==================================================")
    print("    Roblox AltGen v6.4 (PC + Stealth + BugFix)    ")
    print("==================================================")
    
    try:
        count = int(input("[?] Сколько аккаунтов нужно создать?: "))
    except ValueError:
        print("Введите число цифрами!")
        return

    custom_password = input("[?] Введите общий пароль (Enter для случайных): ")
    successful_count = 0
    
    with sync_playwright() as p:
        for i in range(count):
            print(f"\n--- Создание аккаунта {i + 1} из {count} ---")
            is_done = create_one_account(p, custom_password)
            if is_done:
                successful_count += 1
            
            if i < count - 1:
                print("[*] Ждем 5 секунд перед запуском следующего окна...")
                time.sleep(5)
                
    print(f"\n[#] Работа завершена! Создано аккаунтов: {successful_count}/{count}")

if __name__ == "__main__":
    main()