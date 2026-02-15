import unittest
import os
import sys
from unittest.mock import patch, MagicMock, mock_open
from pathlib import Path

# Add parent directory to path to import the module
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import SynchAndBuildInstaller as installer


class TestPathGetters(unittest.TestCase):
    """Tests for path getter functions"""

    def test_get_root_path(self):
        """Test that get_root_path returns C:\\ """
        result = installer.get_root_path()
        self.assertEqual(result, Path("C:\\"))
        self.assertIsInstance(result, Path)

    @patch('SynchAndBuildInstaller.sys')
    @patch('SynchAndBuildInstaller.os.path.dirname')
    @patch('SynchAndBuildInstaller.os.path.realpath')
    def test_get_app_path_with_location(self, mock_realpath, mock_dirname, mock_sys):
        """Test get_app_path with a valid location parameter"""
        test_location = "C:\\TestFolder"
        with patch('pathlib.Path.is_dir', return_value=True):
            result = installer.get_app_path(test_location)
            self.assertEqual(result, Path(test_location))

    @patch('SynchAndBuildInstaller.sys')
    @patch('SynchAndBuildInstaller.os.path.dirname')
    @patch('SynchAndBuildInstaller.os.path.realpath')
    def test_get_app_path_frozen(self, mock_realpath, mock_dirname, mock_sys):
        """Test get_app_path when application is frozen (exe)"""
        mock_sys.frozen = True
        mock_sys.executable = "C:\\App\\tool.exe"
        result = installer.get_app_path()
        self.assertEqual(result, Path("C:\\App\\tool.exe"))

    @patch('SynchAndBuildInstaller.sys')
    @patch('SynchAndBuildInstaller.os.path.dirname')
    @patch('SynchAndBuildInstaller.os.path.realpath')
    def test_get_app_path_not_frozen(self, mock_realpath, mock_dirname, mock_sys):
        """Test get_app_path when application is not frozen (running as script)"""
        mock_sys.frozen = False
        mock_realpath.return_value = "C:\\Scripts\\SynchAndBuildInstaller.py"
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

    @patch('SynchAndBuildInstaller._search_for_file')
    def test_get_p4_path(self, mock_search):
        """Test get_p4_path calls search_for_file with correct parameters"""
        expected_path = Path("C:\\Perforce\\p4.exe")
        mock_search.return_value = expected_path

        result = installer.get_p4_path()
        mock_search.assert_called_once_with(installer.P4_COMMON_PATHS, "p4.exe")
        self.assertEqual(result, expected_path)

    @patch('SynchAndBuildInstaller._search_for_file')
    def test_get_p4v_path(self, mock_search):
        """Test get_p4v_path calls search_for_file with correct parameters"""
        expected_path = Path("C:\\Perforce\\p4v.exe")
        mock_search.return_value = expected_path

        result = installer.get_p4v_path()
        mock_search.assert_called_once_with(installer.P4V_COMMON_PATHS, "p4v.exe")
        self.assertEqual(result, expected_path)

    @patch('SynchAndBuildInstaller.shutil.which')
    def test_search_for_file_found_by_which(self, mock_which):
        """Test search_for_file when file is found by shutil.which"""
        mock_which.return_value = "C:\\System32\\p4.exe"
        result = installer._search_for_file([], "p4.exe")
        self.assertEqual(result, Path("C:\\System32\\p4.exe"))

    @patch('SynchAndBuildInstaller.shutil.which')
    @patch('pathlib.Path.exists')
    @patch('SynchAndBuildInstaller.get_root_path')
    def test_search_for_file_found_in_common_paths(self, mock_get_root, mock_exists, mock_which):
        """Test search_for_file when file is found in common paths"""
        mock_which.return_value = None
        mock_get_root.return_value = Path("C:\\")
        mock_exists.return_value = True

        common_paths = [os.path.join("Program Files", "Perforce", "p4.exe")]
        result = installer._search_for_file(common_paths, "p4.exe")
        self.assertEqual(result, Path("C:\\Program Files\\Perforce\\p4.exe"))

    @patch('SynchAndBuildInstaller.shutil.which')
    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.rglob')
    @patch('SynchAndBuildInstaller.get_root_path')
    def test_search_for_file_found_by_rglob(self, mock_get_root, mock_rglob, mock_exists, mock_which):
        """Test search_for_file when file is found by recursive search"""
        mock_which.return_value = None
        mock_exists.return_value = False
        mock_get_root.return_value = Path("C:\\")
        expected_path = Path("C:\\SomeFolder\\p4.exe")
        mock_rglob.return_value = iter([expected_path])

        result = installer._search_for_file([], "p4.exe")
        self.assertEqual(result, expected_path)

    @patch('SynchAndBuildInstaller.shutil.which')
    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.rglob')
    @patch('SynchAndBuildInstaller.get_root_path')
    def test_search_for_file_not_found(self, mock_get_root, mock_rglob, mock_exists, mock_which):
        """Test search_for_file when file is not found"""
        mock_which.return_value = None
        mock_exists.return_value = False
        mock_get_root.return_value = Path("C:\\")
        mock_rglob.return_value = iter([])

        result = installer._search_for_file([], "nonexistent.exe")
        self.assertIsNone(result)


