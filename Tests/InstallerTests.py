import unittest
import os
import sys
from unittest.mock import patch, MagicMock, mock_open
from pathlib import Path

# Add parent directory to path to import the module
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import Installer as installer


class TestPathGetters(unittest.TestCase):
    """Tests for path getter functions"""

    def test_get_root_path(self):
        """Test that get_root_path returns C:\\ """
        result = installer.get_root_path()
        self.assertEqual(result, Path("C:\\"))
        self.assertIsInstance(result, Path)

    @patch('Installer.sys')
    @patch('Installer.os.path.dirname')
    @patch('Installer.os.path.realpath')
    def test_get_app_path_with_location(self, mock_realpath, mock_dirname, mock_sys):
        """Test get_app_path with a valid location parameter"""
        test_location = "C:\\TestFolder"
        with patch('pathlib.Path.is_dir', return_value=True):
            result = installer.get_app_path(test_location)
            self.assertEqual(result, Path(test_location))

    @patch('Installer.sys')
    @patch('Installer.os.path.dirname')
    @patch('Installer.os.path.realpath')
    def test_get_app_path_frozen(self, mock_realpath, mock_dirname, mock_sys):
        """Test get_app_path when application is frozen (exe) returns parent dir"""
        mock_sys.frozen = True
        mock_sys.executable = "C:\\App\\tool.exe"
        result = installer.get_app_path()
        self.assertEqual(result, Path("C:\\App"))

    @patch('Installer.sys')
    @patch('Installer.os.path.dirname')
    @patch('Installer.os.path.realpath')
    def test_get_app_path_not_frozen(self, mock_realpath, mock_dirname, mock_sys):
        """Test get_app_path when application is not frozen (running as script)"""
        mock_sys.frozen = False
        mock_realpath.return_value = "C:\\Scripts\\Installer.py"
        mock_dirname.return_value = "C:\\Scripts"
        result = installer.get_app_path()
        self.assertEqual(result, Path("C:\\Scripts"))

    def test_get_project_path(self):
        """Test get_project_path returns parent.parent of app_path"""
        app_path = Path("C:\\Project\\Tools\\SyncAndBuild")
        result = installer.get_project_path(app_path)
        self.assertEqual(result, Path("C:\\Project"))

    @patch('pathlib.Path.is_dir')
    @patch('pathlib.Path.rglob')
    def test_get_uproject_path_found(self, mock_rglob, mock_is_dir):
        """Test get_uproject_path when .uproject file is found"""
        mock_is_dir.return_value = True
        expected_path = Path("C:\\Project\\MyGame.uproject")
        mock_rglob.return_value = iter([expected_path])

        project_path = Path("C:\\Project")
        result = installer.get_uproject_path(project_path)
        self.assertEqual(result, expected_path)

    @patch('pathlib.Path.is_dir')
    def test_get_uproject_path_not_directory(self, mock_is_dir):
        """Test get_uproject_path when path is not a directory"""
        mock_is_dir.return_value = False
        result = installer.get_uproject_path(Path("C:\\NotADir"))
        self.assertIsNone(result)

    @patch('pathlib.Path.is_dir')
    @patch('pathlib.Path.rglob')
    def test_get_uproject_path_not_found(self, mock_rglob, mock_is_dir):
        """Test get_uproject_path when .uproject file is not found"""
        mock_is_dir.return_value = True
        mock_rglob.return_value = iter([])

        result = installer.get_uproject_path(Path("C:\\Project"))
        self.assertIsNone(result)


