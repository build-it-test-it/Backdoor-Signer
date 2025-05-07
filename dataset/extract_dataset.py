#!/usr/bin/env python3
"""
Simplified script to extract code-documentation pairs from the Backdoor-Signer codebase.
"""

import os
import re
import json
import glob
from pathlib import Path

def extract_code_docs_from_file(file_path):
    """Extract code and documentation pairs from a file."""
    pairs = []
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Skip empty files
        if not content.strip():
            return pairs
        
        # Get language based on file extension
        ext = os.path.splitext(file_path)[1].lower()
        if ext == '.swift':
            language = 'swift'
        elif ext in ['.cpp', '.mm']:
            language = 'cpp'
        elif ext in ['.h', '.hpp']:
            language = 'cpp'
        else:
            return pairs  # Skip unsupported file types
        
        # Get folder name for metadata (Shared or iOS)
        if "Shared" in file_path:
            folder = "Shared"
        elif "iOS" in file_path:
            folder = "iOS"
        else:
            folder = "Other"
        
        # Split content into lines for processing
        lines = content.split('\n')
        
        # Track current documentation comment block
        current_doc = ""
        
        # Process line by line
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            
            # Skip empty lines
            if not line:
                i += 1
                continue
            
            # Collect documentation comments
            if line.startswith('//'):
                # Single line comment
                if not current_doc:
                    current_doc = line[2:].strip()
                else:
                    current_doc += " " + line[2:].strip()
            
            # Check for class/struct/enum/protocol/extension declarations
            elif language == 'swift' and any(keyword in line for keyword in ['class ', 'struct ', 'enum ', 'protocol ', 'extension ']):
                # Extract declaration type and name
                match = re.search(r'(class|struct|enum|protocol|extension)\s+(\w+)', line)
                if match:
                    type_name = match.group(1)
                    item_name = match.group(2)
                    
                    # Collect the full declaration
                    declaration = line
                    j = i + 1
                    brace_count = 0
                    if '{' in line:
                        brace_count = 1
                    
                    # Get up to opening brace
                    while j < len(lines) and (brace_count == 0 or j < i + 10):
                        next_line = lines[j].strip()
                        declaration += "\n" + next_line
                        
                        if '{' in next_line:
                            brace_count += 1
                            break
                        
                        j += 1
                    
                    # Skip if we didn't find an opening brace
                    if brace_count == 0:
                        i += 1
                        continue
                    
                    # Generate documentation if missing
                    if not current_doc:
                        current_doc = generate_doc_for_type(type_name, item_name)
                    
                    # Add to pairs
                    pairs.append({
                        'code': declaration,
                        'nl': current_doc,
                        'language': language,
                        'file_path': file_path,
                        'folder': folder,
                        'code_type': type_name
                    })
                    
                    # Reset documentation
                    current_doc = ""
            
            # Check for function declarations
            elif language == 'swift' and 'func ' in line:
                match = re.search(r'func\s+(\w+)', line)
                if match:
                    func_name = match.group(1)
                    
                    # Collect the full declaration
                    declaration = line
                    j = i + 1
                    brace_count = 0
                    if '{' in line:
                        brace_count = 1
                    
                    # Get up to opening brace
                    while j < len(lines) and (brace_count == 0 or j < i + 10):
                        next_line = lines[j].strip()
                        declaration += "\n" + next_line
                        
                        if '{' in next_line:
                            brace_count += 1
                            break
                        
                        j += 1
                    
                    # Skip if we didn't find an opening brace
                    if brace_count == 0:
                        i += 1
                        continue
                    
                    # Generate documentation if missing
                    if not current_doc:
                        current_doc = generate_doc_for_function(func_name)
                    
                    # Add to pairs
                    pairs.append({
                        'code': declaration,
                        'nl': current_doc,
                        'language': language,
                        'file_path': file_path,
                        'folder': folder,
                        'code_type': 'function'
                    })
                    
                    # Reset documentation
                    current_doc = ""
            
            # Check for C++ class/struct declarations
            elif language == 'cpp' and ('class ' in line or 'struct ' in line):
                match = re.search(r'(class|struct)\s+(\w+)', line)
                if match:
                    type_name = match.group(1)
                    item_name = match.group(2)
                    
                    # Collect the full declaration
                    declaration = line
                    j = i + 1
                    brace_count = 0
                    if '{' in line:
                        brace_count = 1
                    
                    # Get up to opening brace
                    while j < len(lines) and (brace_count == 0 or j < i + 10):
                        next_line = lines[j].strip()
                        declaration += "\n" + next_line
                        
                        if '{' in next_line:
                            brace_count += 1
                            break
                        
                        j += 1
                    
                    # Skip if we didn't find an opening brace
                    if brace_count == 0:
                        i += 1
                        continue
                    
                    # Skip license headers
                    if current_doc and ("copyright" in current_doc.lower() or "license" in current_doc.lower()):
                        current_doc = ""
                    
                    # Generate documentation if missing
                    if not current_doc:
                        current_doc = generate_doc_for_type(type_name, item_name)
                    
                    # Add to pairs
                    pairs.append({
                        'code': declaration,
                        'nl': current_doc,
                        'language': language,
                        'file_path': file_path,
                        'folder': folder,
                        'code_type': type_name
                    })
                    
                    # Reset documentation
                    current_doc = ""
            
            # Check for C++ function declarations
            elif language == 'cpp' and re.search(r'\w+\s+\w+\s*\(', line) and not any(keyword in line for keyword in ['if', 'for', 'while', 'switch']):
                match = re.search(r'\w+\s+(\w+)\s*\(', line)
                if match:
                    func_name = match.group(1)
                    
                    # Collect the full declaration
                    declaration = line
                    j = i + 1
                    
                    # Continue to semicolon or opening brace
                    while j < len(lines) and ';' not in declaration and '{' not in declaration and j < i + 10:
                        declaration += "\n" + lines[j].strip()
                        j += 1
                    
                    # Skip license headers
                    if current_doc and ("copyright" in current_doc.lower() or "license" in current_doc.lower()):
                        current_doc = ""
                    
                    # Generate documentation if missing
                    if not current_doc:
                        current_doc = generate_doc_for_function(func_name)
                    
                    # Add to pairs
                    pairs.append({
                        'code': declaration,
                        'nl': current_doc,
                        'language': language,
                        'file_path': file_path,
                        'folder': folder,
                        'code_type': 'function'
                    })
                    
                    # Reset documentation
                    current_doc = ""
            
            # If we haven't matched any code pattern, reset the documentation unless it's a continuation
            elif not line.startswith('import ') and not line.startswith('#include '):
                current_doc = ""
                
            i += 1
                
        return pairs
    
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return []

