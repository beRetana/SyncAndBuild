import os
import subprocess
import sys
import xml.etree.ElementTree as Et
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox
from enum import Enum

# The tool cannot run without these files
REQUIRED_SOURCE_FILES = [
    os.path.join("Source", "sync_and_build.bat"),
    os.path.join("Source", "sync_and_build.ps1")
]

# This will make it faster to find the p4 and p4v executables
P4V_COMMON_PATHS = [
    os.path.join("Program Files", "Perforce", "p4v.exe"),
    os.path.join("Program Files (x86)", "Perforce", "p4v.exe")
]

P4_COMMON_PATHS = [
    os.path.join("Program Files", "Perforce", "p4.exe"),
    os.path.join("Program Files (x86)", "Perforce", "p4.exe")
]

P4_USER = "P4USER"
P4_PORT = "P4PORT"
P4_CLIENT = "P4CLIENT"
P4_TIME_OUT = 15

def get_root_path()-> Path:
    """Return the path to the root folder of the project"""
    return Path("C:\\")

def get_app_path(location="")-> Path:
    """Return the path to the application folder"""
    
    if (not location == "") and Path(location).is_dir():
        return Path(location)
    
    if getattr(sys, 'frozen', False):
        return Path(sys.executable)
    return Path(os.path.dirname(os.path.realpath(__file__)))

def get_bat_file_path(starting_dir=None)-> Path:
    """Return the path to the sync_and_build.bat file"""
    
    if starting_dir is not None:
        return next(starting_dir.rglob("sync_and_build.bat"))
    
    return get_app_path().joinpath("Source", "sync_and_build.bat")

def get_project_path(app_path: Path)-> Path | None:
    """Return the path to the project folder"""
    return app_path.parent.parent

def get_uproject_path(project_path: Path)-> Path | None:
    """Search for an uproject file and return the path to it, if not found, then return None"""
    
    if not project_path.is_dir():
        return None
    
    files_found = project_path.rglob("*.uproject")

    return next(files_found, None)

def get_p4_path()-> Path | None:
    """Search for a p4 executable and return the path to it, if not found, then return None"""
    
    return _search_for_file(P4_COMMON_PATHS, "p4.exe")

def get_p4v_path()-> Path | None:
    """Search for a p4v executable and return the path to it, if not found, then return None"""

    return _search_for_file(P4V_COMMON_PATHS, "p4v.exe")

def _search_for_file(common_paths: list, file_name='')-> Path | None:
    """Search for a file in common paths and return the path to it, if not found, then return None"""

    root = get_root_path()
    for path in common_paths:
        potential_path = root / path
        if potential_path.exists():
            return potential_path
        
    files_found = root.rglob(file_name) # In case the file is not in the common paths
    first_file = next(files_found, None)
    if first_file is not None:
        return first_file
    
    return None
      
def get_p4_config_path(project_path=None)-> Path | None:
    """Search for a p4 config file and return the path to it, if not found, then return None"""
    
    if project_path is None:
        project_path = get_project_path(get_app_path())
        
    for file in project_path.rglob("*.p4config"):
        if file.is_file():
            return file
    
    return None

def _get_p4_env_var(var_name: str)-> list[str] | None:
    """Return the value of a p4 environment variable"""
    
    env = os.environ.copy()

    result = subprocess.run(
        ["p4", "set", var_name],
        env=env,
        capture_output=True,
        text=True,
        timeout=P4_TIME_OUT)
    
    if result.returncode != 0:
        return None
    
    result = result.stdout

    keyword, value = result.split("=")
    value = value.split()[0].strip()
    return [keyword, value]

def get_p4_env_vars()-> dict:
    """Return a dictionary with the p4 environment variables"""

    dict_to_return = {}
    
    vars_to_get = [P4_USER, P4_PORT, P4_CLIENT]
    
    for var in vars_to_get:
        result = _get_p4_env_var(var)
        if result is not None:
            dict_to_return[result[0]] = result[1]
    
    return dict_to_return

