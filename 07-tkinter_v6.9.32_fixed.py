#!/usr/bin/env python3
"""
07‑tkinter_v6.9.32_fixed.py – simple Tkinter GUI installer for the Cursor IDE.

This script provides a minimal graphical installer using the built‑in
`tkinter` toolkit so that users can install or uninstall the Cursor IDE
without resorting to the command line.  It wraps the existing shell
installer (`install_v6.9.32.sh`) and presents a small window with
Install and Uninstall buttons.  Pressing one of these buttons will
invoke the appropriate mode on the installer.  A progress bar is shown
while the operation runs in a background thread.  Any error output is
reported in a message box at the end.

The UI is intentionally simple to avoid dependencies on external
libraries.  It is not meant to replace the enhanced or Zenity based
installers, but rather to provide a cross‑platform fallback for GUI
environments where `zenity` is unavailable.  Because `tkinter` may not
be installed on minimal systems, this script should be considered
optional.
"""

import os
import subprocess
import sys
import threading

# Try importing tkinter. If it's unavailable (e.g. python-tk is not installed),
# print a clear error message and exit gracefully. This prevents a
# ModuleNotFoundError from crashing the script when run on minimal systems.
try:
    import tkinter as tk
    from tkinter import ttk, messagebox  # type: ignore
except ImportError:
    sys.stderr.write(
        "Error: tkinter module is not available.\n"
        "Please install the 'python3-tk' package or use the CLI installer.\n"
    )
    sys.exit(1)


def run_installer(script_path: str, mode: str, progress: ttk.Progressbar, root: tk.Tk) -> None:
    """Run the installer in a background thread and update progress.

    :param script_path: Path to the install_v6.9.32.sh wrapper
    :param mode: Either "install" or "uninstall"
    :param progress: Progressbar widget to update
    :param root: The Tk root window
    """

    def task() -> None:
        try:
            # Start progressbar in indeterminate mode
            root.after(0, lambda: progress.start(10))
            cmd = ["bash", script_path, f"--{mode}"]
            # Use check_call so that exceptions propagate on failure
            subprocess.check_call(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            root.after(0, lambda: messagebox.showinfo(
                title="Cursor Installer", message=f"{mode.capitalize()}ation completed successfully."))
        except subprocess.CalledProcessError as exc:
            # Extract error output if available
            err_msg = exc.output.decode(errors="ignore") if getattr(exc, "output", None) else str(exc)
            root.after(0, lambda: messagebox.showerror(
                title="Cursor Installer", message=f"{mode.capitalize()}ation failed:\n{err_msg}"))
        finally:
            # Stop and reset the progress bar regardless of outcome
            root.after(0, lambda: progress.stop())

    threading.Thread(target=task, daemon=True).start()


def main() -> None:
    # Determine the location of the installer relative to this script
    script_dir = os.path.abspath(os.path.dirname(__file__))
    install_script = os.path.join(script_dir, "install_v6.9.32.sh")
    if not os.path.isfile(install_script):
        sys.stderr.write(
            f"Error: installer script not found at {install_script}\nPlease ensure this script resides in the same directory.\n"
        )
        sys.exit(1)

    root = tk.Tk()
    root.title("Cursor Installer v6.9.32")
    root.resizable(False, False)

    # Centre the window on screen
    window_width = 350
    window_height = 160
    screen_width = root.winfo_screenwidth()
    screen_height = root.winfo_screenheight()
    x_cordinate = int((screen_width / 2) - (window_width / 2))
    y_cordinate = int((screen_height / 2) - (window_height / 2))
    root.geometry(f"{window_width}x{window_height}+{x_cordinate}+{y_cordinate}")

    # Create UI elements
    label = ttk.Label(root, text="Welcome to the Cursor Installer", font=("Arial", 12))
    label.pack(pady=10)

    progress = ttk.Progressbar(root, mode="indeterminate", length=250)
    progress.pack(pady=5)

    button_frame = ttk.Frame(root)
    button_frame.pack(pady=10)

    install_btn = ttk.Button(button_frame, text="Install",
                             command=lambda: run_installer(install_script, "install", progress, root))
    uninstall_btn = ttk.Button(button_frame, text="Uninstall",
                               command=lambda: run_installer(install_script, "uninstall", progress, root))
    quit_btn = ttk.Button(button_frame, text="Quit", command=root.destroy)

    install_btn.grid(row=0, column=0, padx=5)
    uninstall_btn.grid(row=0, column=1, padx=5)
    quit_btn.grid(row=0, column=2, padx=5)

    # Run the Tk event loop
    root.mainloop()


if __name__ == "__main__":
    main()