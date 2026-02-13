import os
import pathlib
import sys

class SynchAndBuildInstaller:

    def __init__(self) -> None:

        try:
            self._app_path = sys._MEIPASS
        self._app_path = pathlib.Path(__file__).parent.absolute()
        self._p4confing_path = None
        self._p4_user = None
        self._p4_password = None
        self._p4_workspace = None
        self._p4_server = None
        pass

    def _check_tool_path_structure(self)-> bool:
        pass

    def _get_p4confing_path(self)-> bool:
        pass

    def _set_p4confing_path(self)-> bool:
        pass

    def _create_custom_tool(self)-> bool:
        pass

    def _create_crash_log(self)-> bool:
        pass

    def _failed_shut_down(self)-> None:
        pass
# Encontrar las direcciones necesarias

# Verificar que la estructura de las carpetas en el proyecto
    # Abortar si es necesario
# Verificar si p4 CLI esta instalado
    # Instalar si no
# Verificar si p4v esta instalado
    # instalar si no

# Buscar la informacion de configuracion para p4 logins
# Crear p4confg si es necesario

def RunInstaller():
    # Run the de fucntions in a sequence
    pass

if __name__ == "__main__":
    print("Hello World")