def generate_doc_for_type(type_name, item_name):
    """Generate documentation for a class/struct/enum/protocol based on its name."""
    doc = f"{type_name} {item_name} - "
    
    # Add descriptions based on common naming conventions
    if item_name.endswith("Controller"):
        doc += "Controls user interface and application flow"
    elif item_name.endswith("View"):
        doc += "UI component for display and interaction"
    elif item_name.endswith("Model"):
        doc += "Data structure for storing application information"
    elif item_name.endswith("Manager"):
        doc += "Manages system resources and operations"
    elif item_name.endswith("Service"):
        doc += "Provides functionality to other components"
    elif item_name.endswith("Helper") or item_name.endswith("Utility"):
        doc += "Provides helper functions and utilities"
    else:
        # Split camelCase into words
        words = re.findall(r'[A-Z][a-z]*', item_name)
        if words:
            desc = ' '.join(words).lower()
            doc += f"implements functionality related to {desc}"
        else:
            doc += f"implements {item_name} functionality"
    
    return doc

def generate_doc_for_function(func_name):
    """Generate documentation for a function based on its name."""
    doc = f"Function {func_name} - "
    
    # Add descriptions based on common naming conventions
    if func_name.startswith("get"):
        doc += f"retrieves {func_name[3:].lower().replace('_', ' ')}"
    elif func_name.startswith("set"):
        doc += f"sets {func_name[3:].lower().replace('_', ' ')}"
    elif func_name.startswith("is"):
        doc += f"checks if {func_name[2:].lower().replace('_', ' ')}"
    elif func_name.startswith("has"):
        doc += f"checks if it has {func_name[3:].lower().replace('_', ' ')}"
    elif func_name.startswith("update"):
        doc += f"updates {func_name[6:].lower().replace('_', ' ')}"
    elif func_name.startswith("create"):
        doc += f"creates {func_name[6:].lower().replace('_', ' ')}"
    elif func_name.startswith("delete"):
        doc += f"deletes {func_name[6:].lower().replace('_', ' ')}"
    elif func_name == "init":
        doc += "initializes the object"
    elif func_name == "deinit":
        doc += "cleans up resources when the object is deallocated"
    else:
        doc += f"implements {func_name.lower().replace('_', ' ')} functionality"
    
    return doc

