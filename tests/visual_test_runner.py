#!/usr/bin/env python3
"""
Visual Test Runner for Godot Games
Runs games with visible window for manual verification and debugging
"""

import os
import sys
import subprocess
import argparse
import shutil
from pathlib import Path
from datetime import datetime

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from tests.test_orchestrator import GameDiscovery, TEST_FRAMEWORK_DIR

GAMES_DIR = Path(__file__).parent.parent
GODOT_CMD = os.environ.get("GODOT_CMD", "godot")


class VisualTestRunner:
    """Runs games visually for manual testing and verification"""

    def __init__(self, game_name: str, inject_agent: bool = True):
        self.game_name = game_name
        self.inject_agent = inject_agent
        self.game_info = None
        self.cleanup_needed = False

    def find_game(self) -> bool:
        """Find the game in the collection"""
        games = GameDiscovery.discover_games()

        for game in games:
            if self.game_name.lower() in game["name"].lower():
                self.game_info = game
                return True

        print(f"Game not found: {self.game_name}")
        print("\nAvailable games:")
        for game in games:
            print(f"  {game['name']}")
        return False

    def prepare_test_agent(self) -> bool:
        """Inject test agent into game"""
        if not self.inject_agent:
            return True

        game_path = Path(self.game_info["path"])

        # Copy test agent
        test_agent_src = TEST_FRAMEWORK_DIR / "autoload" / "test_agent.gd"
        if not test_agent_src.exists():
            print(f"Test agent not found: {test_agent_src}")
            return False

        test_agent_dst = game_path / "autoload" / "test_agent.gd"
        shutil.copy(test_agent_src, test_agent_dst)

        # Modify project.godot
        project_file = game_path / "project.godot"
        content = project_file.read_text()

        if "TestAgent" not in content:
            if "[autoload]" in content:
                content = content.replace(
                    "[autoload]\n",
                    '[autoload]\n\nTestAgent="*res://autoload/test_agent.gd"\n'
                )
            else:
                content += '\n[autoload]\n\nTestAgent="*res://autoload/test_agent.gd"\n'
            project_file.write_text(content)

        self.cleanup_needed = True
        print("Test agent injected")
        return True

    def run(self, windowed: bool = True, resolution: str = "720x1280") -> int:
        """Run the game visually"""
        game_path = Path(self.game_info["path"])

        print(f"\nLaunching: {self.game_info['name']}")
        print(f"Path: {game_path}")
        print(f"Type: {self.game_info['type']}")
        print(f"Resolution: {resolution}")
        print("-" * 40)

        cmd = [GODOT_CMD, "--path", str(game_path)]

        if windowed:
            width, height = resolution.split("x")
            cmd.extend(["--resolution", f"{width}x{height}"])

        try:
            process = subprocess.run(cmd, cwd=str(game_path))
            return process.returncode
        except KeyboardInterrupt:
            print("\nTest interrupted by user")
            return 0
        except FileNotFoundError:
            print(f"Godot not found: {GODOT_CMD}")
            print("Set GODOT_CMD environment variable to your Godot executable")
            return 1
        finally:
            if self.cleanup_needed:
                self.cleanup()

    def cleanup(self):
        """Remove test agent from game"""
        if not self.cleanup_needed:
            return

        game_path = Path(self.game_info["path"])

        # Remove test agent
        test_agent = game_path / "autoload" / "test_agent.gd"
        if test_agent.exists():
            test_agent.unlink()

        # Clean project.godot
        project_file = game_path / "project.godot"
        if project_file.exists():
            content = project_file.read_text()
            lines = content.split("\n")
            filtered = [l for l in lines if "TestAgent" not in l]
            project_file.write_text("\n".join(filtered))

        print("Cleanup complete")


def interactive_mode():
    """Interactive game selection"""
    games = GameDiscovery.discover_games()

    print("\n" + "="*60)
    print("VISUAL TEST RUNNER - Interactive Mode")
    print("="*60)
    print("\nAvailable games:\n")

    for i, game in enumerate(games, 1):
        print(f"  [{i:2}] {game['name']:<35} ({game['type']})")

    print(f"\n  [0] Exit")
    print()

    while True:
        try:
            choice = input("Select game number: ").strip()
            if choice == "0":
                return None

            idx = int(choice) - 1
            if 0 <= idx < len(games):
                return games[idx]["name"]
            else:
                print("Invalid selection")
        except ValueError:
            print("Please enter a number")
        except KeyboardInterrupt:
            return None


def main():
    parser = argparse.ArgumentParser(description="Visual Game Test Runner")
    parser.add_argument("game", nargs="?", help="Game name to test (partial match)")
    parser.add_argument("--no-agent", action="store_true", help="Don't inject test agent")
    parser.add_argument("--resolution", "-r", default="720x1280", help="Window resolution")
    parser.add_argument("--list", "-l", action="store_true", help="List games only")
    parser.add_argument("--interactive", "-i", action="store_true", help="Interactive mode")
    args = parser.parse_args()

    if args.list:
        games = GameDiscovery.discover_games()
        print(f"\nDiscovered {len(games)} games:\n")
        for game in games:
            print(f"  [{game['type']:8}] {game['name']}")
        return 0

    # Get game name
    game_name = args.game
    if not game_name or args.interactive:
        game_name = interactive_mode()
        if not game_name:
            return 0

    # Run the game
    runner = VisualTestRunner(game_name, inject_agent=not args.no_agent)

    if not runner.find_game():
        return 1

    return runner.run(resolution=args.resolution)


if __name__ == "__main__":
    sys.exit(main())
