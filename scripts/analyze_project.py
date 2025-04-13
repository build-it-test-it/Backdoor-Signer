#!/usr/bin/env python3
"""
A diagnostic tool to analyze the structure of an Xcode project file.
This tool helps identify the correct patterns for the dependency scripts.

Usage:
    python3 analyze_project.py [project_file]
"""

import argparse
import re
import os
import sys
import json

DEFAULT_PROJECT_FILE = 'backdoor.xcodeproj/project.pbxproj'

def analyze_project(project_file):
    """Analyze the structure of the Xcode project file."""
    try:
        with open(project_file, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading project file: {e}")
        return 1
    
    print(f"\n=== Project File Analysis: {project_file} ===")
    print(f"File size: {len(content)} bytes")
    
    # Find all section markers
    begin_sections = re.findall(r'\/\* Begin ([A-Za-z]+) section \*\/', content)
    end_sections = re.findall(r'\/\* End ([A-Za-z]+) section \*\/', content)
    
    print(f"\n=== Detected {len(begin_sections)} section types ===")
    for section in sorted(set(begin_sections)):
        print(f"- {section}")
    
    if set(begin_sections) != set(end_sections):
        print("\nWARNING: Mismatched begin/end section markers!")
        only_begin = set(begin_sections) - set(end_sections)
        only_end = set(end_sections) - set(begin_sections)
        
        if only_begin:
            print(f"Sections with only BEGIN marker: {', '.join(only_begin)}")
        if only_end:
            print(f"Sections with only END marker: {', '.join(only_end)}")
    
    # Analyze PBXFrameworksBuildPhase section specifically
    print("\n=== PBXFrameworksBuildPhase Analysis ===")
    frameworks_match = re.search(r'\/\* Begin PBXFrameworksBuildPhase section \*\/(.*?)\/\* End PBXFrameworksBuildPhase section \*\/', 
                              content, re.DOTALL)
    
    if frameworks_match:
        frameworks_section = frameworks_match.group(1)
        print(f"Section length: {len(frameworks_section)} bytes")
        
        # Find all framework build phases
        build_phases = re.findall(r'([A-F0-9]+)\s+\/\*\s*([^*]+)\s*\*\/\s+=\s+\{\s*isa\s+=\s+PBXFrameworksBuildPhase;(.*?)};', 
                                frameworks_section, re.DOTALL)
        
        print(f"Found {len(build_phases)} framework build phases:")
        
        for i, (phase_id, phase_name, phase_content) in enumerate(build_phases):
            print(f"\n--- Build Phase {i+1}: {phase_name.strip()} ({phase_id}) ---")
            
            # Extract attributes
            attributes = re.findall(r'(\w+)\s*=\s*([^;]+);', phase_content)
            for attr_name, attr_value in attributes:
                if attr_name == "files":
                    file_entries = re.findall(r'([A-F0-9]+)\s+\/\*\s*([^*]+)\*\/', attr_value)
                    print(f"  {attr_name} = ({len(file_entries)} entries)")
                    for file_id, file_name in file_entries[:5]:  # Show first 5
                        print(f"    - {file_name.strip()} ({file_id})")
                    if len(file_entries) > 5:
                        print(f"    ... and {len(file_entries) - 5} more")
                else:
                    print(f"  {attr_name} = {attr_value.strip()}")
    else:
        print("WARNING: Could not find PBXFrameworksBuildPhase section!")
        
        # Try to find similar sections
        similar_sections = [section for section in begin_sections if "Phase" in section]
        if similar_sections:
            print(f"Found these similar phase sections: {', '.join(similar_sections)}")
            
            # Sample the first one
            for section in similar_sections:
                section_match = re.search(f'\/\* Begin {section} section \*\/(.*?)\/\* End {section} section \*\/', 
                                       content, re.DOTALL)
                if section_match:
                    print(f"\nSample from {section} section (first 200 chars):")
                    print(section_match.group(1)[:200] + "...")
                    break
    
    # Look at PBXBuildFile section for framework entries
    print("\n=== Framework Build File Entries ===")
    buildfile_match = re.search(r'\/\* Begin PBXBuildFile section \*\/(.*?)\/\* End PBXBuildFile section \*\/', 
                               content, re.DOTALL)
    
    if buildfile_match:
        buildfile_section = buildfile_match.group(1)
        framework_entries = re.findall(r'([A-F0-9]+)\s+\/\*\s*([^*]+in Frameworks)\s*\*\/\s+=\s+\{(.*?)\};', 
                                     buildfile_section, re.DOTALL)
        
        print(f"Found {len(framework_entries)} framework build file entries:")
        for i, (file_id, file_name, file_content) in enumerate(framework_entries[:10]):  # Show first 10
            print(f"  - {file_name.strip()} ({file_id})")
            
        if len(framework_entries) > 10:
            print(f"  ... and {len(framework_entries) - 10} more")
    else:
        print("WARNING: Could not find PBXBuildFile section!")
    
    return 0

def main():
    parser = argparse.ArgumentParser(description='Analyze Xcode project structure for diagnostics')
    parser.add_argument('project_file', nargs='?', default=DEFAULT_PROJECT_FILE,
                      help=f'Path to project.pbxproj file (defaults to {DEFAULT_PROJECT_FILE})')
    args = parser.parse_args()
    
    return analyze_project(args.project_file)

if __name__ == '__main__':
    sys.exit(main())