def get_p4_config_file_vars(config_path=None)-> dict:
    """Return a dictionary with the p4 config file variables"""

    if config_path is None:
        config_path = get_p4_config_path()

    keywords = [P4_USER, P4_PORT, P4_CLIENT]
    dict_to_return = {}

    if config_path is None:
        return dict_to_return

    with open(config_path, "r") as file:
        for line in file:
            for keyword in keywords:
                if line.startswith(f"{keyword}="):
                    dict_to_return[keyword] = line.split("=")[1].split()[0].strip()
                    break

    return dict_to_return

def get_p4v_custom_tools_path()-> Path | None:
    """Return a path to the XML file with custom tools in p4v"""
    
    env = os.environ.copy()
    
    user_profile = env.get("USERPROFILE", None)
    
    if user_profile is None:
        return None
    return Path(user_profile).joinpath(".p4qt", "customtools.xml")

def create_p4_config(variables=None):
    """Create a p4 config file in the project folder"""
    config_path = get_project_path(get_app_path()).joinpath(".p4config")
    set_config_file(config_path, variables)
    
def set_config_file(config_file: Path, variables=None)-> None:
    """Set the p4 config file in the environment variables"""
    
    if variables is None:
        variables = get_p4_env_vars()
        
    keywords = list(variables.keys())

    with open(config_file, "r") as file:
        current_config = file.readlines()
    
    if current_config[0] == "\n":
        with open(config_file, "w") as file:
            for keyword in keywords:
                file.write(f"{keyword}={variables[keyword]}\n")
        return
    
    new_config = []
    for line in current_config:
        was_line_modified = False
        for keyword in keywords:
            if line.startswith(f"{keyword}="):
                new_config.append(f"{keyword}={variables[keyword]}\n")
                was_line_modified = True
                break
    
        if not was_line_modified:
            new_config.append(line)
    
    with open(config_file, "w") as file:
        file.writelines(new_config)

def check_source_files_exist(app_path=None)-> bool:
    """Check if the required source files exist in the project"""

    if app_path is None:
        app_path = get_app_path()

    for file in REQUIRED_SOURCE_FILES:
        if not (app_path / file).exists():
            return False

    return True

def check_p4_connection()-> bool:
    """Check if the p4 CLI is connected to the server"""
    
    env = os.environ.copy()
    result = subprocess.run(
        ["p4", "info"],
        env=env,
        capture_output=True,
        text=True,
        timeout=P4_TIME_OUT)
    
    if result.returncode != 0:
        return False
    
    return True

def is_custom_tool_defined(custom_tool_file: Path, custom_tool_name: str)-> bool:
    """Check if a custom tool is defined in p4v"""
    
    if (custom_tool_file is None) or (not os.path.isfile(custom_tool_file)):
        return False
    
    try:
        tree = Et.parse(custom_tool_file)
        root = tree.getroot()
        for tool_definition in root.findall("CustomToolDef"):
            tool_def_content = tool_definition.find(".//Name")
            if tool_def_content is not None and tool_def_content.text == custom_tool_name:
                return True
            
    except Et.ParseError:
        return False
    return False

def define_custom_tool(custom_tool_file: Path, tool_name: str, bat_path: str, starting_folder: str)-> bool:
    """Define a custom tool in p4v"""
    p4qt_dir = os.path.dirname(custom_tool_file)
    
    if not os.path.isfile(custom_tool_file):
        os.makedirs(p4qt_dir, exist_ok=True)
        root = Et.Element("CustomToolDefList")
        root.set("varName", "customtooldeflist")
        tree = Et.ElementTree(root)
    else:
        tree = Et.parse(custom_tool_file)
        root = tree.getroot()

    tool_def = Et.SubElement(root, "CustomToolDef")

    definition = Et.SubElement(tool_def, "Definition")
    Et.SubElement(definition, "Name").text = tool_name
    Et.SubElement(definition, "Command").text = r"C:\Windows\System32\cmd.exe"
    Et.SubElement(definition, "Arguments").text = f"/k {bat_path}"
    Et.SubElement(definition, "Shortcut").text = ""
    Et.SubElement(definition, "InitDir").text = starting_folder

    console = Et.SubElement(tool_def, "Console")
    Et.SubElement(console, "CloseOnExit").text = "true"

    Et.SubElement(tool_def, "AddToContext").text = "true"
    Et.SubElement(tool_def, "Refresh").text = "true"

    Et.indent(tree, space="  ")

    tree.write(custom_tool_file, encoding="UTF-8", xml_declaration=True)
    
    return True

