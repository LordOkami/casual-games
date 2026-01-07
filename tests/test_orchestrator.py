#!/usr/bin/env python3
"""
Autonomous Game Test Orchestrator
Runs automated tests on all Godot games in the collection
"""

import os
import sys
import json
import subprocess
import shutil
import time
import argparse
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Any
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import tempfile

# Configuration
GAMES_DIR = Path(__file__).parent.parent
TEST_FRAMEWORK_DIR = GAMES_DIR / "_test_framework"
TEST_TIMEOUT = 60  # seconds per game
GODOT_CMD = os.environ.get("GODOT_CMD", "godot")


@dataclass
class TestResult:
    """Result of a single game test"""
    game_name: str
    game_path: str
    passed: bool
    duration: float
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    fps_avg: float = 0.0
    actions_performed: int = 0
    screenshots: int = 0
    stdout: str = ""
    stderr: str = ""
    exit_code: int = 0
    timestamp: str = ""

    def to_dict(self) -> Dict:
        return asdict(self)


@dataclass
class TestReport:
    """Complete test report for all games"""
    total_games: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    total_duration: float = 0.0
    results: List[TestResult] = field(default_factory=list)
    timestamp: str = ""
    godot_version: str = ""

    def to_dict(self) -> Dict:
        return {
            "summary": {
                "total_games": self.total_games,
                "passed": self.passed,
                "failed": self.failed,
                "skipped": self.skipped,
                "pass_rate": f"{(self.passed / max(1, self.total_games)) * 100:.1f}%",
                "total_duration": f"{self.total_duration:.2f}s"
            },
            "godot_version": self.godot_version,
            "timestamp": self.timestamp,
            "results": [r.to_dict() for r in self.results]
        }


class GameDiscovery:
    """Discovers and analyzes games in the collection"""

    GAME_PATTERNS = {
        "tap": ["flappy", "whack", "tap", "click", "pop", "fidget"],
        "swipe": ["snake", "2048", "fruit", "slice", "tetris"],
        "drag": ["breakout", "pong", "paddle", "doodle"],
        "gravity": ["gravity", "flip", "jump", "bounce"],
        "puzzle": ["memory", "match", "puzzle", "pin", "pull"]
    }

    @staticmethod
    def discover_games() -> List[Dict[str, Any]]:
        """Find all game projects in the collection"""
        games = []

        for item in sorted(GAMES_DIR.iterdir()):
            if not item.is_dir():
                continue
            if item.name.startswith("_") or item.name.startswith("."):
                continue
            if not item.name[0].isdigit():
                continue

            project_file = item / "project.godot"
            if not project_file.exists():
                continue

            game_info = GameDiscovery._analyze_game(item)
            games.append(game_info)

        return games

    @staticmethod
    def _analyze_game(game_dir: Path) -> Dict[str, Any]:
        """Analyze a game to determine its type and mechanics"""
        name = game_dir.name
        game_type = "tap"  # default

        # Detect game type from name
        name_lower = name.lower()
        for gtype, patterns in GameDiscovery.GAME_PATTERNS.items():
            for pattern in patterns:
                if pattern in name_lower:
                    game_type = gtype
                    break

        # Check for game.gd to analyze mechanics
        game_gd = game_dir / "scenes" / "game.gd"
        mechanics = []
        if game_gd.exists():
            content = game_gd.read_text()
            if "InputEventScreenTouch" in content:
                mechanics.append("touch")
            if "swipe" in content.lower():
                mechanics.append("swipe")
            if "drag" in content.lower():
                mechanics.append("drag")
            if "gravity" in content.lower():
                mechanics.append("gravity")

        return {
            "name": name,
            "path": str(game_dir),
            "type": game_type,
            "mechanics": mechanics,
            "has_menu": (game_dir / "scenes" / "main_menu.tscn").exists(),
            "has_game_manager": (game_dir / "autoload" / "game_manager.gd").exists(),
            "has_audio": (game_dir / "autoload" / "audio_manager.gd").exists()
        }


