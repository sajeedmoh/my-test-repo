import tkinter as tk

def click(value):
    current = entry.get()
    entry.delete(0, tk.END)
    entry.insert(0, current + value)

def clear():
    entry.delete(0, tk.END)

def backspace():
    current = entry.get()
    entry.delete(0, tk.END)
    entry.insert(0, current[:-1])

def calculate():
    try:
        result = eval(entry.get())
        entry.delete(0, tk.END)
        entry.insert(0, str(result))
    except ZeroDivisionError:
        entry.delete(0, tk.END)
        entry.insert(0, "Error: Div by 0")
    except Exception:
        entry.delete(0, tk.END)
        entry.insert(0, "Error")

# Main window
root = tk.Tk()
root.title("Calculator")
root.resizable(False, False)
root.configure(bg="#2e2e2e")

# Display entry
entry = tk.Entry(root, font=("Arial", 24), bd=0, bg="#1e1e1e", fg="white",
                 insertbackground="white", justify="right")
entry.grid(row=0, column=0, columnspan=4, padx=10, pady=10, ipady=15, sticky="we")

# Button style using Label for proper color rendering on macOS
def make_btn(text, row, col, cmd, color="#3e3e3e", colspan=1):
    btn = tk.Label(root, text=text, font=("Arial", 18), bg=color, fg="white",
                   padx=10, pady=15, cursor="hand2")
    btn.grid(row=row, column=col, columnspan=colspan, padx=5, pady=5, sticky="we")
    btn.bind("<Button-1>", lambda _e: cmd())
    btn.bind("<Enter>",    lambda _e: btn.config(bg="#666" if color == "#3e3e3e" else color))
    btn.bind("<Leave>",    lambda _e: btn.config(bg=color))

# Row 1
make_btn("C",   1, 0, clear,             color="#e74c3c")
make_btn("⌫",  1, 1, backspace,          color="#e67e22")
make_btn("%",   1, 2, lambda: click("%"), color="#555")
make_btn("/",   1, 3, lambda: click("/"), color="#f39c12")

# Row 2
make_btn("7", 2, 0, lambda: click("7"))
make_btn("8", 2, 1, lambda: click("8"))
make_btn("9", 2, 2, lambda: click("9"))
make_btn("*", 2, 3, lambda: click("*"), color="#f39c12")

# Row 3
make_btn("4", 3, 0, lambda: click("4"))
make_btn("5", 3, 1, lambda: click("5"))
make_btn("6", 3, 2, lambda: click("6"))
make_btn("-", 3, 3, lambda: click("-"), color="#f39c12")

# Row 4
make_btn("1", 4, 0, lambda: click("1"))
make_btn("2", 4, 1, lambda: click("2"))
make_btn("3", 4, 2, lambda: click("3"))
make_btn("+", 4, 3, lambda: click("+"), color="#f39c12")

# Row 5
make_btn("0",   5, 0, lambda: click("0"), colspan=2)
make_btn(".",   5, 2, lambda: click("."))
make_btn("=",   5, 3, calculate, color="#2ecc71")

root.mainloop()
