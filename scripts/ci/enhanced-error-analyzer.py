#!/usr/bin/env python3
"""
Enhanced Build Error Analysis Tool

This script analyzes build logs from artifacts, identifies compilation errors,
and generates comprehensive reports. It supports analyzing multiple log files
and has improved error detection capabilities.
"""

import os
import re
import sys
import json
import html
import glob
import time
import argparse
from pathlib import Path
from collections import defaultdict, Counter

class EnhancedBuildErrorAnalyzer:
    def __init__(self, log_dir='logs-for-analysis', repo_root='.'):
        """
        Initialize the analyzer.
        
        Args:
            log_dir: Directory containing log files to analyze
            repo_root: Root of the repository
        """
        self.log_dir = Path(log_dir)
        self.repo_root = Path(repo_root)
        self.errors = []
        self.warnings = []
        self.notes = []
        self.errors_by_file = defaultdict(list)
        self.warnings_by_file = defaultdict(list)
        self.error_types = Counter()
        self.warning_types = Counter()
        self.related_errors = defaultdict(list)
        self.timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        self.analyzed_files = []
        
    def find_and_analyze_logs(self):
        """Find and analyze all log files in the log directory"""
        print(f"Searching for log files in {self.log_dir}")
        
        # First check if we have a combined log file
        combined_log = self.log_dir / "combined_build_logs.txt"
        if combined_log.exists() and combined_log.stat().st_size > 0:
            print(f"Found combined log file: {combined_log}")
            content = self._read_file(combined_log)
            if content:
                print(f"Analyzing combined log file ({len(content)} bytes)")
                self.parse_errors(content)
                self.analyzed_files.append(str(combined_log))
                return True
        
        # If no combined log or it's empty, try individual log files
        log_files = []
        log_files.extend(self.log_dir.glob('*.log'))
        log_files.extend(self.log_dir.glob('*.txt'))
        
        if not log_files:
            print(f"No log files found in {self.log_dir}")
            return False
        
        print(f"Found {len(log_files)} individual log files")
        
        # Sort by size (largest first) as they likely have more information
        log_files.sort(key=lambda x: x.stat().st_size, reverse=True)
        
        successful_parse = False
        for log_file in log_files:
            # Skip very small files (likely empty or useless)
            if log_file.stat().st_size < 100:
                print(f"Skipping small file: {log_file} ({log_file.stat().st_size} bytes)")
                continue
                
            content = self._read_file(log_file)
            if not content:
                continue
                
            print(f"Analyzing log file: {log_file} ({len(content)} bytes)")
            
            # Check if this file contains build output
            if not self._is_build_log(content):
                print(f"File doesn't appear to be a build log, skipping: {log_file}")
                continue
                
            # Parse errors from this log file
            result = self.parse_errors(content)
            if result:
                successful_parse = True
                self.analyzed_files.append(str(log_file))
        
        return successful_parse
    
    def _is_build_log(self, content):
        """Check if content appears to be a build log"""
        # Look for common patterns in build logs
        build_patterns = [
            r'(error|warning):', 
            r'Build failed',
            r'Compile .*\.swift',
            r'swift',
            r'xcodebuild',
            r'linker command failed',
            r'clang',
            r'Compilation failed'
        ]
        
        for pattern in build_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                return True
                
        return False
    
    def _read_file(self, file_path):
        """Read a file with error handling"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
                
            if content:
                print(f"Successfully read {file_path} ({len(content)} bytes)")
                return content
            else:
                print(f"File is empty: {file_path}")
                return None
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return None
            
    def parse_errors(self, log_content):
        """Parse the log to find compilation errors^
