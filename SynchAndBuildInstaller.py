import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox

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
    
    return search_for_file(P4_COMMON_PATHS, "p4.exe")

def get_p4v_path()-> Path | None:
    """Search for a p4v executable and return the path to it, if not found, then return None"""

    return search_for_file(P4V_COMMON_PATHS, "p4v.exe")

def search_for_file(common_paths: list, file_name='')-> Path | None:
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

def _get_p4_var(var_name: str)-> list[str] | None:
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
        result = _get_p4_var(var)
        if result is not None:
            dict_to_return[result[0]] = result[1]
    
    return dict_to_return

def get_p4v_custom_tools_path()-> Path | None:
    """Return a path to the XML file with custom tools in p4v"""
    
    env = os.environ.copy()
    
    user_profile = env.get("USERPROFILE", None)
    
    if user_profile is None:
        return None
    return Path(user_profile).joinpath(".p4qt", "customtools.xml")

def create_p4_config():
    """Create a p4 config file in the project folder"""
    config_path = get_project_path(get_app_path()).joinpath(".p4config")
    set_config(config_path)
    
def set_config(config_file: Path, variables=None)-> None:
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
           
# this is for now, we will add GUI later    
def check_p4_config():
    """Check if the p4 config file exists"""
    config_path = get_p4_config_path()
    
    # Check variables exist
    # if they do create a new file
    # if not ask user for input
    
    if (not config_path) or (not config_path.exists()):
        create_p4_config()
    else:
        set_config(config_path)

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
        
class InstallerGUI:
    def __init__(self):
        pass
        
        
class ToolInstaller:
    
    def __init__(self):
        pass

if __name__ == "__main__":
    pass