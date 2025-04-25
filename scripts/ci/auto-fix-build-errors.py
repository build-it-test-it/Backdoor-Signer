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

class BuildErrorFixer:
    def __init__(self, log_file, repo_root='.'):
        self.log_file = log_file
        self.repo_root = Path(repo_root)
        self.errors = []
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
        
        # Extract Swift compilation errors
        swift_errors = re.findall(r'(.*?\.swift):(\d+):(\d+): (error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract Objective-C compilation errors
        objc_errors = re.findall(r'(.*?\.[hm]|.*?\.[hm]m):(\d+):(\d+): (error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract linker errors
        linker_errors = re.findall(r'(ld: error|Undefined symbols for architecture .*?):(.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Process Swift and Objective-C errors
        for file_path, line, column, severity, message in swift_errors + objc_errors:
            self.errors.append({
                'file': file_path.strip(),
                'line': int(line),
                'column': int(column),
                'severity': severity,
                'message': message.strip(),
                'type': 'compilation'
            })
            
        # Process linker errors
        for error_type, message in linker_errors:
            self.errors.append({
                'file': None,
                'line': None,
                'column': None,
                'severity': 'error',
                'message': f"{error_type}: {message.strip()}",
                'type': 'linker'
            })
            
        print(f"Found {len(self.errors)} potential issues to fix")
        return self.errors
        
    def fix_errors(self):
        """Apply fixes for the detected errors"""
        if not self.errors:
            print("No errors to fix.")
            return False
            
        fixes_applied = 0
        for error in self.errors:
            if error['type'] == 'compilation' and error['file']:
                fixed = self.fix_compilation_error(error)
                if fixed:
                    fixes_applied += 1
            elif error['type'] == 'linker':
                fixed = self.fix_linker_error(error)
                if fixed:
                    fixes_applied += 1
                    
        print(f"Applied {fixes_applied} fixes")
        return fixes_applied > 0
        
    def fix_compilation_error(self, error):
        """Fix a compilation error"""
        file_path = error['file']
        line = error['line']
        message = error['message']
        
        # Check if file exists
        full_path = self.repo_root / file_path
        if not full_path.exists():
            print(f"Cannot fix error: File not found: {full_path}")
            return False
            
        # Read the file
        try:
            with open(full_path, 'r') as f:
                file_lines = f.readlines()
        except Exception as e:
            print(f"Error reading file {full_path}: {e}")
            return False
            
        # Apply fixes based on error patterns
        fix_applied = False
        
        # Common error type 1: Use of undeclared type or identifier
        if "undeclared type" in message or "use of undeclared identifier" in message:
            fix_applied = self.fix_undeclared_identifier(full_path, file_lines, line, message)
            
        # Common error type 2: Missing import/include
        elif "No such module" in message:
            fix_applied = self.fix_missing_import(full_path, file_lines, line, message)
            
        # Common error type 3: Missing method implementation
        elif "does not conform to protocol" in message or "does not implement required instance method" in message:
            fix_applied = self.fix_missing_protocol_implementation(full_path, file_lines, line, message)
            
        # Common error type 4: Type mismatch
        elif "cannot convert value of type" in message or "cannot assign value of type" in message:
            fix_applied = self.fix_type_mismatch(full_path, file_lines, line, message)
            
        # Common error type 5: Missing initialization
        elif "property" in message and "not initialized" in message:
            fix_applied = self.fix_missing_initialization(full_path, file_lines, line, message)
            
        # If no specific fix applied, log the error for manual fixing
        if not fix_applied:
            print(f"No automatic fix available for: {file_path}:{line} - {message}")
            
        return fix_applied
        
    def fix_undeclared_identifier(self, file_path, file_lines, line, message):
        """Fix undeclared identifier errors"""
        # Extract the identifier
        match = re.search(r"use of undeclared (type|identifier) ['']([^'']+)['']", message)
        if not match:
            return False
            
        identifier_type = match.group(1)
        identifier = match.group(2)
        
        print(f"Attempting to fix undeclared {identifier_type}: {identifier} in {file_path}:{line}")
        
        # Simple type import attempt for Swift
        if file_path.suffix == '.swift' and identifier_type == 'type':
            # Add import at the top of the file after existing imports
            for i, line_content in enumerate(file_lines):
                if line_content.strip().startswith('import '):
                    last_import_line = i
                    
            if 'last_import_line' in locals():
                file_lines.insert(last_import_line + 1, f"import {identifier}\n")
                
                # Write the file
                with open(file_path, 'w') as f:
                    f.writelines(file_lines)
                    
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
        
        print(f"Attempting to fix missing import for module: {module_name} in {file_path}:{line}")
        
        # Add import at the top of the file
        for i, line_content in enumerate(file_lines):
            if line_content.strip().startswith('import '):
                last_import_line = i
        
        # If there are already imports, add after the last one
        if 'last_import_line' in locals():
            file_lines.insert(last_import_line + 1, f"import {module_name}\n")
        # Otherwise add at the top after comments and blank lines
        else:
            i = 0
            while i < len(file_lines) and (file_lines[i].strip().startswith('//') or file_lines[i].strip() == ''):
                i += 1
            file_lines.insert(i, f"import {module_name}\n")
            last_import_line = i - 1
            
        # Write the file
        with open(file_path, 'w') as f:
            f.writelines(file_lines)
            
        self.fixes_applied.append({
            'file': str(file_path),
            'line': last_import_line + 1,
            'fix': f"Added import for module {module_name}"
        })
        return True
        
    def fix_missing_protocol_implementation(self, file_path, file_lines, line, message):
        """Fix missing protocol implementation errors"""
        # This is a more complex fix requiring context analysis
        # For now, just identify the method that needs to be implemented
        match = re.search(r"does not implement required instance method ['']([^'']+)['']", message)
        if not match:
            return False
            
        method_name = match.group(1)
        print(f"Detected missing protocol method: {method_name} in {file_path}:{line}")
        
        # This type of fix would require more context to implement correctly
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
        
        print(f"Attempting to fix type mismatch: {from_type} to {to_type} in {file_path}:{line}")
        
        # This type of fix would require more context to implement correctly
        return False
        
    def fix_missing_initialization(self, file_path, file_lines, line, message):
        """Fix missing initialization errors"""
        # Extract the property name
        match = re.search(r"property ['']([^'']+)[''] not initialized", message)
        if not match:
            return False
            
        property_name = match.group(1)
        
        print(f"Attempting to fix missing initialization for: {property_name} in {file_path}:{line}")
        
        # This type of fix would require more context to implement correctly
        return False
        
    def fix_linker_error(self, error):
        """Fix a linker error"""
        message = error['message']
        
        print(f"Attempting to fix linker error: {message}")
        
        # Linker errors are complex and require understanding the project structure
        # This would need to be implemented based on specific project needs
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