class TestSearchForFile(unittest.TestCase):
    """Tests for search_for_file and related functions"""

    @patch('Installer._search_for_file')
    def test_get_p4_path(self, mock_search):
        """Test get_p4_path calls search_for_file with correct parameters"""
        expected_path = Path("C:\\Perforce\\p4.exe")
        mock_search.return_value = expected_path

        result = installer.get_p4_path()
        mock_search.assert_called_once_with(installer.P4_COMMON_PATHS, "p4.exe")
        self.assertEqual(result, expected_path)

    @patch('Installer._search_for_file')
    def test_get_p4v_path(self, mock_search):
        """Test get_p4v_path calls search_for_file with correct parameters"""
        expected_path = Path("C:\\Perforce\\p4v.exe")
        mock_search.return_value = expected_path

        result = installer.get_p4v_path()
        mock_search.assert_called_once_with(installer.P4V_COMMON_PATHS, "p4v.exe")
        self.assertEqual(result, expected_path)

    @patch('pathlib.Path.exists')
    @patch('Installer.get_root_path')
    def test_search_for_file_found_in_common_paths(self, mock_get_root, mock_exists):
        """Test _search_for_file when file is found in common paths"""
        mock_get_root.return_value = Path("C:\\")
        mock_exists.return_value = True

        common_paths = [os.path.join("Program Files", "Perforce", "p4.exe")]
        result = installer._search_for_file(common_paths, "p4.exe")
        self.assertEqual(result, Path("C:\\Program Files\\Perforce\\p4.exe"))

    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.rglob')
    @patch('Installer.get_root_path')
    def test_search_for_file_found_by_rglob(self, mock_get_root, mock_rglob, mock_exists):
        """Test _search_for_file when file is found by recursive search"""
        mock_exists.return_value = False
        mock_get_root.return_value = Path("C:\\")
        expected_path = Path("C:\\SomeFolder\\p4.exe")
        mock_rglob.return_value = iter([expected_path])

        result = installer._search_for_file([], "p4.exe")
        self.assertEqual(result, expected_path)

    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.rglob')
    @patch('Installer.get_root_path')
    def test_search_for_file_not_found(self, mock_get_root, mock_rglob, mock_exists):
        """Test _search_for_file when file is not found"""
        mock_exists.return_value = False
        mock_get_root.return_value = Path("C:\\")
        mock_rglob.return_value = iter([])

        result = installer._search_for_file([], "nonexistent.exe")
        self.assertIsNone(result)

    @patch('pathlib.Path.exists')
    @patch('Installer.get_root_path')
    def test_search_for_file_multiple_common_paths(self, mock_get_root, mock_exists):
        """Test _search_for_file with multiple common paths, finds in second"""
        mock_get_root.return_value = Path("C:\\")
        # First path doesn't exist, second one does
        mock_exists.side_effect = [False, True]

        common_paths = [
            os.path.join("Program Files", "Perforce", "p4.exe"),
            os.path.join("Program Files (x86)", "Perforce", "p4.exe")
        ]
        result = installer._search_for_file(common_paths, "p4.exe")
        self.assertEqual(result, Path("C:\\Program Files (x86)\\Perforce\\p4.exe"))


class TestP4Config(unittest.TestCase):
    """Tests for P4 configuration functions"""

    @patch('Installer.get_project_path')
    @patch('Installer.get_app_path')
    @patch('pathlib.Path.rglob')
    @patch('pathlib.Path.is_file')
    def test_get_p4_config_path_found(self, mock_is_file, mock_rglob, mock_get_app, mock_get_project):
        """Test get_p4_config_path when config file is found"""
        expected_path = Path("C:\\Project\\.p4config")
        mock_is_file.return_value = True
        mock_rglob.return_value = [expected_path]
        mock_get_project.return_value = Path("C:\\Project")

        result = installer.get_p4_config_path()
        self.assertEqual(result, expected_path)

    @patch('Installer.get_project_path')
    @patch('Installer.get_app_path')
    @patch('pathlib.Path.rglob')
    def test_get_p4_config_path_not_found(self, mock_rglob, mock_get_app, mock_get_project):
        """Test get_p4_config_path when config file is not found"""
        mock_rglob.return_value = []
        mock_get_project.return_value = Path("C:\\Project")

        result = installer.get_p4_config_path()
        self.assertIsNone(result)

    @patch('Installer.subprocess.run')
    def test_get_p4_env_var_success(self, mock_run):
        """Test _get_p4_env_var with successful execution"""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "P4USER=testuser\n"
        mock_run.return_value = mock_result

        result = installer._get_p4_env_var("P4USER")
        self.assertEqual(result, ["P4USER", "testuser"])

    @patch('Installer.subprocess.run')
    def test_get_p4_env_var_failure(self, mock_run):
        """Test _get_p4_env_var with failed execution"""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_run.return_value = mock_result

        result = installer._get_p4_env_var("P4USER")
        self.assertIsNone(result)

    @patch('Installer._get_p4_env_var')
    def test_get_p4_env_vars(self, mock_get_var):
        """Test get_p4_env_vars returns dict with all variables"""
        mock_get_var.side_effect = [
            ["P4USER", "testuser"],
            ["P4PORT", "localhost:1666"],
            ["P4CLIENT", "testclient"]
        ]

        result = installer.get_p4_env_vars()
        self.assertEqual(result, {
            "P4USER": "testuser",
            "P4PORT": "localhost:1666",
            "P4CLIENT": "testclient"
        })

    @patch('Installer._get_p4_env_var')
    def test_get_p4_env_vars_partial(self, mock_get_var):
        """Test get_p4_env_vars when some variables are not available"""
        mock_get_var.side_effect = [
            ["P4USER", "testuser"],
            None,
            ["P4CLIENT", "testclient"]
        ]

        result = installer.get_p4_env_vars()
        self.assertEqual(result, {
            "P4USER": "testuser",
            "P4CLIENT": "testclient"
        })

    @patch('Installer.set_config_file')
    @patch('Installer.get_project_path')
    @patch('Installer.get_app_path')
    def test_create_p4_config(self, mock_get_app, mock_get_project, mock_set_config_file):
        """Test create_p4_config creates config in correct location"""
        project_path = Path("C:\\Project")
        mock_get_app.return_value = Path("C:\\Project\\Tools\\SyncAndBuild")
        mock_get_project.return_value = project_path

        installer.create_p4_config()
        expected_config_path = project_path.joinpath(".p4config")
        mock_set_config_file.assert_called_once_with(expected_config_path, None)

    @patch('builtins.open', new_callable=mock_open, read_data="\n")
    @patch('Installer.get_p4_env_vars')
    def test_set_config_empty_file(self, mock_get_vars, mock_file):
        """Test set_config writes to empty file"""
        mock_get_vars.return_value = {
            "P4USER": "testuser",
            "P4PORT": "localhost:1666"
        }

        config_file = Path("C:\\Project\\.p4config")
        installer.set_config_file(config_file)

        # Verify file was opened for reading and writing
        calls = mock_file().write.call_args_list
        written_content = ''.join([call[0][0] for call in calls])
        self.assertIn("P4USER=testuser", written_content)
        self.assertIn("P4PORT=localhost:1666", written_content)

    @patch('builtins.open', new_callable=mock_open, read_data="P4USER=olduser\nP4PORT=oldport\n")
    @patch('Installer.get_p4_env_vars')
    def test_set_config_existing_file(self, mock_get_vars, mock_file):
        """Test set_config updates existing file"""
        mock_get_vars.return_value = {
            "P4USER": "newuser",
            "P4PORT": "newport"
        }

        config_file = Path("C:\\Project\\.p4config")
        installer.set_config_file(config_file)

        # Verify file was written
        mock_file().writelines.assert_called_once()


