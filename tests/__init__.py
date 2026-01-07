"""
Autonomous Game Test Suite

This package provides tools for automated testing of Godot games.

Components:
- test_orchestrator.py: Main orchestrator for running tests
- run_tests.sh: Shell script for easy test execution

Usage:
    # List all games
    python -m tests.test_orchestrator --list

    # Run all tests
    python -m tests.test_orchestrator

    # Test specific games
    python -m tests.test_orchestrator -g flappy snake

    # Parallel testing
    python -m tests.test_orchestrator -p 4 -v
"""

from .test_orchestrator import (
    TestOrchestrator,
    TestAgent,
    GameDiscovery,
    TestResult,
    TestReport,
)

__all__ = [
    "TestOrchestrator",
    "TestAgent",
    "GameDiscovery",
    "TestResult",
    "TestReport",
]
