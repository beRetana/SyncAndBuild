import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox
from enum import Enum
from xml.dom import DomstringSizeErr

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
    result = shutil.which(file_name)
    if result is not None:
        return Path(result)
    
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
        tree = ET.parse(custom_tool_file)
        root = tree.getroot()
        for tool_definition in root.findall("CustomToolDef"):
            tool_def_content = tool_definition.find(".//Name")
            if tool_def_content is not None and tool_def_content.text == custom_tool_name:
                return True
            
    except ET.ParseError:
        return False
    return False

def define_custom_tool(custom_tool_file: Path, tool_name: str, bat_path: str, starting_folder: str)-> bool:
    """Define a custom tool in p4v"""
    p4qt_dir = os.path.dirname(custom_tool_file)
    
    if not os.path.isfile(custom_tool_file):
        os.makedirs(p4qt_dir, exist_ok=True)
        root = ET.Element("CustomToolDefList")
        root.set("varName", "customtooldeflist")
        tree = ET.ElementTree(root)
    else:
        tree = ET.parse(custom_tool_file)
        root = tree.getroot()

    tool_def = ET.SubElement(root, "CustomToolDef")

    definition = ET.SubElement(tool_def, "Definition")
    ET.SubElement(definition, "Name").text = tool_name
    ET.SubElement(definition, "Command").text = r"C:\Windows\System32\cmd.exe"
    ET.SubElement(definition, "Arguments").text = f"/k {bat_path}"
    ET.SubElement(definition, "Shortcut").text = ""
    ET.SubElement(definition, "InitDir").text = starting_folder

    console = ET.SubElement(tool_def, "Console")
    ET.SubElement(console, "CloseOnExit").text = "true"

    ET.SubElement(tool_def, "AddToContext").text = "true"
    ET.SubElement(tool_def, "Refresh").text = "true"

    ET.indent(tree, space="  ")

    tree.write(custom_tool_file, encoding="UTF-8", xml_declaration=True)
    
    return True

def fix_existing_custom_tool(custom_tool_file: Path, custom_tool_name: str, bat_path: str, starting_folder: str)-> bool:
    """Fix an existing custom tool in p4v"""
    
    tree = ET.parse(custom_tool_file)
    root = tree.getroot()
    
    for tool_definition in root.findall("CustomToolDef"):
        tool_def_name = tool_definition.find(".//Name")
        if tool_def_name is not None and tool_def_name.text == custom_tool_name:
            print(f"Custom tool {custom_tool_name} already exists, updating...")
            root.remove(tool_definition)
            
    tree.write(custom_tool_file, encoding="UTF-8", xml_declaration=True)
    
    return define_custom_tool(custom_tool_file, custom_tool_name, bat_path, starting_folder)

class P4ConfigUI(tk.Toplevel):
    def __init__(self):
        super().__init__()
        pass
            
class LogType(Enum):
    INFO = 0
    WARNING = 1
    SUCCESS = 2
    ERROR = 3