class TestSourceFiles(unittest.TestCase):
    """Tests for source file validation"""

    @patch('pathlib.Path.exists')
    @patch('Installer.get_app_path')
    def test_check_source_files_exist_all_present(self, mock_get_app, mock_exists):
        """Test check_source_files_exist when all files exist"""
        mock_get_app.return_value = Path("C:\\Tools\\SyncAndBuild")
        mock_exists.return_value = True

        result = installer.check_source_files_exist()
        self.assertTrue(result)

    @patch('pathlib.Path.exists')
    @patch('Installer.get_app_path')
    def test_check_source_files_exist_missing_file(self, mock_get_app, mock_exists):
        """Test check_source_files_exist when a file is missing"""
        mock_get_app.return_value = Path("C:\\Tools\\SyncAndBuild")
        mock_exists.return_value = False

        result = installer.check_source_files_exist()
        self.assertFalse(result)

    @patch('pathlib.Path.exists')
    def test_check_source_files_exist_custom_path(self, mock_exists):
        """Test check_source_files_exist with custom app_path"""
        custom_path = Path("C:\\Custom\\Path")
        mock_exists.return_value = True

        result = installer.check_source_files_exist(custom_path)
        self.assertTrue(result)


class TestBatFilePath(unittest.TestCase):
    """Tests for get_bat_file_path function"""

    @patch('Installer.get_app_path')
    def test_get_bat_file_path_no_starting_dir(self, mock_get_app):
        """Test get_bat_file_path without starting_dir parameter"""
        mock_get_app.return_value = Path("C:\\Project\\Tools\\SyncAndBuild")
        result = installer.get_bat_file_path()
        expected = Path("C:\\Project\\Tools\\SyncAndBuild\\Source\\sync_and_build.bat")
        self.assertEqual(result, expected)

    @patch('pathlib.Path.rglob')
    def test_get_bat_file_path_with_starting_dir(self, mock_rglob):
        """Test get_bat_file_path with starting_dir parameter"""
        expected_path = Path("C:\\CustomDir\\Source\\sync_and_build.bat")
        mock_rglob.return_value = iter([expected_path])

        starting_dir = Path("C:\\CustomDir")
        result = installer.get_bat_file_path(starting_dir)
        self.assertEqual(result, expected_path)


class TestP4ConfigFileVars(unittest.TestCase):
    """Tests for get_p4_config_file_vars function"""

    @patch('builtins.open', new_callable=mock_open, read_data="P4USER=testuser\nP4PORT=localhost:1666\nP4CLIENT=testclient\n")
    @patch('Installer.get_p4_config_path')
    def test_get_p4_config_file_vars_all_present(self, mock_get_config, mock_file):
        """Test get_p4_config_file_vars with all variables present"""
        config_path = Path("C:\\Project\\.p4config")
        mock_get_config.return_value = config_path

        result = installer.get_p4_config_file_vars()
        self.assertEqual(result, {
            "P4USER": "testuser",
            "P4PORT": "localhost:1666",
            "P4CLIENT": "testclient"
        })

    @patch('builtins.open', new_callable=mock_open, read_data="P4USER=testuser\n")
    def test_get_p4_config_file_vars_partial(self, mock_file):
        """Test get_p4_config_file_vars with partial variables"""
        config_path = Path("C:\\Project\\.p4config")

        result = installer.get_p4_config_file_vars(config_path)
        self.assertEqual(result, {"P4USER": "testuser"})

    @patch('Installer.get_p4_config_path')
    def test_get_p4_config_file_vars_no_config(self, mock_get_config):
        """Test get_p4_config_file_vars when config file doesn't exist"""
        mock_get_config.return_value = None

        result = installer.get_p4_config_file_vars()
        self.assertEqual(result, {})

    @patch('builtins.open', new_callable=mock_open, read_data="# Comment\nP4USER=user1\nOTHER_VAR=value\nP4PORT=port1\n")
    def test_get_p4_config_file_vars_with_other_content(self, mock_file):
        """Test get_p4_config_file_vars ignores non-P4 variables"""
        config_path = Path("C:\\Project\\.p4config")

        result = installer.get_p4_config_file_vars(config_path)
        self.assertEqual(result, {
            "P4USER": "user1",
            "P4PORT": "port1"
        })