:\s]+\.swift):(\d+):(\d+): (error|warning|note): (.*?)(?=\n\n|\n[
^
\s]|$)', 
            log_content, 
            re.DOTALL
        )
        
        # Extract Objective-C compilation errors and warnings
        objc_issues = re.findall(
            rf'{path_pattern}([
^
:\s]+\.[hm](?:m)?):(\d+):(\d+): (error|warning|note): (.*?)(?=\n\n|\n[
^
\s]|$)', 
            log_content, 
            re.DOTALL
        )
        
        # Extract linker errors with better patterns
        linker_errors = []
        linker_errors.extend(re.findall(r'(ld: error|Undefined symbols for architecture .*?):(.*?)(?=\n\n|\n[
^
\s]|$)', log_content, re.DOTALL))
        linker_errors.extend(re.findall(r'(ld: library not found for .*?)(?=\n\n|\n[
^
\s]|$)', log_content, re.DOTALL))
        linker_errors.extend(re.findall(r'(ld: framework not found .*?)(?=\n\n|\n[
^
\s]|$)', log_content, re.DOTALL))
        
        # Extract module errors (like swift module compilation)
        module_errors = re.findall(r'(EmitSwiftModule|SwiftEmitModule).*failed', log_content)
        
        # Extract Xcode build errors (sometimes these are formatted differently)
        xcode_errors = re.findall(r'(?:The following build commands failed:)(?:\n\t.+)+', log_content)
        
        # Count issues found
        issues_found = len(swift_issues) + len(objc_issues) + len(linker_errors) + len(module_errors) + len(xcode_errors)
        
        # Process Swift and Objective-C issues
        for file_path, line, column, severity, message in swift_issues + objc_issues:
            issue = {
                'file': self._normalize_path(file_path.strip()),
                'line': int(line),
                'column': int(column),
                'severity': severity,
                'message': message.strip(),
                'type': self._categorize_issue(message.strip()),
                'code_context': self._get_code_context(message.strip())
            }
            
            if severity == 'error':
                self.errors.append(issue)
                self.errors_by_file[issue['file']].append(issue)
                self.error_types[issue['type']] += 1
            elif severity == 'warning':
                self.warnings.append(issue)
                self.warnings_by_file[issue['file']].append(issue)
                self.warning_types[issue['type']] += 1
            else:  # note
                self.notes.append(issue)
        
        # Process other types of errors
        self._process_other_errors(linker_errors, 'linker')
        self._process_other_errors(module_errors, 'module_compilation')
        self._process_other_errors(xcode_errors, 'build_system')
        
        # Find and link related errors
        self._link_related_errors()
            
        print(f"Found {len(self.errors)} errors and {len(self.warnings)} warnings in this log")
        return issues_found > 0
        
    def _process_other_errors(self, errors, error_type):
        """Process non-code-location errors like linker errors"""
        for i, error_info in enumerate(errors):
            if isinstance(error_info, tuple):
                error_type_text, message = error_info
                error_message = f"{error_type_text}: {message.strip()}"
            else:
                error_message = error_info.strip()
            
            issue = {
                'file': None,
                'line': None,
                'column': None,
                'severity': 'error',
                'message': error_message,
                'type': error_type,
                'id': f'{error_type}_{i}'  # Give each a unique ID for referencing
            }
            self.errors.append(issue)
            self.error_types[error_type] += 1
    
    def _normalize_path(self, path):
        """Normalize file paths to be consistent"""
        # Remove absolute path prefixes that might appear in logs
        normalized = re.sub(r'
^
/Users/[
^
/]+/work/[
^
/]+/[
^
/]+/', '', path)
        normalized = re.sub(r'
^
/Users/runner/\w+/\w+/', '', normalized)
        normalized = re.sub(r'
^
workspace/', '', normalized)
        return normalized
    
    def _get_code_context(self, message):
        """Extract code context from error messages if provided"""
        code_snippets = re.findall(r'`([
^
`]+)`', message)
        if code_snippets:
            return code_snippets
        return None
        
    def _categorize_issue(self, message):
        """Categorize the type of issue based on the error message with enhanced matching"""
        # Identifier and type issues
        if re.search(r"undeclared (type|identifier)", message, re.IGNORECASE):
            return "undeclared_identifier"
        elif "No such module" in message:
            return "missing_import"
            
        # Protocol and conformance issues
        elif "does not conform to protocol" in message:
            return "protocol_conformance" 
        elif "does not implement required" in message:
            return "missing_implementation"
        elif "conformance of" in message and "to protocol" in message:
            return "conflicting_conformance"
            
        # Override and class member issues
        elif "'override' can only be specified on class members" in message:
            return "invalid_override"
            
        # Type safety issues
        elif re.search(r"cannot (convert|assign) value of type", message, re.IGNORECASE):
            return "type_mismatch"
        elif "nil coalescing operator" in message:
            return "unnecessary_nil_coalescing"
            
        # Initialization issues
        elif re.search(r"property ['\"].*['\"] not initialized", message, re.IGNORECASE):
            return "initialization"
            
        # Syntax issues
        elif "expected '}'" in message:
            return "missing_brace"
        elif "expected declaration" in message:
            return "invalid_declaration"
            
        # Access control issues
        elif "extension of internal class cannot be declared public" in message:
            return "access_control"
            
        # Swift concurrency issues
        elif "'Sendable'-related warnings" in message or "@preconcurrency" in message:
            return "concurrency"
            
        # Return anything else as "other"
        return "other"
    
    def _link_related_errors(self):
        """Find errors that are likely related to each other"""
        # Group file-based errors by file and line proximity
        for file_path, errors in self.errors_by_file.items():
            # Skip files with only one error
            if len(errors) <= 1:
                continue
                
            # Sort by line number
            sorted_errors = sorted(errors, key=lambda x: x.get('line', 0) or 0)
            
            # Group errors that are within 5 lines of each other
            current_group = []
            for error in sorted_errors:
                if not current_group or abs((error.get('line', 0) or 0) - (current_group[-1].get('line', 0) or 0)) <= 5:
                    current_group.append(error)
                else:
                    # Store the group if it has multiple errors
                    if len(current_group) > 1:
                        group_id = f"group_{file_path}_{current_group[0].get('line', 0)}"
                        for err in current_group:
                            self.related_errors[group_id].append(err)
                    current_group = [error]
            
            # Check the last group
            if len(current_group) > 1:
                group_id = f"group_{file_path}_{current_group[0].get('line', 0)}"
                for err in current_group:
                    self.related_errors[group_id].append(err)
                    
        # Also look for similar error types across files (common module errors, etc.)
        for error_type in self.error_types:
            if error_type not in ('other', 'unknown') and self.error_types[error_type] > 1:
                matching_errors = [err for err in self.errors if err.get('type') == error_type]
                if len(matching_errors) > 1:
                    group_id = f"type_{error_type}"
                    for err in matching_errors:
                        self.related_errors[group_id].append(err)
            
    def generate_reports(self):
        """Generate all reports (text, HTML, JSON)"""
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
                'error_types': dict(self.error_types),
                'warning_types': dict(self.warning_types),
                'analyzed_files': self.analyzed_files,
                'timestamp': self.timestamp
            },
            'errors': self.errors,
            'warnings': self.warnings,
            'related_error_groups': {k: [err['message'] for err in v] for k, v in self.related_errors.items()}
        }
        
        with open('build_error_report.json', 'w', encoding='utf-8') as f:
            json.dump(report_data, f, indent=2)
            
        print(f"Reports saved to build_error_report.txt, build_error_report.html, and build_error_report.json")
    
    def generate_text_report(self):
        """Generate a plain text report of all errors and warnings"""
        if not self.errors and not self.warnings:
            return "No errors or warnings detected in the build logs."
            
        report = []
        report.append("=" * 80)
        report.append("BUILD ERROR ANALYSIS REPORT")
        report.append("=" * 80)
        report.append(f"Generated at: {self.timestamp}")
        report.append("")
        report.append(f"Analyzed the following logs:")
        for log_file in self.analyzed_files:
            report.append(f"  - {log_file}")
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
                for error in sorted(errors, key=lambda x: x.get('line', 0) or 0):
                    line_info = f"Line {error['line']}" if error.get('line') else ""
                    report.append(f"  {line_info}")
                    report.append(f"  ERROR: {error['message']}")
                    report.append(f"  TYPE: {error['type']}")
                    suggestion = self._get_suggestion(error)
                    if suggestion:
                        report.append(f"  SUGGESTION: {suggestion}")
                    report.append("")
                
                # Add a related errors section if applicable
                related_groups = {group_id: errors for group_id, errors in self.related_errors.items() 
                                 if any(err.get('file') == file_path for err in errors)}
                if related_groups:
                    report.append("  RELATED ERRORS:")
                    for group_id, rel_errors in related_groups.items():
                        if any(err.get('file') == file_path for err in rel_errors):
                            report.append(f"  - Group of {len(rel_errors)} related errors around line {rel_errors[0].get('line', '?')}")
                    report.append("")
                
                report.append("-" * 40)
            
            # Handle errors without file information
            other_errors = [e for e in self.errors if not e.get('file')]
            if other_errors:
                report.append("OTHER ERRORS:")
                for error in other_errors:
                    report.append(f"  ERROR: {error['message']}")
                    report.append(f"  TYPE: {error['type']}")
                    suggestion = self._get_suggestion(error)
                    if suggestion:
                        report.append(f"  SUGGESTION: {suggestion}")
                    report.append("")
        
        # Warnings summary
        if self.warnings:
            report.append("WARNINGS SUMMARY:")
            report.append("-" * 80)
            for file_path, warnings in sorted(self.warnings_by_file.items()):
                report.append(f"FILE: {file_path}")
                for warning in sorted(warnings, key=lambda x: x.get('line', 0) or 0):
                    report.append(f"  Line {warning.get('line', '?')}: {warning['message']}")
                    # Add suggestions for warnings too
                    suggestion = self._get_suggestion(warning)
                    if suggestion:
                        report.append(f"  SUGGESTION: {suggestion}")
                report.append("")
        
        # Add a section with fix recommendations
        report.append("RECOMMENDE# Let's create a focused update with just the essential components
# First, create the artifact handler script with improved log finding

cat > scripts/ci/artifact-manager.sh << 'EOF'
#!/bin/bash
set -eo pipefail

# Focused Artifact Manager Script
# Prioritizes finding and analyzing build logs from artifacts

echo "📦 Artifact Manager: Finding build logs in artifacts"

# Create directories for organized processing
mkdir -p artifact-extracts
mkdir -p build-logs

# Find all artifacts in the current directory and artifact-contents
find_artifacts() {
  echo "🔍 Searching for artifact files..."
  
  # Common locations where artifacts might be found in GitHub Actions
  ARTIFACT_DIRS=(
    "."
    "artifact-contents"
    "artifacts"
    "downloads"
    "/home/runner/work/_temp"
  )
  
  # Look for zip files in these directories
  for DIR in "${ARTIFACT_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      echo "Searching in $DIR"
      find "$DIR" -name "*.zip" -type f | while read -r ZIP_FILE; do
        echo "Found artifact: $ZIP_FILE"
        extract_artifact "$ZIP_FILE"
      done
    fi
  done
}

# Extract an artifact file
extract_artifact() {
  ZIP_FILE="$1"
  EXTRACT_DIR="artifact-extracts/$(basename "$ZIP_FILE" .zip)"
  
  echo "Extracting $ZIP_FILE to $EXTRACT_DIR"
  mkdir -p "$EXTRACT_DIR"
  unzip -q -o "$ZIP_FILE" -d "$EXTRACT_DIR" || echo "Warning: Extraction issues with $ZIP_FILE"
  
  # Look for build logs in the extracted content
  find_logs_in_extract "$EXTRACT_DIR"
}

# Find log files in an extracted artifact
find_logs_in_extract() {
  EXTRACT_DIR="$1"
  echo "Searching for logs in $EXTRACT_DIR"
  
  # Common build log patterns
  LOG_PATTERNS=(
    "*build*.log"
    "*build*.txt"
    "*xcodebuild*.log"
    "*output*.log"
    "*compile*.log"
    "*.build.log"
    "*.txt"
  )
  
  # Find all potential log files
  for PATTERN in "${LOG_PATTERNS[@]}"; do
    find "$EXTRACT_DIR" -type f -iname "$PATTERN" 2>/dev/null | while read -r LOG_FILE; do
      echo "Checking potential log: $LOG_FILE"
      
      # Check if this looks like a build log (contains error/warning messages)
      if grep -q -E "error:|warning:|fatal error:|linker command failed|swift|xcodebuild" "$LOG_FILE"; then
        echo "✅ Found build log: $LOG_FILE"
        cp "$LOG_FILE" "build-logs/$(basename "$LOG_FILE")"
      fi
    done
  done
}

# Combine all found logs into a single file for analysis
combine_logs() {
  echo "Combining logs for analysis..."
  
  if [ -z "$(ls -A build-logs 2>/dev/null)" ]; then
    echo "::warning::No build logs found in artifacts"
    echo "No build log found. This is a placeholder." > build_log.txt
    return 1
  fi
  
  # Combine all logs with headers separating them
  > combined_build_log.txt
  for LOG_FILE in build-logs/*; do
    echo "=== $(basename "$LOG_FILE") ===" >> combined_build_log.txt
    echo "" >> combined_build_log.txt
    cat "$LOG_FILE" >> combined_build_log.txt
    echo "" >> combined_build_log.txt
    echo "=== END OF $(basename "$LOG_FILE") ===" >> combined_build_log.txt
    echo "" >> combined_build_log.txt
  done
  
  # Create the main build log file for backward compatibility
  cp combined_build_log.txt build_log.txt
  echo "Created combined log file: build_log.txt"
  
  # Create a manifest of log files
  find build-logs -type f | sort > build-logs/log_manifest.txt
  echo "Created log manifest: build-logs/log_manifest.txt"
  
  return 0
}

# Main execution flow
find_artifacts
combine_logs

# Summary
echo "✅ Artifact processing complete"
if [ -f "build_log.txt" ]; then
  echo "Log files ready for analysis: build_log.txt"
  echo "Individual logs available in: build-logs/"
fi