def fix_existing_custom_tool(custom_tool_file: Path, custom_tool_name: str, bat_path: str, starting_folder: str)-> bool:
    """Fix an existing custom tool in p4v"""
    
    tree = Et.parse(custom_tool_file)
    root = tree.getroot()
    
    for tool_definition in root.findall("CustomToolDef"):
        tool_def_name = tool_definition.find(".//Name")
        if tool_def_name is not None and tool_def_name.text == custom_tool_name:
            root.remove(tool_definition)
            
    tree.write(custom_tool_file, encoding="UTF-8", xml_declaration=True)
    
    return define_custom_tool(custom_tool_file, custom_tool_name, bat_path, starting_folder)

class P4ConfigUI(tk.Toplevel):
    def __init__(self, parent, existing):
        super().__init__(parent)

        self.title = "Perforce Credentials"
        self.resizable(False, False)
        self.result = None
        existing = existing or {}

        self.transient(parent)
        self.grab_set()

        # Frame that contains the widgets
        frame = ttk.Frame(self, padding=20)
        frame.pack(fill=tk.BOTH, expand=True)

        # The title of the widget
        ttk.Label(
            frame,
            text="Please enter your Perforce credentials:",
            font=("Segoe UI", 12, "bold")
        ).grid(column=0, row=0, columnspan=2, pady=(0,15), sticky=tk.W)

        # The labels for entries
        ttk.Label(
            frame,
            text="P4PORT:"
        ). grid(column=0, row=1, sticky=tk.W, pady=5, padx=(0, 10))

        self.p4port_var = tk.StringVar(value=existing.get("P4PORT", ""))

        p4port_entry = ttk.Entry(
            frame,
            width=45,
            textvariable=self.p4port_var
        )
        p4port_entry.grid(column=1, row=1, sticky=tk.W, pady=5, padx=(0, 10))

        ttk.Label(
            frame,
            text="ej: perforce.server.unreal:1666",
            foreground="gray"
        ).grid( column=0, row=2, sticky=tk.W)

        ttk.Label(
            frame,
            text="P4USER:"
        ). grid(column=0, row=3, sticky=tk.W, pady=5, padx=(0, 10))

        self.p4user_var = tk.StringVar(value=existing.get("P4USER", ""))

        p4user_entry = ttk.Entry(
            frame,
            width=45,
            textvariable=self.p4user_var
        )
        p4user_entry.grid(column=1, row=3, sticky=tk.W, pady=5, padx=(0, 10))

        ttk.Label(
            frame,
            text="P4CLIENT:"
        ).grid(column=0, row=4, sticky=tk.W, pady=5, padx=(0, 10))

        self.p4client_var = tk.StringVar(value=existing.get("P4CLIENT", ""))

        p4client_entry = ttk.Entry(
            frame,
            width=45,
            textvariable=self.p4client_var
        )
        p4client_entry.grid(column=1, row=4, sticky=tk.W, pady=5, padx=(0, 10))

        ttk.Label(
            frame,
            text="workspace name",
            foreground="gray"
        ).grid(column=1, row=5, sticky=tk.W)

        btn_frame = ttk.Frame(frame)
        btn_frame.grid(column=0, row=6, columnspan=2, pady=(20, 0))

        ttk.Button(
            btn_frame,
            text="Accept",
            command=self._on_accept
        ).pack(side=tk.LEFT, padx=5)

        ttk.Button(
            btn_frame,
            text="Cancel",
            command=self._on_cancel
        ).pack(side=tk.LEFT, padx=5)

        self.protocol("WM_DELETE_WINDOW", self._on_cancel)

        # Focus on the first empty entry
        for var, entry in {self.p4port_var: p4port_entry, self.p4user_var : p4user_entry, self.p4client_var : p4client_entry}.items():
            if not var.get():
                entry.focus_set()
                break

        self.wait_window()

    def _on_accept(self):
        self.result = {
            "P4PORT": self.p4port_var.get().strip(),
            "P4USER": self.p4user_var.get().strip(),
            "P4CLIENT": self.p4client_var.get().strip()
        }

        if all(self.result.values()):
            self.destroy()
        else:
            messagebox.showerror(
                "Error",
                "All fields are required",
                parent=self
            )
    def _on_cancel(self):
        self.result = None
        self.destroy()
            