class TestP4VCustomToolsPath(unittest.TestCase):
    """Tests for get_p4v_custom_tools_path function"""

    @patch('Installer.os.environ.copy')
    def test_get_p4v_custom_tools_path_success(self, mock_env):
        """Test get_p4v_custom_tools_path with valid USERPROFILE"""
        mock_env.return_value = {"USERPROFILE": "C:\\Users\\TestUser"}

        result = installer.get_p4v_custom_tools_path()
        expected = Path("C:\\Users\\TestUser\\.p4qt\\customtools.xml")
        self.assertEqual(result, expected)

    @patch('Installer.os.environ.copy')
    def test_get_p4v_custom_tools_path_no_userprofile(self, mock_env):
        """Test get_p4v_custom_tools_path when USERPROFILE is not set"""
        mock_env.return_value = {}

        result = installer.get_p4v_custom_tools_path()
        self.assertIsNone(result)


class TestP4Connection(unittest.TestCase):
    """Tests for check_p4_connection function"""

    @patch('Installer.subprocess.run')
    def test_check_p4_connection_success(self, mock_run):
        """Test check_p4_connection when connection is successful"""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_run.return_value = mock_result

        result = installer.check_p4_connection()
        self.assertTrue(result)
        mock_run.assert_called_once()

    @patch('Installer.subprocess.run')
    def test_check_p4_connection_failure(self, mock_run):
        """Test check_p4_connection when connection fails"""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_run.return_value = mock_result

        result = installer.check_p4_connection()
        self.assertFalse(result)

    @patch('Installer.subprocess.run')
    def test_check_p4_connection_timeout(self, mock_run):
        """Test check_p4_connection handles timeout"""
        import subprocess
        mock_run.side_effect = subprocess.TimeoutExpired("p4 info", installer.P4_TIME_OUT)

        with self.assertRaises(subprocess.TimeoutExpired):
            installer.check_p4_connection()


class TestCustomToolDefinition(unittest.TestCase):
    """Tests for is_custom_tool_defined function"""

    def test_is_custom_tool_defined_file_not_exists(self):
        """Test is_custom_tool_defined when file doesn't exist"""
        result = installer.is_custom_tool_defined(Path("C:\\nonexistent.xml"), "TestTool")
        self.assertFalse(result)

    def test_is_custom_tool_defined_none_path(self):
        """Test is_custom_tool_defined with None path"""
        result = installer.is_custom_tool_defined(None, "TestTool")
        self.assertFalse(result)

    @patch('Installer.os.path.isfile')
    @patch('xml.etree.ElementTree.parse')
    def test_is_custom_tool_defined_tool_exists(self, mock_parse, mock_isfile):
        """Test is_custom_tool_defined when tool is defined"""
        mock_isfile.return_value = True

        # Create mock XML structure
        mock_tree = MagicMock()
        mock_root = MagicMock()
        mock_tool_def = MagicMock()
        mock_name = MagicMock()
        mock_name.text = "Auto Sync & Build"
        mock_tool_def.find.return_value = mock_name
        mock_root.findall.return_value = [mock_tool_def]
        mock_tree.getroot.return_value = mock_root
        mock_parse.return_value = mock_tree

        result = installer.is_custom_tool_defined(Path("C:\\test.xml"), "Auto Sync & Build")
        self.assertTrue(result)

    @patch('Installer.os.path.isfile')
    @patch('xml.etree.ElementTree.parse')
    def test_is_custom_tool_defined_tool_not_exists(self, mock_parse, mock_isfile):
        """Test is_custom_tool_defined when tool is not defined"""
        mock_isfile.return_value = True

        mock_tree = MagicMock()
        mock_root = MagicMock()
        mock_tool_def = MagicMock()
        mock_name = MagicMock()
        mock_name.text = "Different Tool"
        mock_tool_def.find.return_value = mock_name
        mock_root.findall.return_value = [mock_tool_def]
        mock_tree.getroot.return_value = mock_root
        mock_parse.return_value = mock_tree

        result = installer.is_custom_tool_defined(Path("C:\\test.xml"), "Auto Sync & Build")
        self.assertFalse(result)

    @patch('Installer.os.path.isfile')
    @patch('xml.etree.ElementTree.parse')
    def test_is_custom_tool_defined_parse_error(self, mock_parse, mock_isfile):
        """Test is_custom_tool_defined handles XML parse errors"""
        import xml.etree.ElementTree as Et
        mock_isfile.return_value = True
        mock_parse.side_effect = Et.ParseError("Invalid XML")

        result = installer.is_custom_tool_defined(Path("C:\\test.xml"), "TestTool")
        self.assertFalse(result)


