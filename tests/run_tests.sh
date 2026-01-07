#!/bin/bash
# Autonomous Game Test Runner
# Run tests on all Godot games in the collection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           AUTONOMOUS GAME TEST SUITE                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Check for Godot
if ! command -v godot &> /dev/null; then
    # Try common Godot locations on macOS
    if [ -f "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
        export GODOT_CMD="/Applications/Godot.app/Contents/MacOS/Godot"
    elif [ -f "/Applications/Godot_v4.app/Contents/MacOS/Godot" ]; then
        export GODOT_CMD="/Applications/Godot_v4.app/Contents/MacOS/Godot"
    else
        echo -e "${RED}Error: Godot not found in PATH${NC}"
        echo "Please either:"
        echo "  1. Add Godot to your PATH"
        echo "  2. Set GODOT_CMD environment variable"
        echo "  3. Run: export GODOT_CMD=/path/to/godot"
        exit 1
    fi
    echo -e "${YELLOW}Using Godot at: $GODOT_CMD${NC}"
else
    export GODOT_CMD="godot"
fi

# Parse arguments
PARALLEL=1
VERBOSE=""
GAMES=""
LIST_ONLY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--parallel)
            PARALLEL="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -l|--list)
            LIST_ONLY="-l"
            shift
            ;;
        -g|--games)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
                GAMES="$GAMES $1"
                shift
            done
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -p, --parallel N    Run N tests in parallel (default: 1)"
            echo "  -v, --verbose       Verbose output"
            echo "  -l, --list          List games only, don't run tests"
            echo "  -g, --games NAMES   Test specific games (space separated)"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                          # Test all games"
            echo "  $0 -l                       # List all games"
            echo "  $0 -g flappy snake          # Test specific games"
            echo "  $0 -p 4 -v                  # 4 parallel workers, verbose"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Build command
CMD="python3 \"$SCRIPT_DIR/test_orchestrator.py\""
[ -n "$PARALLEL" ] && CMD="$CMD -p $PARALLEL"
[ -n "$VERBOSE" ] && CMD="$CMD $VERBOSE"
[ -n "$LIST_ONLY" ] && CMD="$CMD $LIST_ONLY"
[ -n "$GAMES" ] && CMD="$CMD -g $GAMES"

# Run tests
echo -e "\n${BLUE}Running command:${NC} $CMD\n"
eval $CMD
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
else
    echo -e "\n${RED}Some tests failed. Check the report for details.${NC}"
fi

exit $EXIT_CODE