class LogType(Enum):
    INFO = 0
    WARNING = 1
    SUCCESS = 2
    ERROR = 3
    HEADER = 4
    DIM = 5

class ToolInstaller:

    TOOL_NAME = "Auto Sync & Build"
    WINDOW_WIDTH = 650
    WINDOW_HEIGHT = 520
    HEADER_BG = "#1e293b"   # Dark slate
    HEADER_FG = "#f8fafc"   # Near-white
    LOG_BG = "#f1f5f9"      # Light gray

    GREEN = "#16a34a"
    RED = "#dc2626"
    ORANGE = "#d97706"
    BLUE = "#334155"
    BLUE_GRAY = "#94a3b8"
    
    def __init__(self):
        self._app_path = get_app_path()
        self._project_path = get_project_path(self._app_path)
        self._uproject_path = get_uproject_path(self._project_path)
        self._log_file_path = self._app_path.joinpath("Logs", "installer.log")
        self._buffered_log = ""

        self.root = tk.Tk()
        self.root.title(f"{self.TOOL_NAME} - Installer")
        self.root.geometry(f"{self.WINDOW_WIDTH}x{self.WINDOW_HEIGHT}")
        self.root.resizable(False, False)

        self._build_ui()

    def _build_ui(self):

        # Header Frame
        header = tk.Frame(
            self.root,
            bg=ToolInstaller.HEADER_BG,
            height=55
        )
        header.pack(fill=tk.X)
        header.pack_propagate(False)

        # Header Label
        tk.Label(
            header,
            text=f"⚙    {self.TOOL_NAME} Installer    ⚙",
            font=("Segoe UI", 15, "bold"),
            bg=ToolInstaller.HEADER_BG,
            fg=ToolInstaller.HEADER_FG
        ).pack(pady=13)

        # Tool Location Frame
        info_frame = ttk.Frame(
            self.root,
        )

        info_frame.pack(
            fill=tk.X,
            padx=15,
            pady=(10, 0)
        )

        # Tool Location Label
        ttk.Label(
            info_frame,
            text=f"Tool Location: {self._app_path}",
            foreground="gray",
            font=("Consolas", 8)
        ).pack(anchor=tk.W)

        # Status Frame

        status_frame = ttk.LabelFrame(self.root, text="Progress", padding=8)
        status_frame.pack(fill=tk.BOTH, expand=True, padx=15, pady=8)

        self.status_text = ttk.Text(
            status_frame,
            wrap=tk.WORD,
            font=("Consolas", 8),
            state=tk.DISABLED,
            bg=ToolInstaller.LOG_BG,
            relief=tk.FLAT,
            padx=8,
            pady=8
        )

        scrollbar = ttk.Scrollbar(status_frame, command=self.status_text.yview)
        self.status_text.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.status_text.pack(fill=tk.BOTH, expand=True)

        self.status_text.tag_configure(LogType.INFO.name, foreground=ToolInstaller.BLUE)
        self.status_text.tag_configure(LogType.WARNING.name, foreground=ToolInstaller.ORANGE)
        self.status_text.tag_configure(LogType.SUCCESS.name, foreground=ToolInstaller.GREEN)
        self.status_text.tag_configure(LogType.ERROR.name, foreground=ToolInstaller.RED)
        self.status_text.tag_configure(LogType.HEADER.name, foreground=self.HEADER_FG, font=("Consolas", 9, "bold"))
        self.status_text.tag_configure(LogType.DIM.name, foreground=ToolInstaller.BLUE_GRAY)

        btn_frame = ttk.Frame(self.root)
        btn_frame.pack(fill=tk.X, padx=15, pady=12)

        self.close_btn = ttk.Button(btn_frame, text="Close", command=self.root.quit)
        self.close_btn.pack(side=tk.RIGHT, padx=5)

        self.install_btn = ttk.Button(btn_frame, text="Install", command=self._on_install_clicked)
        self.install_btn.pack(side=tk.RIGHT, padx=5)
        
    def _check_project_structure(self)-> bool:
        """Check if the project structure is correct"""
        self._header_log("Step 1: Checking for correct tool structure...")
        
        if not check_source_files_exist(self._app_path):
            self._error_log("Source files are missing, please check the tool structure.")
            return False
        self._success_log("Source files found.")

        self._info_log("Checking for Project directory...")
        if self._project_path is None:
            self._error_log("Project directory not found.")
            return False
        self._success_log("Project directory found at: " + str(self._project_path))

        self._info_log("Checking for .uproject file...")
        if self._uproject_path is None:
            self._error_log(".uproject file not found.")
            return False
        self._success_log(".uproject file found at: " + str(self._uproject_path))
        
        return True
    
    def _check_p4(self)-> bool:

        self._header_log("Step 2: Checking for correct P4, and P4V installation...")
        
        self._info_log("Checking for p4 CLI...")
        p4_path = get_p4_path()
        if p4_path is None:
            self._error_log("p4 CLI not found.")
            return False
        self._success_log("p4 CLI found at: " + str(p4_path))

        self._info_log("Checking for p4 CLI connection...")
        if check_p4_connection():
            self._error_log("p4 CLI is not connected to the server.")
            return False
        self._success_log("p4 CLI is connected to the server.")

        self._info_log("Checking for p4v...")
        p4v_path = get_p4v_path()
        if p4v_path is None:
            self._error_log("p4v not found.")
            return False
        self._success_log("p4v found at: " + str(p4v_path))

        return True
        
    def _setup_p4_config(self)-> bool:
        """Check if the p4 config file exists"""

        self._header_log("Step 3: Setting up p4config credentials")
        self._info_log("Searching for p4 config file...")

        config_path = get_p4_config_path(self._project_path)

        if config_path is None or not config_path.is_file():
            self._warning_log("No .p4config file found, creating one...")
            config_path = get_project_path(self._app_path).joinpath(".p4config")
            self._info_log(".p4config file created at: " + str(config_path))
        else:
            self._success_log("Found .p4config file")
            self._info_log("Checking if credentials are correct...")

        file_variables = get_p4_config_file_vars(config_path)

        match len(file_variables):
            case 3:
                self._success_log("Found All credentials in .p4config file.")
                return True
            case 0:
                self._warning_log("All credentials in .p4config are missing")
            case _:
                self._warning_log("Some credentials in .p4config are missing")

        self._info_log("Searching for credentials in environment variables...")
        env_variables = get_p4_env_vars()

        for key, value in file_variables.items():
            env_variables[key] = value

        if len(env_variables) == 3:
            self._success_log("Found All credentials.")
            self._info_log("Setting config file with found credentials.")
            set_config_file(config_path, env_variables)
            self._success_log(".p4config credentials set successfully.")
            return True

        self._warning_log("Credentials are still needed, user input required.")

        result = P4ConfigUI(self._app_path.parent, env_variables).result
        if len(result) != 3:
            self._error_log("Failed to obtain credentials from user input, aborting installation.")
            return False

        self._success_log("Credentials set successfully.")
        self._info_log("Setting config file with credentials.")
        set_config_file(config_path, env_variables)
        self._success_log(".p4config credentials set successfully.")
        return True
    
    def _setup_custom_tool(self)-> bool:
        """Check if the custom tool is defined in p4v"""

        self._header_log("Step 4: Setting up custom tool...")
        custom_tool_file = get_p4v_custom_tools_path()

        if custom_tool_file is None:
            self._error_log("User profile not found.")
            return False

        self._success_log("Custom tool file found at: " + str(custom_tool_file))
        self._info_log("Checking if custom tool is defined...")

        is_defined = is_custom_tool_defined(custom_tool_file, ToolInstaller.TOOL_NAME)

        if is_defined:
            self._success_log("Custom tool is already defined.")
            self._info_log("Refreshing custom tool definition...")
            fix_existing_custom_tool(
                custom_tool_file,
                ToolInstaller.TOOL_NAME,
                str(get_bat_file_path(self._app_path)),
                str(self._project_path))
            self._success_log("Custom tool definition refreshed successfully.")
            return True

        self._warning_log("Custom tool is not defined.")
        self._info_log("Defining custom tool...")
        define_custom_tool(
            custom_tool_file,
            ToolInstaller.TOOL_NAME,
            str(get_bat_file_path(self._app_path)),
            str(self._project_path))
        self._success_log("Custom tool definition created successfully.")

        return True
        
    def _clean_log_file(self):
        with open(self._log_file_path, "w") as log_file:
            log_file.write("")
            
    def _flush_to_log_file(self):
        if self._buffered_log == "":
            return
        
        with open(self._log_file_path, "a") as log_file:
            log_file.write(self._buffered_log)
            self._buffered_log = ""

    def _header_log(self, message: str):
        self._log(f"\n▶ {message}", log_type=LogType.HEADER)

    def _info_log(self, message: str):
        self._log(f"  → {message}", log_type=LogType.INFO)

    def _warning_log(self, message: str):
        self._log(f"  ⚠ {message}", log_type=LogType.WARNING)

    def _success_log(self, message: str):
        self._log(f"  ✓ {message}", log_type=LogType.SUCCESS)

    def _error_log(self, message: str):
        self._log(f"  ✗ {message}", log_type=LogType.ERROR)

    def _dim_log(self, message: str):
        self._log(message, log_type=LogType.DIM)

    def _log(self, message: str, log_type: LogType):
        
        self.status_text.configure(state=tk.NORMAL)
        self.status_text.insert(tk.END, f"{message}\n", log_type.name)
        self.status_text.configure(state=tk.DISABLED)
        self.status_text.configure(state=tk.DISABLED)

        self._buffered_log += f"{log_type.name}: {message}\n"
        self.root.update_idletasks()
    
    def _finish(self, success=True):
        self._info_log("")
        self._header_log("=" * 48)
        if success:
            self._success_log("  Installation Completed")
            self._info_log("")
            self._info_log("  Open P4V and look for 'Auto Sync & Build'")
            self._info_log("  under Tools or in the context menu (right click)")
        else:
            self._error_log("  Incomplete Installation — Check errors above or log file")
            self._info_log(f"  Log File can be found at: {str(self._log_file_path)}")
        self._header_log("=" * 48)

    def _on_install_clicked(self):
        self.install_btn.configure(state=tk.DISABLED)
        self.status_text.configure(state=tk.NORMAL)
        self.status_text.delete(1.0, tk.END)
        self.status_text.configure(state=tk.DISABLED)
        self.install()

    def install(self):
        """Install the tool"""

        self._clean_log_file()
        self._info_log("="*48)
        self._header_log(f"{ToolInstaller.TOOL_NAME} - Installer")
        self._dim_log(f"Author: Brandon Eduardo Retana García")
        self._info_log("=" * 48)
        self._info_log("")

        installation_steps = [
            self._check_project_structure,
            self._check_p4,
            self._setup_p4_config,
            self._setup_custom_tool]

        for step in installation_steps:
            self._flush_to_log_file()
            if not step():
                self._finish(success=False)
                return

        self._finish(success=True)
    
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    Installer = ToolInstaller()
    Installer.run()