class TestDefineCustomTool(unittest.TestCase):
    """Tests for define_custom_tool function"""

    @patch('xml.etree.ElementTree.ElementTree.write')
    @patch('xml.etree.ElementTree.indent')
    @patch('Installer.os.path.isfile')
    @patch('Installer.os.makedirs')
    def test_define_custom_tool_new_file(self, mock_makedirs, mock_isfile, mock_indent, mock_write):
        """Test define_custom_tool creates new XML file"""
        mock_isfile.return_value = False

        result = installer.define_custom_tool(
            Path("C:\\Users\\Test\\.p4qt\\customtools.xml"),
            "Auto Sync & Build",
            "C:\\Tools\\sync_and_build.bat",
            "C:\\Project"
        )

        self.assertTrue(result)
        mock_makedirs.assert_called_once()
        mock_write.assert_called_once()

    @patch('xml.etree.ElementTree.parse')
    @patch('Installer.os.path.isfile')
    def test_define_custom_tool_existing_file(self, mock_isfile, mock_parse):
        """Test define_custom_tool appends to existing XML file"""
        import xml.etree.ElementTree as Et
        mock_isfile.return_value = True

        # Create a real XML element instead of MagicMock
        root = Et.Element("CustomToolDefList")
        root.set("varName", "customtooldeflist")
        mock_tree = MagicMock()
        mock_tree.getroot.return_value = root
        mock_parse.return_value = mock_tree

        result = installer.define_custom_tool(
            Path("C:\\Users\\Test\\.p4qt\\customtools.xml"),
            "Auto Sync & Build",
            "C:\\Tools\\sync_and_build.bat",
            "C:\\Project"
        )

        self.assertTrue(result)
        mock_tree.write.assert_called_once()


class TestFixExistingCustomTool(unittest.TestCase):
    """Tests for fix_existing_custom_tool function"""

    @patch('Installer.define_custom_tool')
    @patch('xml.etree.ElementTree.parse')
    def test_fix_existing_custom_tool(self, mock_parse, mock_define):
        """Test fix_existing_custom_tool removes old and creates new"""
        import xml.etree.ElementTree as Et

        # Create real XML elements
        root = Et.Element("CustomToolDefList")
        tool_def = Et.SubElement(root, "CustomToolDef")
        definition = Et.SubElement(tool_def, "Definition")
        Et.SubElement(definition, "Name").text = "Auto Sync & Build"

        mock_tree = MagicMock()
        mock_tree.getroot.return_value = root
        mock_parse.return_value = mock_tree
        mock_define.return_value = True

        result = installer.fix_existing_custom_tool(
            Path("C:\\Users\\Test\\.p4qt\\customtools.xml"),
            "Auto Sync & Build",
            "C:\\Tools\\sync_and_build.bat",
            "C:\\Project"
        )

        self.assertTrue(result)
        # Verify the tool was removed (root should have no children after removal)
        self.assertEqual(len(list(root)), 0)
        mock_tree.write.assert_called_once()
        mock_define.assert_called_once()


class TestEdgeCases(unittest.TestCase):
    """Tests for edge cases and error handling"""

    @patch('Installer.subprocess.run')
    def test_get_p4_env_var_timeout(self, mock_run):
        """Test _get_p4_env_var handles timeout exception"""
        import subprocess
        mock_run.side_effect = subprocess.TimeoutExpired("p4 set", installer.P4_TIME_OUT)

        with self.assertRaises(subprocess.TimeoutExpired):
            installer._get_p4_env_var("P4USER")

    @patch('Installer.subprocess.run')
    def test_get_p4_env_var_malformed_output(self, mock_run):
        """Test _get_p4_env_var with malformed output"""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "MALFORMED_OUTPUT_NO_EQUALS"
        mock_run.return_value = mock_result

        with self.assertRaises(ValueError):
            installer._get_p4_env_var("P4USER")

    @patch('pathlib.Path.rglob')
    def test_get_uproject_path_multiple_files(self, mock_rglob):
        """Test get_uproject_path returns first when multiple .uproject files exist"""
        first_project = Path("C:\\Project\\Game1.uproject")
        second_project = Path("C:\\Project\\Game2.uproject")
        mock_rglob.return_value = iter([first_project, second_project])

        with patch('pathlib.Path.is_dir', return_value=True):
            result = installer.get_uproject_path(Path("C:\\Project"))
            self.assertEqual(result, first_project)

    @patch('builtins.open', new_callable=mock_open, read_data="P4USER=user\nP4PORT=port\n")
    @patch('Installer.get_p4_env_vars')
    def test_set_config_file_adds_missing_vars(self, mock_get_vars, mock_file):
        """Test set_config_file adds variables not in existing file"""
        mock_get_vars.return_value = {
            "P4USER": "newuser",
            "P4PORT": "newport",
            "P4CLIENT": "newclient"
        }

        config_file = Path("C:\\Project\\.p4config")
        installer.set_config_file(config_file)

        # File should be updated
        mock_file().writelines.assert_called_once()

    @patch('builtins.open', new_callable=mock_open, read_data="P4USER=user\n# Comment line\nP4PORT=port\nOther content\n")
    @patch('Installer.get_p4_env_vars')
    def test_set_config_file_preserves_non_p4_lines(self, mock_get_vars, mock_file):
        """Test set_config_file preserves lines that aren't P4 variables (covers line 205)"""
        mock_get_vars.return_value = {
            "P4USER": "newuser",
            "P4PORT": "newport"
        }

        config_file = Path("C:\\Project\\.p4config")
        installer.set_config_file(config_file)

        # Verify writelines was called (non-P4 lines should be preserved)
        mock_file().writelines.assert_called_once()


