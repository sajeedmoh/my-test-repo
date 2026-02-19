import tkinter as tk
import math

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

def sci_func(func):
    try:
        val = float(entry.get())
        if func == "sin":    result = math.sin(math.radians(val))
        elif func == "cos":  result = math.cos(math.radians(val))
        elif func == "tan":  result = math.tan(math.radians(val))
        elif func == "log":  result = math.log10(val)
        elif func == "ln":   result = math.log(val)
        elif func == "sqrt": result = math.sqrt(val)
        elif func == "x²":   result = val ** 2
        elif func == "x³":   result = val ** 3
        elif func == "1/x":  result = 1 / val
        elif func == "π":
            entry.delete(0, tk.END)
            entry.insert(0, str(math.pi))
            return
        elif func == "e":
            entry.delete(0, tk.END)
            entry.insert(0, str(math.e))
            return
        entry.delete(0, tk.END)
        entry.insert(0, str(round(result, 10)))
    except ZeroDivisionError:
        entry.delete(0, tk.END)
        entry.insert(0, "Error: Div by 0")
    except Exception:
        entry.delete(0, tk.END)
        entry.insert(0, "Error")

# Main window
root = tk.Tk()
root.title("Scientific Calculator")
root.resizable(False, False)
root.configure(bg="#2e2e2e")

# Display entry (spans all 8 columns)
entry = tk.Entry(root, font=("Arial", 22), bd=0, bg="#1e1e1e", fg="white",
                 insertbackground="white", justify="right")
entry.grid(row=0, column=0, columnspan=8, padx=10, pady=10, ipady=15, sticky="we")

# Button style using Label for proper color rendering on macOS
def make_btn(text, row, col, cmd, color="#3e3e3e", colspan=1):
    btn = tk.Label(root, text=text, font=("Arial", 14), bg=color, fg="white",
                   padx=8, pady=12, cursor="hand2")
    btn.grid(row=row, column=col, columnspan=colspan, padx=3, pady=3, sticky="we")
    btn.bind("<Button-1>", lambda _e: cmd())
    btn.bind("<Enter>",    lambda _e: btn.config(bg="#666" if color == "#3e3e3e" else color))
    btn.bind("<Leave>",    lambda _e: btn.config(bg=color))

SCI = "#1a5276"  # dark blue for scientific buttons

# Row 1 — Scientific functions
make_btn("sin",  1, 0, lambda: sci_func("sin"),  color=SCI)
make_btn("cos",  1, 1, lambda: sci_func("cos"),  color=SCI)
make_btn("tan",  1, 2, lambda: sci_func("tan"),  color=SCI)
make_btn("log",  1, 3, lambda: sci_func("log"),  color=SCI)
make_btn("ln",   1, 4, lambda: sci_func("ln"),   color=SCI)
make_btn("√",    1, 5, lambda: sci_func("sqrt"), color=SCI)
make_btn("x²",   1, 6, lambda: sci_func("x²"),   color=SCI)
make_btn("x³",   1, 7, lambda: sci_func("x³"),   color=SCI)

# Row 2 — More scientific + clear/backspace
make_btn("π",    2, 0, lambda: sci_func("π"),    color=SCI)
make_btn("e",    2, 1, lambda: sci_func("e"),    color=SCI)
make_btn("1/x",  2, 2, lambda: sci_func("1/x"),  color=SCI)
make_btn("(",    2, 3, lambda: click("("),        color="#555")
make_btn(")",    2, 4, lambda: click(")"),        color="#555")
make_btn("C",    2, 5, clear,                    color="#e74c3c")
make_btn("⌫",   2, 6, backspace,                color="#e67e22")
make_btn("%",    2, 7, lambda: click("%"),        color="#555")

# Row 3
make_btn("7", 3, 0, lambda: click("7"))
make_btn("8", 3, 1, lambda: click("8"))
make_btn("9", 3, 2, lambda: click("9"))
make_btn("*", 3, 3, lambda: click("*"), color="#f39c12")
make_btn("/", 3, 4, lambda: click("/"), color="#f39c12")
make_btn("^", 3, 5, lambda: click("**"), color="#555")
make_btn("E", 3, 6, lambda: click("e"), color="#555")  # scientific notation
make_btn("+/-", 3, 7, lambda: click("-"), color="#555")

# Row 4
make_btn("4", 4, 0, lambda: click("4"))
make_btn("5", 4, 1, lambda: click("5"))
make_btn("6", 4, 2, lambda: click("6"))
make_btn("-", 4, 3, lambda: click("-"), color="#f39c12")
make_btn("+", 4, 4, lambda: click("+"), color="#f39c12")

# Row 5
make_btn("1", 5, 0, lambda: click("1"))
make_btn("2", 5, 1, lambda: click("2"))
make_btn("3", 5, 2, lambda: click("3"))

# Row 6
make_btn("0",  6, 0, lambda: click("0"), colspan=2)
make_btn(".",  6, 2, lambda: click("."))
make_btn("=",  6, 3, calculate, color="#2ecc71", colspan=2)

root.mainloop()
