# Custom Programming Language and iOS App Enhancements

## Overview
This document outlines the requirements for designing and implementing a custom programming language for a private iOS application, enhancing terminal integration, and addressing multiple issues within the existing codebase. The custom language must integrate seamlessly with Python and Swift, and the terminal must be fully on-device. Additionally, various modules, UI components, and logic within the app require deep analysis, bug fixes, and enhancements to ensure high-quality, production-grade code. All tasks must adhere to the provided prompts for production-level code, real files, issue resolution, repository analysis, and rule adherence.

---

## Custom Programming Language Requirements

### Objectives
- Design and implement a custom programming language for a private iOS application.
- Enhance the existing terminal integration to support the new language.
- Ensure seamless integration with Python and Swift, with smooth interoperability.
- Provide a user-friendly terminal environment for inputting and executing code.

### Functional Requirements
1. **Python Integration**:
   - Full support for writing, executing, and coding in Python.
   - Ability to install Python dependencies, run scripts, and perform any Python-related tasks (e.g., data processing, scripting, library usage).
2. **Swift Integration**:
   - Full support for writing, executing, and running Swift code.
   - Access to Swift command-line tools and native iOS APIs.
3. **Interoperability**:
   - Allow switching between Python, Swift, or both within the same program.
   - Support data passing between Python and Swift (e.g., calling Swift functions from Python and vice versa).
4. **Terminal Enhancements**:
   - Replace external website-based terminal with a fully on-device terminal tailored to the app’s specific use case.
   - Provide a clear, user-defined syntax for the custom language.
   - Support language features like variables, control flow, and function definitions.
   - Ensure the terminal is user-friendly, efficient, secure, and optimized for iOS.
5. **Implementation Details**:
   - Develop a complete language design, execution engine, and terminal integration.
   - Use open-source libraries and resources to create a high-quality terminal.
   - Leverage dependencies listed in `dependencies.txt` for implementation.
   - Avoid external dependencies like Keychain for storage; use local storage instead.

### Technical Constraints
- The app is private and not subject to App Store restrictions.
- All code must be production-grade, fully implemented, and free of placeholders or stubs.
- The terminal must be analyzed within the codebase, and all connected components must be identified and updated.

---

## Codebase Issues and Enhancements

### General Guidelines
- All tasks must adhere to the following prompts:
  1. Provide complete, robust, production-level code without stubs or simplified implementations.
  2. Use only real, existing files; download or access necessary files to ensure functionality.
  3. Avoid simplified code; replace any existing simplified code with production-ready implementations.
  4. Address issues one at a time, in order, with complete fixes before moving to the next.
  5. Perform comprehensive repository analysis when instructed to analyze the entire codebase.
  6. Strictly follow these rules for all code-related tasks and store them for reference.

- Use dependencies listed in `dependencies.txt` for all implementations.
- Ensure all code is high-quality, sophisticated, and optimized for iOS.
- Remove duplicate logic, unused code, or placeholder logic across all tasks.
- Avoid Keychain usage; switch to local storage for any data persistence.

### Specific Issues and Enhancements

1. **App Crash After Initial Screens**:
   - **Issue**: The app crashes after passing the initial screens, rendering it unusable until reinstalled.
   - **Task**:
     - Perform a deep analysis of all code related to navigation and post-initial screen logic.
     - Identify and fix the root cause of the crash.
     - Ensure the app remains stable and functional after the initial screens.
     - Check for potential issues in other parts of the codebase that may contribute to the crash.

2. **Keychain Removal**:
   - **Issue**: The app may use Keychain for data storage, which is not desired.
   - **Task**:
     - Analyze the codebase for any Keychain usage.
     - Replace Keychain-based storage with secure local storage (e.g., file-based or on-device database).
     - Ensure no functionality is broken during the transition.
     - Update all affected components to use the new storage mechanism.

3. **AI Code Enhancements**:
   - **Issue**: AI-related code may contain unused, duplicate, or incomplete logic.
   - **Task**:
     - Perform a deep analysis of all AI code in the codebase.
     - Ensure all AI functionality is 100% correct, production-grade, and optimized for iOS.
     - Remove unused or duplicate code, keeping only the best implementation.
     - Optionally convert AI code to C++ if it improves maintainability and performance, ensuring proper integration with the app.
     - Verify all AI logic works as intended and enhance where necessary.

4. **Debugger Module Enhancements**:
   - **Issue**: The debugger module may contain placeholder or incomplete logic.
   - **Task**:
     - Perform a deep analysis of the debugger module.
     - Remove any placeholder or incomplete logic.
     - Fully implement a high-quality, built-in app debugger using internet resources and best practices.
     - Ensure the debugger is production-grade and does not introduce new placeholders.