class TestAgent:
    """Agent that runs tests on a single game"""

    def __init__(self, game_info: Dict[str, Any], config: Dict[str, Any] = None):
        self.game_info = game_info
        self.config = config or {}
        self.temp_dir: Optional[Path] = None

    def prepare(self) -> bool:
        """Prepare the game for testing by injecting test framework"""
        game_path = Path(self.game_info["path"])

        # Create temp directory for test files
        self.temp_dir = Path(tempfile.mkdtemp(prefix="godot_test_"))

        # Copy test agent to game's autoload
        test_agent_src = TEST_FRAMEWORK_DIR / "autoload" / "test_agent.gd"
        if not test_agent_src.exists():
            print(f"[ERROR] Test agent not found: {test_agent_src}")
            return False

        test_agent_dst = game_path / "autoload" / "test_agent.gd"
        shutil.copy(test_agent_src, test_agent_dst)

        # Create test config
        test_config = {
            "auto_start": True,
            "auto_exit": True,
            "game_type": self.game_info["type"],
            "timeout": TEST_TIMEOUT,
            "scenarios": ["menu_navigation", self.game_info["type"], "stress_test"]
        }

        config_path = game_path / "test_config.json"
        with open(config_path, "w") as f:
            json.dump(test_config, f, indent=2)

        # Modify project.godot to include test agent as autoload
        self._inject_autoload(game_path / "project.godot")

        return True

    def _inject_autoload(self, project_file: Path) -> None:
        """Add test agent to project autoloads"""
        content = project_file.read_text()

        # Check if already injected
        if "TestAgent" in content:
            return

        # Find autoload section or create it
        if "[autoload]" in content:
            # Add to existing autoloads
            content = content.replace(
                "[autoload]\n",
                '[autoload]\n\nTestAgent="*res://autoload/test_agent.gd"\n'
            )
        else:
            # Add autoload section
            content += '\n[autoload]\n\nTestAgent="*res://autoload/test_agent.gd"\n'

        project_file.write_text(content)

    def run(self) -> TestResult:
        """Run tests on the game"""
        game_path = Path(self.game_info["path"])
        start_time = time.time()

        result = TestResult(
            game_name=self.game_info["name"],
            game_path=str(game_path),
            passed=False,
            duration=0,
            timestamp=datetime.now().isoformat()
        )

        try:
            # Run Godot in headless mode
            cmd = [
                GODOT_CMD,
                "--headless",
                "--path", str(game_path),
                "--quit-after", str(TEST_TIMEOUT)
            ]

            print(f"[TEST] Running: {self.game_info['name']}")

            process = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=TEST_TIMEOUT + 10,
                cwd=str(game_path)
            )

            result.stdout = process.stdout
            result.stderr = process.stderr
            result.exit_code = process.returncode

            # Parse test results from game output
            self._parse_results(result, game_path)

            # Check for success indicators
            if process.returncode == 0:
                result.passed = True
            elif "PASSED: true" in process.stdout or "PASSED: True" in process.stdout:
                result.passed = True

            # Check for errors in output
            if "ERROR" in process.stderr:
                result.errors.append("Godot errors in stderr")
                result.passed = False

        except subprocess.TimeoutExpired:
            result.errors.append(f"Test timed out after {TEST_TIMEOUT}s")

        except FileNotFoundError:
            result.errors.append(f"Godot not found at: {GODOT_CMD}")

        except Exception as e:
            result.errors.append(f"Exception: {str(e)}")

        finally:
            result.duration = time.time() - start_time
            self.cleanup()

        return result

    def _parse_results(self, result: TestResult, game_path: Path) -> None:
        """Parse test results from game output files"""
        results_file = game_path / "test_results.json"

        # Check user:// location (varies by OS)
        user_dir = self._get_godot_user_dir(game_path)
        if user_dir:
            alt_results = user_dir / "test_results.json"
            if alt_results.exists():
                results_file = alt_results

        if results_file.exists():
            try:
                with open(results_file) as f:
                    data = json.load(f)
                    result.passed = data.get("passed", False)
                    result.errors.extend(data.get("errors", []))
                    result.fps_avg = data.get("fps_avg", 0)
                    result.actions_performed = data.get("actions", 0)
                    result.screenshots = data.get("screenshots", 0)
            except Exception as e:
                result.warnings.append(f"Could not parse results: {e}")

    def _get_godot_user_dir(self, game_path: Path) -> Optional[Path]:
        """Get the Godot user:// directory for this game"""
        # Parse project name from project.godot
        project_file = game_path / "project.godot"
        if not project_file.exists():
            return None

        content = project_file.read_text()
        project_name = None
        for line in content.split("\n"):
            if line.startswith("config/name="):
                project_name = line.split("=", 1)[1].strip().strip('"')
                break

        if not project_name:
            project_name = game_path.name

        # Godot user directory varies by OS
        if sys.platform == "darwin":
            base = Path.home() / "Library/Application Support/Godot/app_userdata"
        elif sys.platform == "win32":
            base = Path(os.environ.get("APPDATA", "")) / "Godot/app_userdata"
        else:
            base = Path.home() / ".local/share/godot/app_userdata"

        return base / project_name

    def cleanup(self) -> None:
        """Clean up test files from game"""
        game_path = Path(self.game_info["path"])

        # Remove injected test agent
        test_agent = game_path / "autoload" / "test_agent.gd"
        if test_agent.exists():
            test_agent.unlink()

        # Remove test config
        config_file = game_path / "test_config.json"
        if config_file.exists():
            config_file.unlink()

        # Restore project.godot
        self._remove_autoload(game_path / "project.godot")

        # Clean temp dir
        if self.temp_dir and self.temp_dir.exists():
            shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _remove_autoload(self, project_file: Path) -> None:
        """Remove test agent from project autoloads"""
        if not project_file.exists():
            return

        content = project_file.read_text()

        # Remove the TestAgent line
        lines = content.split("\n")
        filtered = [l for l in lines if "TestAgent" not in l]

        project_file.write_text("\n".join(filtered))