class TestP4Config(unittest.TestCase):
    """Tests for P4 configuration functions"""

    @patch('SynchAndBuildInstaller.get_project_path')
    @patch('SynchAndBuildInstaller.get_app_path')
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

    @patch('SynchAndBuildInstaller.get_project_path')
    @patch('SynchAndBuildInstaller.get_app_path')
    @patch('pathlib.Path.rglob')
    def test_get_p4_config_path_not_found(self, mock_rglob, mock_get_app, mock_get_project):
        """Test get_p4_config_path when config file is not found"""
        mock_rglob.return_value = []
        mock_get_project.return_value = Path("C:\\Project")

        result = installer.get_p4_config_path()
        self.assertIsNone(result)

    @patch('SynchAndBuildInstaller.subprocess.run')
    def test_get_p4_env_var_success(self, mock_run):
        """Test _get_p4_env_var with successful execution"""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "P4USER=testuser\n"
        mock_run.return_value = mock_result

        result = installer._get_p4_env_var("P4USER")
        self.assertEqual(result, ["P4USER", "testuser"])

    @patch('SynchAndBuildInstaller.subprocess.run')
    def test_get_p4_env_var_failure(self, mock_run):
        """Test _get_p4_env_var with failed execution"""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_run.return_value = mock_result

        result = installer._get_p4_env_var("P4USER")
        self.assertIsNone(result)

    @patch('SynchAndBuildInstaller._get_p4_env_var')
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

    @patch('SynchAndBuildInstaller._get_p4_env_var')
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

    @patch('SynchAndBuildInstaller.set_config_file')
    @patch('SynchAndBuildInstaller.get_project_path')
    @patch('SynchAndBuildInstaller.get_app_path')
    def test_create_p4_config(self, mock_get_app, mock_get_project, mock_set_config_file):
        """Test create_p4_config creates config in correct location"""
        project_path = Path("C:\\Project")
        mock_get_app.return_value = Path("C:\\Project\\Tools\\SyncAndBuild")
        mock_get_project.return_value = project_path

        installer.create_p4_config()
        expected_config_path = project_path.joinpath(".p4config")
        mock_set_config_file.assert_called_once_with(expected_config_path, None)

    @patch('builtins.open', new_callable=mock_open, read_data="\n")
    @patch('SynchAndBuildInstaller.get_p4_env_vars')
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
    @patch('SynchAndBuildInstaller.get_p4_env_vars')
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
    @patch('SynchAndBuildInstaller.get_app_path')
    def test_check_source_files_exist_all_present(self, mock_get_app, mock_exists):
        """Test check_source_files_exist when all files exist"""
        mock_get_app.return_value = Path("C:\\Tools\\SyncAndBuild")
        mock_exists.return_value = True

        result = installer.check_source_files_exist()
        self.assertTrue(result)

    @patch('pathlib.Path.exists')
    @patch('SynchAndBuildInstaller.get_app_path')
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

if __name__ == '__main__':
    unittest.main()