class TestToolInstallerMethods(unittest.TestCase):
    """Tests for ToolInstaller methods that can be tested without full UI"""

    def test_tool_installer_init(self):
        """Test ToolInstaller initialization"""
        tool_installer = self._create_tool_installer()

        self.assertEqual(tool_installer._app_path, Path("C:\\Tools\\SyncAndBuild"))
        self.assertEqual(tool_installer._project_path, Path("C:\\Project"))
        self.assertEqual(tool_installer._uproject_path, Path("C:\\Project\\Game.uproject"))

    def _create_tool_installer(self):
        """Helper method to create a ToolInstaller instance with mocked UI"""
        def fake_configure_styles(self_inst):
            self_inst.ROOT_BG = "#27282c"
            self_inst.HEADER_BG = "#1e1f23"
            self_inst.HEADER_FG = "#e2e8f0"
            self_inst.LOG_BG = "#2f3036"
            self_inst.SUCCESS_FONT_COLOR = "#4ade80"
            self_inst.ERROR_FONT_COLOR = "#f87171"
            self_inst.WARNING_FONT_COLOR = "#fbbf24"
            self_inst.HEADER_FONT_COLOR = "#e2e8f0"
            self_inst.DIM_FONT_COLOR = "#94a3b8"
            self_inst.HYPERLINK_COLOR = "#60a5fa"

        with patch('Installer.ToolInstaller._build_ui'), \
             patch('Installer.ToolInstaller._configure_styles', fake_configure_styles), \
             patch('Installer.get_app_path', return_value=Path("C:\\Tools\\SyncAndBuild")), \
             patch('Installer.get_project_path', return_value=Path("C:\\Project")), \
             patch('Installer.get_uproject_path', return_value=Path("C:\\Project\\Game.uproject")), \
             patch('tkinter.Tk'):
            tool_installer = installer.ToolInstaller()
            # Mock UI components that methods use
            tool_installer.status_text = MagicMock()
            tool_installer.root = MagicMock()
            return tool_installer

    def test_check_project_structure_success(self):
        """Test _check_project_structure when all checks pass"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'check_source_files_exist', return_value=True):
            result = tool_installer._check_project_structure()
            self.assertTrue(result)

    def test_check_project_structure_missing_source_files(self):
        """Test _check_project_structure when source files are missing"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'check_source_files_exist', return_value=False):
            result = tool_installer._check_project_structure()
            self.assertFalse(result)

    def test_check_project_structure_no_project_path(self):
        """Test _check_project_structure when project path is None"""
        tool_installer = self._create_tool_installer()
        tool_installer._project_path = None

        with patch.object(installer, 'check_source_files_exist', return_value=True):
            result = tool_installer._check_project_structure()
            self.assertFalse(result)

    def test_check_project_structure_no_uproject(self):
        """Test _check_project_structure when .uproject file is missing"""
        tool_installer = self._create_tool_installer()
        tool_installer._uproject_path = None

        with patch.object(installer, 'check_source_files_exist', return_value=True):
            result = tool_installer._check_project_structure()
            self.assertFalse(result)

    def test_check_p4_success(self):
        """Test _check_p4 when all P4 checks pass"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'get_p4_path', return_value=Path("C:\\p4.exe")), \
             patch.object(installer, 'get_p4v_path', return_value=Path("C:\\p4v.exe")), \
             patch.object(installer, 'check_p4_connection', return_value=True):
            result = tool_installer._check_p4()
            self.assertTrue(result)

    def test_check_p4_no_p4_exe(self):
        """Test _check_p4 when p4.exe is not found"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'get_p4_path', return_value=None):
            result = tool_installer._check_p4()
            self.assertFalse(result)

    def test_check_p4_no_connection(self):
        """Test _check_p4 when p4 connection fails"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'get_p4_path', return_value=Path("C:\\p4.exe")), \
             patch.object(installer, 'check_p4_connection', return_value=False):
            result = tool_installer._check_p4()
            self.assertFalse(result)

    def test_check_p4_no_p4v(self):
        """Test _check_p4 when p4v is not found"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'get_p4_path', return_value=Path("C:\\p4.exe")), \
             patch.object(installer, 'get_p4v_path', return_value=None), \
             patch.object(installer, 'check_p4_connection', return_value=True):
            result = tool_installer._check_p4()
            self.assertFalse(result)

    def test_setup_custom_tool_no_userprofile(self):
        """Test _setup_custom_tool when USERPROFILE is not set"""
        tool_installer = self._create_tool_installer()

        with patch.object(installer, 'get_p4v_custom_tools_path', return_value=None):
            result = tool_installer._setup_custom_tool()
            self.assertFalse(result)

    def test_setup_custom_tool_already_defined(self):
        """Test _setup_custom_tool when tool is already defined"""
        tool_installer = self._create_tool_installer()
        custom_tools_path = Path("C:\\Users\\Test\\.p4qt\\customtools.xml")

        with patch.object(installer, 'get_p4v_custom_tools_path', return_value=custom_tools_path), \
             patch.object(installer, 'is_custom_tool_defined', return_value=True), \
             patch.object(installer, 'fix_existing_custom_tool', return_value=True), \
             patch.object(installer, 'get_bat_file_path', return_value=Path("C:\\bat.bat")):
            result = tool_installer._setup_custom_tool()
            self.assertTrue(result)

    def test_setup_custom_tool_not_defined(self):
        """Test _setup_custom_tool when tool needs to be created"""
        tool_installer = self._create_tool_installer()
        custom_tools_path = Path("C:\\Users\\Test\\.p4qt\\customtools.xml")

        with patch.object(installer, 'get_p4v_custom_tools_path', return_value=custom_tools_path), \
             patch.object(installer, 'is_custom_tool_defined', return_value=False), \
             patch.object(installer, 'define_custom_tool', return_value=True), \
             patch.object(installer, 'get_bat_file_path', return_value=Path("C:\\bat.bat")):
            result = tool_installer._setup_custom_tool()
            self.assertTrue(result)

    @patch('builtins.open', new_callable=mock_open)
    def test_clean_log_file(self, mock_file):
        """Test _clean_log_file clears the log file"""
        tool_installer = self._create_tool_installer()
        tool_installer._clean_log_file()

        mock_file.assert_called_once()
        mock_file().write.assert_called_once_with("")

    @patch('builtins.open', new_callable=mock_open)
    def test_flush_to_log_file_with_buffer(self, mock_file):
        """Test _flush_to_log_file writes buffered content"""
        tool_installer = self._create_tool_installer()
        tool_installer._buffered_log = "Test log content"
        tool_installer._flush_to_log_file()

        mock_file().write.assert_called_once_with("Test log content")
        self.assertEqual(tool_installer._buffered_log, "")

    def test_flush_to_log_file_empty_buffer(self):
        """Test _flush_to_log_file does nothing when buffer is empty"""
        tool_installer = self._create_tool_installer()
        tool_installer._buffered_log = ""

        # Should return early without opening file
        with patch('builtins.open', new_callable=mock_open) as mock_file:
            tool_installer._flush_to_log_file()
            mock_file.assert_not_called()


