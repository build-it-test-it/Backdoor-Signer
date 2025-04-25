#!/usr/bin/env python3
"""
Automatic Build Error Correction Tool

This script analyzes build logs, identifies common compilation errors, 
and automatically attempts to fix them.
"""

import os
import re
import sys
import json
import subprocess
from pathlib import Path
from collections import defaultdict

class BuildErrorFixer:
    def __init__(self, log_file, repo_root='.'):
        self.log_file = log_file
        self.repo_root = Path(repo_root)
        self.errors = []
        self.errors_by_file = defaultdict(list)
        self.fixes_applied = []
        
    def read_log(self):
        """Read the build log file"""
        print(f"Reading build log from: {self.log_file}")
        try:
            with open(self.log_file, 'r') as f:
                return f.read()
        except Exception as e:
            print(f"Error reading log file: {e}")
            return ""
            
    def parse_errors(self, log_content):
        """Parse the log to find compilation errors"""
        print("Parsing build log for errors...")
        
        # Extract Swift compilation errors (more comprehensive pattern)
        swift_errors = re.findall(r'([^:\s]+\.swift):(\d+):(\d+): (error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract Objective-C compilation errors
        objc_errors = re.findall(r'([^:\s]+\.[hm]|[^:\s]+\.[hm]m):(\d+):(\d+): (error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract linker errors
        linker_errors = re.findall(r'(ld: error|Undefined symbols for architecture .*?):(.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Process Swift and Objective-C errors
        for file_path, line, column, severity, message in swift_errors + objc_errors:
            error = {
                'file': file_path.strip(),
                'line': int(line),
                'column': int(column),
                'severity': severity,
                'message': message.strip(),
                'type': 'compilation'
            }
            self.errors.append(error)
            self.errors_by_file[file_path.strip()].append(error)
            
        # Process linker errors
        for error_type, message in linker_errors:
            error = {
                'file': None,
                'line': None,
                'column': None,
                'severity': 'error',
                'message': f"{error_type}: {message.strip()}",
                'type': 'linker'
            }
            self.errors.append(error)
            
        print(f"Found {len(self.errors)} potential issues to fix")
        return self.errors
        
    def fix_errors(self):
        """Apply fixes for the detected errors"""
        if not self.errors:
            print("No errors to fix.")
            return False
            
        fixes_applied = 0
        
        # Process files with errors
        for file_path, errors in self.errors_by_file.items():
            file_fixes = self.fix_file_errors(file_path, errors)
            fixes_applied += file_fixes
            
        # Process linker errors
        for error in self.errors:
            if error['type'] == 'linker':
                fixed = self.fix_linker_error(error)
                if fixed:
                    fixes_applied += 1
                    
        print(f"Applied {fixes_applied} fixes")
        return fixes_applied > 0
    
    def fix_file_errors(self, file_path, errors):
        """Fix all errors in a single file"""
        # Attempt to find the file with both absolute and relative paths
        absolute_path = file_path
        if not os.path.isabs(file_path):
            full_path = self.repo_root / file_path
        else:
            full_path = Path(file_path)
            # Also try to find it relative to the repo root
            file_name = os.path.basename(file_path)
            for root, dirs, files in os.walk(self.repo_root):
                if file_name in files:
                    candidate = Path(os.path.join(root, file_name))
                    if candidate.exists():
                        full_path = candidate
                        break
            
        if not full_path.exists():
            # Try to find the file by basename in the repo
            basename = os.path.basename(file_path)
            found_paths = []
            for root, dirs, files in os.walk(self.repo_root):
                if basename in files:
                    found_paths.append(os.path.join(root, basename))
            
            if found_paths:
                full_path = Path(found_paths[0])
                print(f"Found matching file at: {full_path}")
            else:
                print(f"Cannot fix errors: File not found: {file_path}")
                return 0
            
        # Read the file
        try:
            with open(full_path, 'r') as f:
                content = f.read()
                file_lines = content.splitlines(True)  # Keep line endings
        except Exception as e:
            print(f"Error reading file {full_path}: {e}")
            return 0
        
        # Sort errors by line in reverse (to process from bottom to top)
        # This prevents line number changes from affecting other fixes
        errors.sort(key=lambda x: x['line'], reverse=True)
        
        fixes_applied = 0
        needs_save = False
        
        # Check for specific error patterns across the file
        has_brace_errors = any("expected '}'" in error['message'] for error in errors)
        has_access_control_errors = any("extension of internal class cannot be declared public" in error['message'] for error in errors)
        has_conformance_errors = any(("conformance of" in error['message'] and "to protocol" in error['message']) for error in errors)
        
        # Apply file-level fixes for certain error types
        if has_brace_errors:
            fixed = self.fix_missing_braces(full_path, file_lines, errors)
            if fixed:
                needs_save = True
                fixes_applied += 1
                
        if has_access_control_errors:
            fixed = self.fix_access_control(full_path, file_lines, errors)
            if fixed:
                needs_save = True
                fixes_applied += 1
                
        if has_conformance_errors:
            fixed = self.fix_conformance_declarations(full_path, file_lines, errors)
            if fixed:
                needs_save = True
                fixes_applied += 1
        
        # Process individual errors
        for error in errors:
            line = error['line'] - 1  # Convert to 0-based indexing
            message = error['message']
            
            # Skip errors that were handled by file-level fixes
            if ((has_brace_errors and "expected '}'" in message) or
                (has_access_control_errors and "extension of internal class cannot be declared public" in message) or
                (has_conformance_errors and "conformance of" in message and "to protocol" in message)):
                continue
            
            # Apply fixes based on error patterns
            fixed = False
            
            # Common error type 1: Use of undeclared type or identifier
            if "undeclared type" in message or "use of undeclared identifier" in message:
                fixed = self.fix_undeclared_identifier(full_path, file_lines, line, message)
                
            # Common error type 2: Missing import/include
            elif "No such module" in message:
                fixed = self.fix_missing_import(full_path, file_lines, line, message)
                
            # Common error type 3: Missing method implementation
            elif "does not conform to protocol" in message or "does not implement required instance method" in message:
                fixed = self.fix_missing_protocol_implementation(full_path, file_lines, line, message)
                
            # Common error type 4: Type mismatch
            elif "cannot convert value of type" in message or "cannot assign value of type" in message:
                fixed = self.fix_type_mismatch(full_path, file_lines, line, message)
                
            # Common error type 5: Missing initialization
            elif "property" in message and "not initialized" in message:
                fixed = self.fix_missing_initialization(full_path, file_lines, line, message)
                
            # Common error type 6: Add @preconcurrency
            elif "'Sendable'-related warnings" in message:
                fixed = self.fix_add_preconcurrency(full_path, file_lines, line, message)
            
            if fixed:
                needs_save = True
                fixes_applied += 1
                
        # Save the file if any fixes were applied
        if needs_save:
            with open(full_path, 'w') as f:
                f.writelines(file_lines)
                
        return fixes_applied
        
    def fix_missing_braces(self, file_path, file_lines, errors):
        """Fix missing closing braces"""
        brace_errors = [e for e in errors if "expected '}'" in e['message']]
        if not brace_errors:
            return False
            
        print(f"Fixing missing braces in {file_path}")
        
        # We need to analyze the structure of the file to fix missing braces
        content = ''.join(file_lines)
        
        # Count opening and closing braces
        open_braces = content.count('{')
        close_braces = content.count('}')
        
        if open_braces > close_braces:
            missing = open_braces - close_braces
            print(f"Found {missing} missing closing braces")
            
            # Find positions where braces need to be added
            for error in brace_errors:
                line_idx = error['line'] - 1
                if line_idx < len(file_lines):
                    # Add a closing brace at the specified line
                    indent = self.get_indentation(file_lines[line_idx])
                    file_lines[line_idx] = file_lines[line_idx] + indent + "}\n"
                    
                    self.fixes_applied.append({
                        'file': str(file_path),
                        'line': error['line'],
                        'fix': f"Added missing closing brace"
                    })
                    
                    # Decrement missing brace count
                    missing -= 1
                    if missing <= 0:
                        break
            
            return True
        
        return False
    
    def fix_access_control(self, file_path, file_lines, errors):
        """Fix access control modifiers"""
        access_errors = [e for e in errors if "extension of internal class cannot be declared public" in e['message']]
        if not access_errors:
            return False
            
        print(f"Fixing access control modifiers in {file_path}")
        fixed = False
        
        for error in access_errors:
            line_idx = error['line'] - 1
            if line_idx < len(file_lines):
                # Replace "public extension" with "extension"
                if "public extension" in file_lines[line_idx]:
                    file_lines[line_idx] = file_lines[line_idx].replace("public extension", "extension")
                    
                    self.fixes_applied.append({
                        'file': str(file_path),
                        'line': error['line'],
                        'fix': f"Changed public extension to extension"
                    })
                    
                    fixed = True
        
        return fixed
    
    def fix_conformance_declarations(self, file_path, file_lines, errors):
        """Fix improper conformance declarations"""
        conformance_errors = [e for e in errors if "conformance of" in e['message'] and "to protocol" in e['message']]
        if not conformance_errors:
            return False
            
        print(f"Fixing conformance declarations in {file_path}")
        fixed = False
        
        for error in conformance_errors:
            line_idx = error['line'] - 1
            if line_idx < len(file_lines):
                # Extract the type and protocol from the error message
                match = re.search(r"conformance of '([^']+)' to protocol '([^']+)'", error['message'])
                if match:
                    type_name = match.group(1)
                    protocol_name = match.group(2)
                    
                    # Typically this requires adding @available or changing the extension
                    if "extension" in file_lines[line_idx]:
                        # Add @available attribute before the extension
                        indent = self.get_indentation(file_lines[line_idx])
                        file_lines.insert(line_idx, f"{indent}// FIXME: This extension may conflict with future framework updates\n")
                        file_lines.insert(line_idx + 1, f"{indent}@available(*, deprecated, message: \"This conformance might conflict with future framework updates\")\n")
                        
                        self.fixes_applied.append({
                            'file': str(file_path),
                            'line': error['line'],
                            'fix': f"Added @available attribute to prevent conflicts for {type_name}:{protocol_name}"
                        })
                        
                        fixed = True
        
        return fixed
    
    def fix_add_preconcurrency(self, file_path, file_lines, line, message):
        """Add @preconcurrency attribute to fix Sendable-related warnings"""
        print(f"Adding @preconcurrency attribute in {file_path}:{line+1}")
        
        # Extract the module name from the error message
        match = re.search(r"from module '([^']+)'", message)
        if not match:
            return False
            
        module_name = match.group(1)
        
        # Find the import statement for this module
        for i, line_content in enumerate(file_lines):
            if line_content.strip().startswith(f"import {module_name}"):
                # Add @preconcurrency attribute before the import
                file_lines[i] = f"@preconcurrency import {module_name}\n"
                
                self.fixes_applied.append({
                    'file': str(file_path),
                    'line': i + 1,
                    'fix': f"Added @preconcurrency to {module_name} import"
                })
                
                return True
        
        return False
        
    def fix_undeclared_identifier(self, file_path, file_lines, line, message):
        """Fix undeclared identifier errors"""
        # Extract the identifier
        match = re.search(r"use of undeclared (type|identifier) ['']([^'']+)['']", message)
        if not match:
            return False
            
        identifier_type = match.group(1)
        identifier = match.group(2)
        
        print(f"Attempting to fix undeclared {identifier_type}: {identifier} in {file_path}:{line+1}")
        
        # Simple type import attempt for Swift
        if str(file_path).endswith('.swift') and identifier_type == 'type':
            # Add import at the top of the file after existing imports
            for i, line_content in enumerate(file_lines):
                if line_content.strip().startswith('import '):
                    last_import_line = i
                    
            if 'last_import_line' in locals():
                file_lines.insert(last_import_line + 1, f"import {identifier}\n")
                
                self.fixes_applied.append({
                    'file': str(file_path),
                    'line': last_import_line + 1,
                    'fix': f"Added import for {identifier}"
                })
                return True
                
        return False
        
    def fix_missing_import(self, file_path, file_lines, line, message):
        """Fix missing import errors"""
        # Extract the module name
        match = re.search(r"No such module ['']([^'']+)['']", message)
        if not match:
            return False
            
        module_name = match.group(1)
        
        print(f"Attempting to fix missing import for module: {module_name} in {file_path}:{line+1}")
        
        # Add import at the top of the file
        for i, line_content in enumerate(file_lines):
            if line_content.strip().startswith('import '):
                last_import_line = i
        
        # If there are already imports, add after the last one
        if 'last_import_line' in locals():
            file_lines.insert(last_import_line + 1, f"import {module_name}\n")
            inserted_at = last_import_line + 1
        # Otherwise add at the top after comments and blank lines
        else:
            i = 0
            while i < len(file_lines) and (file_lines[i].strip().startswith('//') or file_lines[i].strip() == ''):
                i += 1
            file_lines.insert(i, f"import {module_name}\n")
            inserted_at = i
            
        self.fixes_applied.append({
            'file': str(file_path),
            'line': inserted_at + 1,
            'fix': f"Added import for module {module_name}"
        })
        return True
        
    def fix_missing_protocol_implementation(self, file_path, file_lines, line, message):
        """Fix missing protocol implementation errors"""
        # This is a more complex fix requiring context analysis
        # Extract the method that needs to be implemented
        match = re.search(r"does not implement required instance method ['']([^'']+)['']", message)
        if not match:
            return False
            
        method_name = match.group(1)
        print(f"Attempting to implement required method: {method_name} in {file_path}:{line+1}")
        
        # Try to determine the class/struct name that needs to implement the method
        class_name = None
        for i in range(line, -1, -1):
            if i < len(file_lines):
                if re.search(r'class\s+(\w+)', file_lines[i]):
                    class_name = re.search(r'class\s+(\w+)', file_lines[i]).group(1)
                    break
                elif re.search(r'struct\s+(\w+)', file_lines[i]):
                    class_name = re.search(r'struct\s+(\w+)', file_lines[i]).group(1)
                    break
        
        if class_name:
            # Generate a stub implementation
            indent = self.get_indentation(file_lines[line])
            stub = f"\n{indent}// FIXME: Implement required protocol method\n{indent}func {method_name} {{\n{indent}    // Implementation needed\n{indent}}}\n"
            
            # Find the right place to insert (before the closing brace of the class/struct)
            for i in range(line, len(file_lines)):
                if '}' in file_lines[i]:
                    file_lines[i] = stub + file_lines[i]
                    
                    self.fixes_applied.append({
                        'file': str(file_path),
                        'line': i + 1,
                        'fix': f"Added stub implementation for method {method_name}"
                    })
                    return True
        
        return False
        
    def fix_type_mismatch(self, file_path, file_lines, line, message):
        """Fix type mismatch errors"""
        # Extract the type information
        match = re.search(r"cannot (convert|assign) value of type ['']([^'']+)[''] to (\w+) type ['']([^'']+)['']", message)
        if not match:
            return False
            
        action = match.group(1)
        from_type = match.group(2)
        to_category = match.group(3)
        to_type = match.group(4)
        
        print(f"Attempting to fix type mismatch: {from_type} to {to_type} in {file_path}:{line+1}")
        
        # First attempt: Add explicit cast if the types are compatible
        if from_type == "String" and to_type == "String?":
            # This is a simple conversion from non-optional to optional
            self.attempt_add_as_cast(file_path, file_lines, line, from_type, to_type)
            return True
        
        # For other cases, we'd need more context
        return False
        
    def attempt_add_as_cast(self, file_path, file_lines, line, from_type, to_type):
        """Attempt to add 'as' cast to fix type mismatch"""
        if line < 0 or line >= len(file_lines):
            return False
            
        # Look for variable assignments or function calls
        original_line = file_lines[line]
        
        # Replace the variable without adding explicit cast
        # This is a simplified approach; a real fix would be more selective
        if "=" in original_line:
            parts = original_line.split("=")
            if len(parts) == 2:
                left = parts[0].strip()
                right = parts[1].strip()
                
                # Add cast to the right part
                if not right.endswith(")") and not " as " in right:
                    new_line = f"{left} = {right} as {to_type}\n"
                    file_lines[line] = new_line
                    
                    self.fixes_applied.append({
                        'file': str(file_path),
                        'line': line + 1,
                        'fix': f"Added explicit cast from {from_type} to {to_type}"
                    })
                    return True
        
        return False
        
    def fix_missing_initialization(self, file_path, file_lines, line, message):
        """Fix missing initialization errors"""
        # Extract the property name
        match = re.search(r"property ['']([^'']+)[''] not initialized", message)
        if not match:
            return False
            
        property_name = match.group(1)
        
        print(f"Attempting to fix missing initialization for: {property_name} in {file_path}:{line+1}")
        
        # Look for the property declaration
        declaration_line = None
        property_type = None
        
        for i in range(max(0, line - 10), min(len(file_lines), line + 10)):
            if property_name in file_lines[i]:
                # Try to extract the type
                type_match = re.search(rf"{property_name}\s*:\s*([^{{}}=\n]+)", file_lines[i])
                if type_match:
                    property_type = type_match.group(1).strip()
                    declaration_line = i
                    break
        
        if declaration_line is not None and property_type:
            # Add initialization based on type
            default_value = self.get_default_value_for_type(property_type)
            
            # Modify the declaration line to include initialization
            original_line = file_lines[declaration_line]
            if not "=" in original_line:
                new_line = original_line.rstrip() + f" = {default_value}\n"
                file_lines[declaration_line] = new_line
                
                self.fixes_applied.append({
                    'file': str(file_path),
                    'line': declaration_line + 1,
                    'fix': f"Added initialization for property {property_name}: {property_type} = {default_value}"
                })
                return True
        
        return False
        
    def get_default_value_for_type(self, type_name):
        """Get default initialization value for a given type"""
        type_name = type_name.strip()
        
        if "String" in type_name:
            return '""'
        elif "Int" in type_name:
            return "0"
        elif "Bool" in type_name:
            return "false"
        elif "Double" in type_name or "Float" in type_name:
            return "0.0"
        elif "Array" in type_name or "[" in type_name:
            return "[]"
        elif "Dictionary" in type_name or "[:" in type_name:
            return "[:]"
        elif "?" in type_name:  # Optional type
            return "nil"
        else:
            return f"{type_name}()"
    
    def get_indentation(self, line):
        """Get the indentation string from a line"""
        match = re.match(r'^(\s*)', line)
        return match.group(1) if match else ""
        
    def fix_linker_error(self, error):
        """Fix a linker error"""
        message = error['message']
        
        print(f"Attempting to fix linker error: {message}")
        
        # Look for undefined symbol references
        if "Undefined symbols for architecture" in message:
            # Extract the symbol name
            symbol_match = re.search(r'"(_[^"]+)"', message)
            if symbol_match:
                symbol = symbol_match.group(1)
                print(f"Undefined symbol: {symbol}")
                
                # To fix this, we would need to locate the source of the symbol
                # This likely requires adding a framework or fixing a function signature
                
        return False
        
    def generate_report(self):
        """Generate a report of the fixes applied"""
        if not self.fixes_applied:
            print("No fixes were applied.")
            return
            
        print("\n===== Applied Fixes Report =====")
        for fix in self.fixes_applied:
            print(f"{fix['file']}:{fix['line']} - {fix['fix']}")
            
        # Save the report to a file
        with open('auto_fix_report.json', 'w') as f:
            json.dump(self.fixes_applied, f, indent=2)
            
        print(f"Report saved to auto_fix_report.json")

def main():
    if len(sys.argv) < 2:
        print("Usage: python auto-fix-build-errors.py <build_log_file>")
        sys.exit(1)
        
    log_file = sys.argv[1]
    fixer = BuildErrorFixer(log_file)
    
    log_content = fixer.read_log()
    if not log_content:
        print("Build log is empty or could not be read.")
        sys.exit(1)
        
    fixer.parse_errors(log_content)
    fixes_applied = fixer.fix_errors()
    fixer.generate_report()
    
    if fixes_applied:
        print("Fixes were successfully applied.")
        sys.exit(0)
    else:
        print("No automatic fixes could be applied.")
        sys.exit(1)

if __name__ == "__main__":
    main()