def main():
    """Process files and build dataset."""
    # Set directories
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_dir = os.path.dirname(os.path.abspath(__file__))
    target_dirs = ['Shared', 'iOS']
    
    # Collect code-doc pairs
    all_pairs = []
    
    # Process Swift files
    for target_dir in target_dirs:
        print(f"Processing {target_dir} directory...")
        
        # Swift files
        swift_files = glob.glob(f"{base_dir}/{target_dir}/**/*.swift", recursive=True)
        for file_path in swift_files:
            rel_path = os.path.relpath(file_path, base_dir)
            pairs = extract_code_docs_from_file(file_path)
            all_pairs.extend(pairs)
            print(f"Processed {rel_path}: found {len(pairs)} pairs")
        
        # C++ files
        cpp_files = glob.glob(f"{base_dir}/{target_dir}/**/*.cpp", recursive=True)
        cpp_files.extend(glob.glob(f"{base_dir}/{target_dir}/**/*.mm", recursive=True))
        for file_path in cpp_files:
            rel_path = os.path.relpath(file_path, base_dir)
            pairs = extract_code_docs_from_file(file_path)
            all_pairs.extend(pairs)
            print(f"Processed {rel_path}: found {len(pairs)} pairs")
        
        # Header files
        h_files = glob.glob(f"{base_dir}/{target_dir}/**/*.h", recursive=True)
        h_files.extend(glob.glob(f"{base_dir}/{target_dir}/**/*.hpp", recursive=True))
        for file_path in h_files:
            rel_path = os.path.relpath(file_path, base_dir)
            pairs = extract_code_docs_from_file(file_path)
            all_pairs.extend(pairs)
            print(f"Processed {rel_path}: found {len(pairs)} pairs")
    
    # Format for CodeBERT
    codebert_dataset = []
    for i, pair in enumerate(all_pairs):
        codebert_entry = {
            "id": str(i),
            "code": pair["code"],
            "nl": pair["nl"],
            "language": pair["language"],
            "folder": pair["folder"],
            "file_path": pair["file_path"],
            "code_type": pair["code_type"]
        }
        codebert_dataset.append(codebert_entry)
    
    # Save as JSON
    json_file = os.path.join(output_dir, "codebert_dataset.json")
    with open(json_file, 'w', encoding='utf-8') as f:
        json.dump(codebert_dataset, f, indent=2)
    
    # Save as CSV for easier viewing
    csv_file = os.path.join(output_dir, "codebert_dataset.csv")
    with open(csv_file, 'w', encoding='utf-8') as f:
        # Write header
        f.write("id,language,folder,code_type,file_path,nl,code\n")
        
        # Write data with CSV escaping
        for item in codebert_dataset:
            nl = item["nl"].replace('"', '""')
            code = item["code"].replace('"', '""')
            file_path = item["file_path"].replace('"', '""')
            
            f.write(f'{item["id"]},{item["language"]},{item["folder"]},{item["code_type"]},"{file_path}","{nl}","{code}"\n')
    
    # Generate statistics
    languages = {}
    folders = {}
    code_types = {}
    
    for item in codebert_dataset:
        lang = item["language"]
        folder = item["folder"]
        code_type = item["code_type"]
        
        languages[lang] = languages.get(lang, 0) + 1
        folders[folder] = folders.get(folder, 0) + 1
        code_types[code_type] = code_types.get(code_type, 0) + 1
    
    # Print statistics
    print(f"\nDataset generation complete!")
    print(f"Total code-documentation pairs extracted: {len(codebert_dataset)}")
    print(f"Dataset saved to: {json_file}")
    print(f"CSV version saved to: {csv_file}")
    
    print("\nDistribution by language:")
    for lang, count in sorted(languages.items(), key=lambda x: x[1], reverse=True):
        print(f"  {lang}: {count} ({count/len(codebert_dataset)*100:.1f}%)")
    
    print("\nDistribution by folder:")
    for folder, count in sorted(folders.items(), key=lambda x: x[1], reverse=True):
        print(f"  {folder}: {count} ({count/len(codebert_dataset)*100:.1f}%)")
    
    print("\nDistribution by code type:")
    for code_type, count in sorted(code_types.items(), key=lambda x: x[1], reverse=True):
        print(f"  {code_type}: {count} ({count/len(codebert_dataset)*100:.1f}%)")
    
    # Update README with statistics
    try:
        with open(os.path.join(output_dir, "README.md"), 'r', encoding='utf-8') as f:
            readme = f.read()
        
        # Update statistics
        readme = readme.replace("- Total pairs: (will be filled in after generation)", 
                                f"- Total pairs: {len(codebert_dataset)}")
        
        # Language stats
        lang_stats = []
        for lang, count in sorted(languages.items(), key=lambda x: x[1], reverse=True):
            lang_stats.append(f"  - {lang}: {count} ({count/len(codebert_dataset)*100:.1f}%)")
        readme = readme.replace("- Language distribution: (will be filled in after generation)", 
                                f"- Language distribution:\n" + "\n".join(lang_stats))
        
        # Code type stats
        code_type_stats = []
        for code_type, count in sorted(code_types.items(), key=lambda x: x[1], reverse=True):
            code_type_stats.append(f"  - {code_type}: {count} ({count/len(codebert_dataset)*100:.1f}%)")
        readme = readme.replace("- Code type distribution: (will be filled in after generation)", 
                                f"- Code type distribution:\n" + "\n".join(code_type_stats))
        
        with open(os.path.join(output_dir, "README.md"), 'w', encoding='utf-8') as f:
            f.write(readme)
        
        print("\nREADME updated with statistics")
    except Exception as e:
        print(f"Error updating README: {e}")

if __name__ == "__main__":
    main()
