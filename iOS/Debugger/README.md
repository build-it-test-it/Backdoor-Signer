# iOS Runtime Debugger

A comprehensive Xcode-like runtime debugger for iOS, fully integrated into the app. This debugger replicates and extends the debugging capabilities of Xcode's LLDB, allowing developers to debug the app directly within its runtime environment.

## Features

### Core Functionality
- LLDB-like command execution
- Breakpoints management
- Variable inspection and modification
- Memory examination
- Thread debugging
- Exception and crash handling
- Step-by-step execution

### Advanced Features
- Network request monitoring
- Performance profiling (CPU, Memory, GPU, Energy)
- View hierarchy inspection
- Memory graph debugging
- Watchpoints

### User Interface
- Floating button (🐞) for quick access
- Tabbed interface for different debugging features
- Light/dark mode support
- Draggable floating button to avoid obstructing the app's interface

## Implementation Details

### Conditional Compilation
The debugger is only included in debug builds using `#if DEBUG` directives, ensuring it doesn't impact release builds.

### Modular Design
The debugger is organized into modular components:
- Core: DebuggerEngine, DebuggerManager
- UI: DebuggerViewController, ConsoleViewController, etc.
- Features: Network monitoring, performance profiling, etc.

### Integration
The debugger is initialized in the AppDelegate's `didFinishLaunchingWithOptions` method, but only in debug builds.

## Usage

### Accessing the Debugger
Tap the floating bug button (🐞) to open the debugger interface.

### Console Commands
The debugger supports many LLDB-like commands:
- `help`: Show available commands
- `po <expr>`: Print object description
- `bt`: Show backtrace
- `br set <file> <line>`: Set breakpoint
- `memory <addr> <size>`: Examine memory
- `step <over|into|out>`: Step execution
- `continue`: Continue execution
- And many more...

### Breakpoints
Set, enable, disable, and delete breakpoints directly from the Breakpoints tab.

### Variables
Inspect and modify variables in the current scope from the Variables tab.

### Network Monitoring
Monitor all network requests, including headers, payloads, and responses from the Network tab.

### Performance Profiling
Monitor CPU, memory, GPU usage, and energy impact in real-time from the Performance tab.

## Implementation Notes

This debugger is designed to be lightweight yet powerful, providing essential debugging capabilities without significantly impacting app performance. It's intended for use during development and testing, and is automatically stripped from release builds.

The implementation uses a combination of Swift's introspection capabilities, runtime features, and UI components to provide a seamless debugging experience within the app itself.

## License

This debugger is part of the main app and is subject to the same license terms.