class TestToolInstallerLogging(unittest.TestCase):
    """Tests for ToolInstaller logging and workflow methods"""

    def _create_tool_installer(self):
        """Helper method to create a ToolInstaller instance with mocked UI"""
        def fake_configure_styles(self_inst):
            self_inst.ROOT_BG = "#27282c"
            self_inst.HEADER_BG = "#1e1f23"
            self_inst.HEADER_FG = "#e2e8f0"
            self_inst.LOG_BG = "#2f3036"
            self_inst.SUCCESS_FONT_COLOR = "#4ade80"
            self_inst.ERROR_FONT_COLOR = "#f87171"
            self_inst.WARNING_FONT_COLOR = "#fbbf24"
            self_inst.HEADER_FONT_COLOR = "#e2e8f0"
            self_inst.DIM_FONT_COLOR = "#94a3b8"
            self_inst.HYPERLINK_COLOR = "#60a5fa"

        with patch('Installer.ToolInstaller._build_ui'), \
             patch('Installer.ToolInstaller._configure_styles', fake_configure_styles), \
             patch('Installer.get_app_path', return_value=Path("C:\\Tools\\SyncAndBuild")), \
             patch('Installer.get_project_path', return_value=Path("C:\\Project")), \
             patch('Installer.get_uproject_path', return_value=Path("C:\\Project\\Game.uproject")), \
             patch('tkinter.Tk'):
            ti = installer.ToolInstaller()
            ti.status_text = MagicMock()
            ti.root = MagicMock()
            return ti

    def test_log_appends_to_buffer(self):
        """Test _log appends message to _buffered_log"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._log("  ▶ Test message", log_type=installer.LogType.HEADER)

        self.assertIn("HEADER:", ti._buffered_log)
        self.assertIn("Test message", ti._buffered_log)

    def test_log_strips_prefix_correctly(self):
        """Test _log strips the 4-char prefix from message for log file"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._info_log("Hello")

        # message[4:] strips the "  → " prefix, leaving just "Hello"
        self.assertIn("INFO: Hello", ti._buffered_log)
        self.assertNotIn("→", ti._buffered_log)

    def test_header_log(self):
        """Test _header_log formats with header prefix"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._header_log("Step 1")

        self.assertIn("HEADER:", ti._buffered_log)
        ti.status_text.insert.assert_called()

    def test_error_log(self):
        """Test _error_log formats with error prefix"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._error_log("Something failed")

        self.assertIn("ERROR:", ti._buffered_log)
        self.assertIn("Something failed", ti._buffered_log)

    def test_warning_log(self):
        """Test _warning_log formats with warning prefix"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._warning_log("Careful")

        self.assertIn("WARNING:", ti._buffered_log)

    def test_success_log(self):
        """Test _success_log formats with success prefix"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._success_log("Done")

        self.assertIn("SUCCESS:", ti._buffered_log)

    def test_dim_log(self):
        """Test _dim_log formats with dim prefix"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._dim_log("Author info")

        self.assertIn("DIM:", ti._buffered_log)

    def test_add_link_buffers_to_log(self):
        """Test _add_link writes link info to buffered log"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._add_link("Click here\n", "https://example.com")

        self.assertIn("LINK:", ti._buffered_log)
        self.assertIn("https://example.com", ti._buffered_log)
        self.assertIn("Click here", ti._buffered_log)

    def test_add_link_configures_tag(self):
        """Test _add_link configures a clickable tag on status_text"""
        ti = self._create_tool_installer()

        ti._add_link("Test link\n", "https://example.com")

        ti.status_text.tag_configure.assert_called()
        ti.status_text.tag_bind.assert_called()
        ti.status_text.insert.assert_called()

    def test_finish_success(self):
        """Test _finish with success=True logs completion message"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._finish(success=True)

        self.assertIn("Installation Completed", ti._buffered_log)

    def test_finish_failure(self):
        """Test _finish with success=False logs error message"""
        ti = self._create_tool_installer()
        ti._buffered_log = ""

        ti._finish(success=False)

        self.assertIn("Incomplete Installation", ti._buffered_log)

    @patch('builtins.open', new_callable=mock_open)
    def test_install_all_steps_pass(self, _):
        """Test install method when all steps succeed"""
        ti = self._create_tool_installer()

        with patch.object(ti, '_check_project_structure', return_value=True), \
             patch.object(ti, '_check_p4', return_value=True), \
             patch.object(ti, '_setup_p4_config', return_value=True), \
             patch.object(ti, '_setup_custom_tool', return_value=True), \
             patch.object(ti, '_finish') as mock_finish:
            ti.install()

        mock_finish.assert_called_once_with(success=True)

    @patch('builtins.open', new_callable=mock_open)
    def test_install_step_fails_early(self, _):
        """Test install method stops at first failing step"""
        ti = self._create_tool_installer()

        with patch.object(ti, '_check_project_structure', return_value=False), \
             patch.object(ti, '_finish') as mock_finish:
            ti.install()

        mock_finish.assert_called_once_with(success=False)

    @patch('builtins.open', new_callable=mock_open)
    def test_install_p4_check_fails(self, _):
        """Test install method stops when p4 check fails"""
        ti = self._create_tool_installer()

        with patch.object(ti, '_check_project_structure', return_value=True), \
             patch.object(ti, '_check_p4', return_value=False), \
             patch.object(ti, '_finish') as mock_finish:
            ti.install()

        mock_finish.assert_called_once_with(success=False)

    def test_on_install_clicked(self):
        """Test _on_install_clicked disables button and calls install"""
        ti = self._create_tool_installer()
        ti.install_btn = MagicMock()

        with patch.object(ti, 'install'):
            ti._on_install_clicked()

        ti.install_btn.configure.assert_called_once_with(state='disabled')
        ti.status_text.delete.assert_called_once()


class TestSetConfigFileNewFile(unittest.TestCase):
    """Tests for set_config_file when file doesn't exist"""

    @patch('pathlib.Path.touch')
    @patch('pathlib.Path.mkdir')
    @patch('pathlib.Path.exists', return_value=False)
    @patch('builtins.open', new_callable=mock_open)
    def test_set_config_file_creates_new_file(self, mock_file, mock_exists, mock_mkdir, mock_touch):
        """Test set_config_file creates file when it doesn't exist"""
        variables = {"P4USER": "testuser", "P4PORT": "localhost:1666"}

        installer.set_config_file(Path("C:\\Project\\.p4config"), variables)

        mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)
        mock_touch.assert_called_once()

    @patch('builtins.open', new_callable=mock_open, read_data="")
    @patch('pathlib.Path.exists', return_value=True)
    def test_set_config_file_handles_empty_existing_file(self, mock_exists, mock_file):
        """Test set_config_file handles empty existing file"""
        variables = {"P4USER": "testuser"}

        installer.set_config_file(Path("C:\\Project\\.p4config"), variables)

        calls = mock_file().write.call_args_list
        written_content = ''.join([call[0][0] for call in calls])
        self.assertIn("P4USER=testuser", written_content)


if __name__ == '__main__':
    unittest.main()
