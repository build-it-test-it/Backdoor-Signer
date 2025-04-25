#!/usr/bin/env python3
"""
Build Error Analysis and Reporting Tool

This script analyzes build logs, identifies compilation errors,
and generates a comprehensive, human-readable report without modifying code.
"""

import os
import re
import sys
import json
import html
from pathlib import Path
from collections import defaultdict, Counter

class BuildErrorAnalyzer:
    def __init__(self, log_file, repo_root='.'):
        self.log_file = log_file
        self.repo_root = Path(repo_root)
        self.errors = []
        self.warnings = []
        self.errors_by_file = defaultdict(list)
        self.warnings_by_file = defaultdict(list)
        self.error_types = Counter()
        
    def read_log(self):
        """Read the build log file"""
        print(f"Reading build log from: {self.log_file}")
        try:
            with open(self.log_file, 'r', encoding='utf-8', errors='replace') as f:
                return f.read()
        except Exception as e:
            print(f"Error reading log file: {e}")
            return ""
            
    def parse_errors(self, log_content):
        """Parse the log to find compilation errors and warnings"""
        print("Analyzing build log for errors and warnings...")
        
        # Extract Swift compilation errors and warnings
        swift_issues = re.findall(r'([^:\s]+\.swift):(\d+):(\d+): (error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract Objective-C compilation errors and warnings
        objc_issues = re.findall(r'([^:\s]+\.[hm]|[^:\s]+\.[hm]m):(\d+):(\d+): (error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract linker errors
        linker_errors = re.findall(r'(ld: error|Undefined symbols for architecture .*?):(.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Extract build configuration errors
        config_errors = re.findall(r'(error|warning): (.*?)(?=\n\n|\n[^\s]|$)', log_content, re.DOTALL)
        
        # Process Swift and Objective-C issues
        for file_path, line, column, severity, message in swift_issues + objc_issues:
            issue = {
                'file': file_path.strip(),
                'line': int(line),
                'column': int(column),
                'severity': severity,
                'message': message.strip(),
                'type': self._categorize_issue(message.strip())
            }
            
            if severity == 'error':
                self.errors.append(issue)
                self.errors_by_file[file_path.strip()].append(issue)
                self.error_types[issue['type']] += 1
            else:
                self.warnings.append(issue)
                self.warnings_by_file[file_path.strip()].append(issue)
            
        # Process linker errors
        for error_type, message in linker_errors:
            issue = {
                'file': None,
                'line': None,
                'column': None,
                'severity': 'error',
                'message': f"{error_type}: {message.strip()}",
                'type': 'linker'
            }
            self.errors.append(issue)
            self.error_types['linker'] += 1
            
        # Process configuration errors that don't have file information
        for severity, message in config_errors:
            # Skip if this looks like it might be part of a compilation error we already captured
            if any(message in error['message'] for error in self.errors + self.warnings):
                continue
                
            issue = {
                'file': None,
                'line': None,
                'column': None,
                'severity': severity,
                'message': message.strip(),
                'type': 'configuration'
            }
            
            if severity == 'error':
                self.errors.append(issue)
                self.error_types['configuration'] += 1
            else:
                self.warnings.append(issue)
            
        print(f"Found {len(self.errors)} errors and {len(self.warnings)} warnings")
        
        # Extract build command errors (like syntax errors in shell commands)
        command_errors = re.findall(r'/bin/sh:.+?syntax error.+', log_content)
        if command_errors:
            for error in command_errors:
                issue = {
                    'file': None,
                    'line': None,
                    'column': None,
                    'severity': 'error',
                    'message': error.strip(),
                    'type': 'shell'
                }
                self.errors.append(issue)
                self.error_types['shell'] += 1
            
        return self.errors, self.warnings
        
    def _categorize_issue(self, message):
        """Categorize the type of issue based on the error message"""
        if "undeclared type" in message or "use of undeclared identifier" in message:
            return "undeclared_identifier"
        elif "No such module" in message:
            return "missing_import"
        elif "does not conform to protocol" in message:
            return "protocol_conformance"
        elif "does not implement required" in message:
            return "missing_implementation"
        elif "cannot convert value of type" in message or "cannot assign value of type" in message:
            return "type_mismatch"
        elif "property" in message and "not initialized" in message:
            return "initialization"
        elif "expected '}'" in message:
            return "missing_brace"
        elif "extension of internal class cannot be declared public" in message:
            return "access_control"
        elif "conformance of" in message and "to protocol" in message:
            return "conflicting_conformance"
        elif "'Sendable'-related warnings" in message:
            return "concurrency"
        else:
            return "other"
    
    def generate_text_report(self):
        """Generate a plain text report of all errors and warnings"""
        if not self.errors and not self.warnings:
            return "No errors or warnings detected in the build log."
            
        report = []
        report.append("=" * 80)
        report.append("BUILD ERROR ANALYSIS REPORT")
        report.append("=" * 80)
        report.append("")
        
        # Summary section
        report.append(f"SUMMARY: Found {len(self.errors)} errors and {len(self.warnings)} warnings")
        report.append("")
        
        # Error type breakdown
        if self.errors:
            report.append("ERROR TYPES:")
            for error_type, count in self.error_types.most_common():
                report.append(f"  - {error_type}: {count}")
            report.append("")
        
        # Errors by file
        if self.errors:
            report.append("ERRORS BY FILE:")
            for file_path, errors in sorted(self.errors_by_file.items(), key=lambda x: len(x[1]), reverse=True):
                report.append(f"  {file_path}: {len(errors)} errors")
            report.append("")
            
            report.append("DETAILED ERRORS:")
            report.append("-" * 80)
            
            # Group errors by file for better readability
            for file_path, errors in sorted(self.errors_by_file.items()):
                report.append(f"FILE: {file_path}")
                for error in sorted(errors, key=lambda x: x['line']):
                    line_info = f"Line {error['line']}" if error['line'] else ""
                    report.append(f"  {line_info}")
                    report.append(f"  ERROR: {error['message']}")
                    report.append(f"  TYPE: {error['type']}")
                    suggestion = self._get_suggestion(error)
                    if suggestion:
                        report.append(f"  SUGGESTION: {suggestion}")
                    report.append("")
                report.append("-" * 40)
            
            # Handle errors without file information
            other_errors = [e for e in self.errors if e['file'] is None]
            if other_errors:
                report.append("OTHER ERRORS:")
                for error in other_errors:
                    report.append(f"  ERROR: {error['message']}")
                    report.append(f"  TYPE: {error['type']}")
                    suggestion = self._get_suggestion(error)
                    if suggestion:
                        report.append(f"  SUGGESTION: {suggestion}")
                    report.append("")
        
        # Warnings summary (if requested)
        if self.warnings:
            report.append("WARNINGS SUMMARY:")
            report.append("-" * 80)
            for file_path, warnings in sorted(self.warnings_by_file.items()):
                report.append(f"FILE: {file_path}")
                for warning in sorted(warnings, key=lambda x: x['line']):
                    report.append(f"  Line {warning['line']}: {warning['message']}")
                report.append("")
        
        return "\n".join(report)
    
    def generate_html_report(self):
        """Generate an HTML report for better readability"""
        html_content = []
        html_content.append("<!DOCTYPE html>")
        html_content.append("<html lang='en'>")
        html_content.append("<head>")
        html_content.append("  <meta charset='UTF-8'>")
        html_content.append("  <meta name='viewport' content='width=device-width, initial-scale=1.0'>")
        html_content.append("  <title>Build Error Analysis Report</title>")
        html_content.append("  <style>")
        html_content.append("    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 1200px; margin: 0 auto; padding: 20px; }")
        html_content.append("    h1 { color: #d33; border-bottom: 2px solid #d33; padding-bottom: 10px; }")
        html_content.append("    h2 { color: #333; border-bottom: 1px solid #ccc; padding-bottom: 5px; }")
        html_content.append("    .summary { background-color: #f8f8f8; border-left: 4px solid #d33; padding: 10px 20px; margin: 20px 0; }")
        html_content.append("    .error { background-color: #fff0f0; border-left: 4px solid #d33; padding: 10px 20px; margin: 10px 0; border-radius: 4px; }")
        html_content.append("    .warning { background-color: #fffaed; border-left: 4px solid #f7b731; padding: 10px 20px; margin: 10px 0; border-radius: 4px; }")
        html_content.append("    .type-badge { display: inline-block; background-color: #ccc; color: #333; border-radius: 12px; padding: 2px 8px; font-size: 12px; margin-right: 5px; }")
        html_content.append("    .suggestion { background-color: #f0fff0; border-left: 4px solid #2ecc71; padding: 10px 20px; margin: 10px 0; border-radius: 4px; }")
        html_content.append("    .file-header { background-color: #eee; padding: 5px 10px; margin-top: 20px; border-radius: 4px 4px 0 0; font-weight: bold; }")
        html_content.append("    table { width: 100%; border-collapse: collapse; margin: 20px 0; }")
        html_content.append("    th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }")
        html_content.append("    th { background-color: #f2f2f2; }")
        html_content.append("    tr:hover { background-color: #f5f5f5; }")
        html_content.append("    .error-count { color: #d33; font-weight: bold; }")
        html_content.append("    .warning-count { color: #f7b731; font-weight: bold; }")
        html_content.append("  </style>")
        html_content.append("</head>")
        html_content.append("<body>")
        html_content.append("  <h1>Build Error Analysis Report</h1>")
        
        # Summary section
        html_content.append("  <div class='summary'>")
        html_content.append(f"    <h2>Summary</h2>")
        html_content.append(f"    <p>Found <span class='error-count'>{len(self.errors)}</span> errors and <span class='warning-count'>{len(self.warnings)}</span> warnings</p>")
        html_content.append("  </div>")
        
        # Error type breakdown
        if self.errors:
            html_content.append("  <h2>Error Types</h2>")
            html_content.append("  <table>")
            html_content.append("    <tr><th>Type</th><th>Count</th></tr>")
            for error_type, count in self.error_types.most_common():
                html_content.append(f"    <tr><td>{error_type}</td><td>{count}</td></tr>")
            html_content.append("  </table>")
        
        # Errors by file
        if self.errors:
            html_content.append("  <h2>Errors By File</h2>")
            html_content.append("  <table>")
            html_content.append("    <tr><th>File</th><th>Error Count</th></tr>")
            for file_path, errors in sorted(self.errors_by_file.items(), key=lambda x: len(x[1]), reverse=True):
                html_content.append(f"    <tr><td>{html.escape(file_path)}</td><td>{len(errors)}</td></tr>")
            html_content.append("  </table>")
            
            html_content.append("  <h2>Detailed Errors</h2>")
            
            # Group errors by file for better readability
            for file_path, errors in sorted(self.errors_by_file.items()):
                html_content.append(f"  <div class='file-header'>{html.escape(file_path)}</div>")
                for error in sorted(errors, key=lambda x: x['line']):
                    html_content.append("  <div class='error'>")
                    line_info = f"Line {error['line']}" if error['line'] else ""
                    html_content.append(f"    <p>{line_info} <span class='type-badge'>{error['type']}</span></p>")
                    html_content.append(f"    <p><strong>Error:</strong> {html.escape(error['message'])}</p>")
                    
                    suggestion = self._get_suggestion(error)
                    if suggestion:
                        html_content.append(f"    <div class='suggestion'><strong>Suggestion:</strong> {html.escape(suggestion)}</div>")
                    
                    html_content.append("  </div>")
            
            # Handle errors without file information
            other_errors = [e for e in self.errors if e['file'] is None]
            if other_errors:
                html_content.append("  <h2>Other Errors</h2>")
                for error in other_errors:
                    html_content.append("  <div class='error'>")
                    html_content.append(f"    <p><span class='type-badge'>{error['type']}</span></p>")
                    html_content.append(f"    <p><strong>Error:</strong> {html.escape(error['message'])}</p>")
                    
                    suggestion = self._get_suggestion(error)
                    if suggestion:
                        html_content.append(f"    <div class='suggestion'><strong>Suggestion:</strong> {html.escape(suggestion)}</div>")
                    
                    html_content.append("  </div>")
        
        # Warnings summary
        if self.warnings:
            html_content.append("  <h2>Warnings Summary</h2>")
            for file_path, warnings in sorted(self.warnings_by_file.items()):
                html_content.append(f"  <div class='file-header'>{html.escape(file_path)}</div>")
                for warning in sorted(warnings, key=lambda x: x['line']):
                    html_content.append("  <div class='warning'>")
                    html_content.append(f"    <p>Line {warning['line']} <span class='type-badge'>{warning['type']}</span></p>")
                    html_content.append(f"    <p><strong>Warning:</strong> {html.escape(warning['message'])}</p>")
                    html_content.append("  </div>")
        
        html_content.append("</body>")
        html_content.append("</html>")
        
        return "\n".join(html_content)
    
    def _get_suggestion(self, error):
        """Generate a human-readable suggestion based on the error type"""
        message = error['message']
        error_type = error['type']
        
        if error_type == 'undeclared_identifier':
            match = re.search(r"use of undeclared (type|identifier) ['']([^'']+)['']", message)
            if match:
                identifier_type = match.group(1)
                identifier = match.group(2)
                return f"Ensure '{identifier}' is properly imported or defined before use."
                
        elif error_type == 'missing_import':
            match = re.search(r"No such module ['']([^'']+)['']", message)
            if match:
                module_name = match.group(1)
                return f"Add 'import {module_name}' to the file."
                
        elif error_type == 'protocol_conformance':
            return "Ensure the class properly conforms to all protocol requirements."
            
        elif error_type == 'missing_implementation':
            match = re.search(r"does not implement required instance method ['']([^'']+)['']", message)
            if match:
                method_name = match.group(1)
                return f"Implement the required method '{method_name}'."
                
        elif error_type == 'type_mismatch':
            match = re.search(r"cannot (convert|assign) value of type ['']([^'']+)[''] to (\w+) type ['']([^'']+)['']", message)
            if match:
                from_type = match.group(2)
                to_type = match.group(4)
                return f"Types '{from_type}' and '{to_type}' are not compatible. Consider using a proper type conversion or ensuring the correct type is used."
                
        elif error_type == 'initialization':
            match = re.search(r"property ['']([^'']+)[''] not initialized", message)
            if match:
                property_name = match.group(1)
                return f"Initialize property '{property_name}' with a default value in init() or with a property initializer."
                
        elif error_type == 'missing_brace':
            return "There is a missing closing brace ('}') in the file. Check for proper opening and closing of code blocks."
            
        elif error_type == 'access_control':
            return "The extension cannot be declared public because the original class is internal. Change 'public extension' to 'extension'."
            
        elif error_type == 'conflicting_conformance':
            return "This extension adds a conformance that might be added by the system in the future. Consider adding @available attribute or restructuring your code."
            
        elif error_type == 'concurrency':
            return "Add '@preconcurrency' to the import to suppress Sendable-related warnings."
            
        elif error_type == 'shell':
            if "syntax error near unexpected token" in message and "(" in message:
                return "There's an issue with parentheses in a shell command. Ensure special characters like parentheses are properly escaped with backslashes."
                
        elif error_type == 'linker':
            if "Undefined symbols" in message:
                return "The linker cannot find definitions for some symbols. Ensure all required frameworks are linked and all functions are properly defined."
                
        return None
        
    def save_reports(self):
        """Save the reports to files"""
        # Save the text report
        with open('build_error_report.txt', 'w', encoding='utf-8') as f:
            f.write(self.generate_text_report())
        
        # Save the HTML report
        with open('build_error_report.html', 'w', encoding='utf-8') as f:
            f.write(self.generate_html_report())
        
        # Save the JSON data for potential programmatic use
        report_data = {
            'summary': {
                'error_count': len(self.errors),
                'warning_count': len(self.warnings),
                'error_types': dict(self.error_types)
            },
            'errors': self.errors,
            'warnings': self.warnings
        }
        
        with open('build_error_report.json', 'w', encoding='utf-8') as f:
            json.dump(report_data, f, indent=2)
            
        print(f"Reports saved to build_error_report.txt, build_error_report.html, and build_error_report.json")

def main():
    if len(sys.argv) < 2:
        print("Usage: python auto-fix-build-errors.py <build_log_file>")
        sys.exit(1)
        
    log_file = sys.argv[1]
    analyzer = BuildErrorAnalyzer(log_file)
    
    log_content = analyzer.read_log()
    if not log_content:
        print("Build log is empty or could not be read.")
        sys.exit(1)
        
    analyzer.parse_errors(log_content)
    
    # Print a simple summary to stdout
    print("\n" + "=" * 80)
    print(f"BUILD ERROR ANALYSIS SUMMARY")
    print("=" * 80)
    print(f"Found {len(analyzer.errors)} errors and {len(analyzer.warnings)} warnings")
    
    if analyzer.errors:
        print("\nERROR TYPES:")
        for error_type, count in analyzer.error_types.most_common():
            print(f"  - {error_type}: {count}")
    
    # Save detailed reports to files
    analyzer.save_reports()
    
    # Exit with code based on whether errors were found
    if analyzer.errors:
        print("\nDetailed reports saved. Please check build_error_report.html for a comprehensive analysis.")
        sys.exit(1)
    else:
        print("\nNo errors found.")
        sys.exit(0)

if __name__ == "__main__":
    main()