class TestOrchestrator:
    """Orchestrates testing across all games"""

    def __init__(self, parallel: int = 1, verbose: bool = False):
        self.parallel = parallel
        self.verbose = verbose
        self.report = TestReport()

    def run_all_tests(self, games: Optional[List[str]] = None) -> TestReport:
        """Run tests on all or specified games"""
        self.report = TestReport(timestamp=datetime.now().isoformat())

        # Get Godot version
        self.report.godot_version = self._get_godot_version()

        # Discover games
        all_games = GameDiscovery.discover_games()

        # Filter if specific games requested
        if games:
            all_games = [g for g in all_games if any(
                pattern in g["name"].lower() for pattern in games
            )]

        self.report.total_games = len(all_games)
        print(f"\n{'='*60}")
        print(f"AUTONOMOUS GAME TEST SUITE")
        print(f"{'='*60}")
        print(f"Games to test: {len(all_games)}")
        print(f"Parallel workers: {self.parallel}")
        print(f"Timeout per game: {TEST_TIMEOUT}s")
        print(f"{'='*60}\n")

        start_time = time.time()

        if self.parallel > 1:
            self._run_parallel(all_games)
        else:
            self._run_sequential(all_games)

        self.report.total_duration = time.time() - start_time

        # Generate report
        self._print_summary()
        self._save_report()

        return self.report

    def _run_sequential(self, games: List[Dict]) -> None:
        """Run tests one at a time"""
        for i, game_info in enumerate(games, 1):
            print(f"\n[{i}/{len(games)}] Testing: {game_info['name']}")
            result = self._test_game(game_info)
            self._record_result(result)

    def _run_parallel(self, games: List[Dict]) -> None:
        """Run tests in parallel"""
        with ThreadPoolExecutor(max_workers=self.parallel) as executor:
            futures = {
                executor.submit(self._test_game, game): game
                for game in games
            }

            for i, future in enumerate(as_completed(futures), 1):
                game = futures[future]
                try:
                    result = future.result()
                    self._record_result(result)
                    print(f"[{i}/{len(games)}] Completed: {game['name']} - {'PASS' if result.passed else 'FAIL'}")
                except Exception as e:
                    print(f"[{i}/{len(games)}] Error testing {game['name']}: {e}")

    def _test_game(self, game_info: Dict) -> TestResult:
        """Test a single game"""
        agent = TestAgent(game_info)

        if not agent.prepare():
            return TestResult(
                game_name=game_info["name"],
                game_path=game_info["path"],
                passed=False,
                duration=0,
                errors=["Failed to prepare test environment"]
            )

        return agent.run()

    def _record_result(self, result: TestResult) -> None:
        """Record a test result"""
        self.report.results.append(result)

        if result.passed:
            self.report.passed += 1
        else:
            self.report.failed += 1

        if self.verbose:
            status = "✅ PASS" if result.passed else "❌ FAIL"
            print(f"  {status} ({result.duration:.2f}s)")
            for error in result.errors:
                print(f"    Error: {error}")

    def _get_godot_version(self) -> str:
        """Get Godot version"""
        try:
            result = subprocess.run(
                [GODOT_CMD, "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.stdout.strip()
        except Exception:
            return "unknown"

    def _print_summary(self) -> None:
        """Print test summary"""
        print(f"\n{'='*60}")
        print("TEST SUMMARY")
        print(f"{'='*60}")
        print(f"Total games:  {self.report.total_games}")
        print(f"Passed:       {self.report.passed} ✅")
        print(f"Failed:       {self.report.failed} ❌")
        print(f"Skipped:      {self.report.skipped}")
        print(f"Pass rate:    {(self.report.passed / max(1, self.report.total_games)) * 100:.1f}%")
        print(f"Duration:     {self.report.total_duration:.2f}s")
        print(f"{'='*60}")

        if self.report.failed > 0:
            print("\nFailed games:")
            for result in self.report.results:
                if not result.passed:
                    print(f"  ❌ {result.game_name}")
                    for error in result.errors[:3]:
                        print(f"      - {error}")

    def _save_report(self) -> None:
        """Save detailed report to file"""
        report_dir = GAMES_DIR / "tests" / "reports"
        report_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = report_dir / f"test_report_{timestamp}.json"

        with open(report_file, "w") as f:
            json.dump(self.report.to_dict(), f, indent=2)

        print(f"\nReport saved: {report_file}")

        # Also save latest report
        latest_file = report_dir / "latest_report.json"
        with open(latest_file, "w") as f:
            json.dump(self.report.to_dict(), f, indent=2)


def main():
    parser = argparse.ArgumentParser(description="Autonomous Game Test Suite")
    parser.add_argument("--games", "-g", nargs="*", help="Specific games to test")
    parser.add_argument("--parallel", "-p", type=int, default=1, help="Parallel workers")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--list", "-l", action="store_true", help="List games only")
    args = parser.parse_args()

    if args.list:
        games = GameDiscovery.discover_games()
        print(f"\nDiscovered {len(games)} games:\n")
        for game in games:
            print(f"  [{game['type']:8}] {game['name']}")
        return 0

    orchestrator = TestOrchestrator(parallel=args.parallel, verbose=args.verbose)
    report = orchestrator.run_all_tests(games=args.games)

    return 0 if report.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