5. **System UI Code Analysis and Fixes**:
   - **Issue**: UI code may contain issues or incorrect implementations.
   - **Task**:
     - Analyze all UI-related code, including the `extensions` folder and other relevant files.
     - Fix any issues found, ensuring all UI components are correctly implemented and functional.
     - Verify UI logic is production-grade and optimized for iOS.

6. **Settings Crash**:
   - **Issue**: The app crashes instantly when the user accesses the settings tab, rendering the app unusable.
   - **Task**:
     - Analyze all settings-related code.
     - Identify and fix the root cause of the crash.
     - Ensure the settings tab is fully functional and stable.

7. **Remove AI Features Popup**:
   - **Issue**: A popup prompting users to enable AI features appears on app launch.
   - **Task**:
     - Identify and remove all code related to the AI features popup.
     - Ensure the popup no longer appears on app launch.
     - Verify no functionality is broken by this removal.

8. **App Signing Logic**:
   - **Issue**: App signing logic may contain placeholder or incomplete code.
   - **Task**:
     - Analyze all app signing code.
     - Ensure it is fully implemented, high-quality, and free of placeholders.
     - Verify proper UI integration for user interaction.
     - Confirm all logic is correctly set up and functional.

9. **Sources Folder Analysis**:
   - **Issue**: The `sources` folder may contain placeholder or incomplete logic.
   - **Task**:
     - Analyze all code in the `sources` folder.
     - Ensure all logic is fully implemented, high-quality, and free of placeholders.
     - Fix any configuration or setup issues.

10. **Popup View Controllers**:
    - **Issue**: Popup view controllers may contain issues or incorrect implementations.
    - **Task**:
      - Analyze all popup view controller files.
      - Understand their purpose and dependencies within the codebase.
      - Fix any issues, ensuring all logic is production-grade and functional.

11. **Apps Folder Enhancements**:
    - **Issue**: The `apps` folder may contain duplicate or incomplete logic.
    - **Task**:
      - Perform a deep analysis of all code in the `apps` folder.
      - Remove duplicate logic and ensure all code is high-quality and production-grade.
      - Enhance logic to meet Swift best practices and ensure full functionality.

12. **Delegates Folder Enhancements**:
    - **Issue**: The `delegates` folder may contain placeholder or suboptimal logic.
    - **Task**:
      - Analyze all code in the `delegates` folder.
      - Remove placeholders and enhance logic to meet high-quality standards.
      - Ensure no functionality is broken during enhancements.

13. **Offline App Logic Enhancements**:
    - **Issue**: Offline logic may not be production-grade or fully optimized.
    - **Task**:
      - Perform a deep analysis of all offline app logic.
      - Enhance the code to be high-quality, sophisticated, and production-grade.
      - Ensure all offline functionality works as intended without issues.

14. **Operations Folder Enhancements**:
    - **Issue**: The `operations` folder may contain placeholder or suboptimal logic.
    - **Task**:
      - Analyze all code in the `operations` folder.
      - Understand the purpose of each file and its dependencies.
      - Enhance the code to be high-quality, sophisticated, and free of placeholders.
      - Ensure no functionality is broken.

15. **Home Folder Enhancements**:
    - **Issue**: The `home` folder may contain incomplete or suboptimal logic.
    - **Task**:
      - Analyze all code in the `home` folder.
      - Understand its intended functionality and enhance the logic to be high-quality and production-grade.
      - Ensure proper UI integration and full functionality.
      - Add any necessary features with complete, production-grade implementations.

---

## Dependencies
- All tasks must utilize the dependencies listed in `dependencies.txt`.
- Ensure compatibility with iOS and the app’s architecture.
- Incorporate open-source libraries where appropriate to enhance functionality (e.g., terminal, debugger, or AI components).

---

## Implementation Notes
- **Code Quality**: All code must be production-grade, adhering to Swift and C++ best practices where applicable.
- **Optimization**: Ensure all implementations are efficient, secure, and optimized for iOS.
- **Testing**: Verify all changes through thorough testing to ensure no functionality is broken.
- **Documentation**: Update any relevant documentation to reflect changes, especially for the custom language and terminal.

---

## Next Steps
1. Analyze the codebase to identify the terminal and its connected components.
2. Design the custom programming language and execution engine.
3. Implement the on-device terminal with the specified features.
4. Address each codebase issue in order, starting with the app crash after initial screens.
5. Perform deep analyses and enhancements for each specified module or folder.
6. Validate all changes to ensure stability and functionality.

This document serves as a comprehensive guide for implementing the custom programming language and enhancing the iOS app’s codebase.
