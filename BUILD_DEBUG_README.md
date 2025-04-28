# Debug Build Fix for Backdoor Project

## Issue

When building the backdoor project in Debug mode, the following error occurs:

```
=== Building in Debug Mode ===
Custom debugger has been enabled
Using build flags:  -SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG DEBUGGER_ENABLED -OTHER_SWIFT_FLAGS=-DDEBUG=1 -SWIFT_OPTIMIZATION_LEVEL=-Onone -SWIFT_COMPILATION_MODE=singlefile -GCC_PREPROCESSOR_DEFINITIONS=DEBUG=1 -GCC_OPTIMIZATION_LEVEL=0 -COPY_PHASE_STRIP=NO -ENABLE_TESTABILITY=YES -GCC_PREPROCESSOR_DEFINITIONS=DEBUG=1 DEBUGGER_ENABLED=1 -INCLUDE_DEBUGGER=YES -ENABLE_ENHANCED_LOGGING=YES -VERBOSE_LOGGING=YES
xcodebuild: error: Unknown build action 'DEBUGGER_ENABLED'.
```

## Problem Analysis

The error occurs because `DEBUGGER_ENABLED` is being passed as a build action rather than as a compilation condition. In Xcode build commands, flags like `SWIFT_ACTIVE_COMPILATION_CONDITIONS` need to be passed as key-value pairs, not as separate build actions.

## Solution

The included `build_debug.sh` script fixes this issue by:

1. Properly formatting the build flags as key-value pairs
2. Setting `SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG DEBUGGER_ENABLED"` instead of passing `DEBUGGER_ENABLED` as a separate build action
3. Ensuring all other debug flags are properly formatted

## Usage

To build the project in debug mode with the correct flags:

```bash
./build_debug.sh
```

This script will build the project with all the necessary debug flags properly formatted.