class ToolInstaller:
    
    def __init__(self):
        self._app_path = get_app_path()
        self._project_path = get_project_path(self._app_path)
        self._uproject_path = get_uproject_path(self._project_path)
        self._log_file = self._app_path.joinpath("Logs", "installer.log")
        self._buffered_log = ""
        
    def _check_project_structure(self)-> bool:
        """Check if the project structure is correct"""
        self._log(LogType.INFO, "Checking for correct tool structure...")
        
        if not check_source_files_exist(self._app_path):
            self._log(LogType.ERROR, "Source files are missing, please check the tool structure.")
            return False
        self._log(LogType.SUCCESS, "Source files found.")

        self._log(LogType.INFO, "Checking for Project directory...")
        if self._project_path is None:
            self._log(LogType.ERROR, "Project directory not found.")
            return False
        self._log(LogType.SUCCESS, "Project directory found at: " + str(self._project_path))

        self._log(LogType.INFO, "Checking for .uproject file...")
        if self._uproject_path is None:
            self._log(LogType.ERROR, ".uproject file not found.")
            return False
        self._log(LogType.SUCCESS, ".uproject file found at: " + str(self._uproject_path))
        
        return True
    
    def _check_p4(self)-> bool:

        self._log(LogType.INFO, "Checking for correct P4, and P4V installation...")
        
        self._log(LogType.INFO, "Checking for p4 CLI...")
        p4_path = get_p4_path()
        if p4_path is None:
            self._log(LogType.ERROR, "p4 CLI not found.")
            return False
        self._log(LogType.SUCCESS, "p4 CLI found at: " + str(p4_path))

        self._log(LogType.INFO, "Checking for p4 CLI connection...")
        if check_p4_connection():
            self._log(LogType.ERROR, "p4 CLI is not connected to the server.")
            return False
        self._log(LogType.SUCCESS, "p4 CLI is connected to the server.")

        self._log(LogType.INFO, "Checking for p4v...")
        p4v_path = get_p4v_path()
        if p4v_path is None:
            self._log(LogType.ERROR, "p4v not found.")
            return False
        self._log(LogType.SUCCESS, "p4v found at: " + str(p4v_path))

        return True
        
    def _setup_p4_config_(self)-> bool:
        """Check if the p4 config file exists"""

        self._log(LogType.INFO, "Setting up p4config credentials")
        self._log(LogType.INFO, "Searching for p4 config file...")

        config_path = get_p4_config_path(self._project_path)

        if config_path is None or not config_path.is_file():
            self._log(LogType.WARNING, "No .p4config file found, creating one...")
            config_path = get_project_path(self._app_path).joinpath(".p4config")
            self._log(LogType.WARNING, ".p4config file created at: " + str(config_path))
        else:
            self._log(LogType.SUCCESS, "Found .p4config file")
            self._log(LogType.INFO, "Checking if credentials are correct...")

        file_variables = get_p4_config_file_vars(config_path)

        match len(file_variables):
            case 3:
                self._log(LogType.SUCCESS, "Found All credentials in .p4config file.")
                return True
            case 0:
                self._log(LogType.WARNING, "All credentials in .p4config are missing")
            case _:
                self._log(LogType.WARNING, "Some credentials in .p4config are missing")

        self._log(LogType.INFO, "Searching for credentials in environment variables...")
        env_variables = get_p4_env_vars()

        for key, value in file_variables.items():
            env_variables[key] = value

        if len(env_variables) == 3:
            self._log(LogType.SUCCESS, "Found All credentials.")
            self._log(LogType.INFO, "Setting config file with found credentials.")
            set_config_file(config_path, env_variables)
            self._log(LogType.SUCCESS, ".p4config credentials set successfully.")
            return True

        self._log(LogType.WARNING, "Credentials are still needed, user input required.")
        # calls for user input
        return True
    
    def _setup_custom_tool_(self)-> bool:
        """Check if the custom tool is defined in p4v"""
        return False
        
    def _clean_log_file(self):
        with open(self._log_file, "w") as log_file:
            log_file.write("")
            
    def _flush_to_log_file(self):
        if self._buffered_log == "":
            return
        
        with open(self._log_file, "a") as log_file:
            log_file.write(self._buffered_log)
            self._buffered_log = ""
    
    def _log(self, log_type: LogType, message: str):
        
        # logic for showing the log in the GUI
        
        self._buffered_log += f"{log_type.name}: {message}\n"
        
    def _abort_installation(self):
        self._flush_to_log_file()
        pass
    
    def _installation_finished(self):
        self._log(LogType.SUCCESS, "Installation finished successfully.")
        self._flush_to_log_file()
        pass

    def install(self):
        """Install the tool"""

        self._clean_log_file()
        self._log(LogType.INFO, "Starting installation...")

        installation_steps = [
            self._check_project_structure,
            self._check_p4,
            self._setup_p4_config_,
            self._setup_custom_tool_]

        for step in installation_steps:
            self._flush_to_log_file()
            if not step():
                self._abort_installation()
                return

        self._installation_finished()
    
    def run(self):
        
        try:
            self.install()
        except Exception as e:
            self._log(LogType.ERROR, str(e))
        finally:
            self._flush_to_log_file()

if __name__ == "__main__":
    print(get_p4_config_file_vars())