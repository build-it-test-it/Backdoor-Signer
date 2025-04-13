# Dependency Management Scripts

This directory contains scripts for managing dependencies in the backdoor project.

## Add Dependencies Script

The `add_dependency.py` script automates the process of adding Swift Package Manager dependencies to the project. It updates both the `project.pbxproj` and `Package.resolved` files with the correct formatting and linking.

### Prerequisites

- Python 3.6 or higher
- The script should be run from the root directory of the project

### Usage

1. Create a JSON file containing the dependencies you want to add (see example format below)
2. Run the script with the JSON file as an argument:

```bash
python scripts/add_dependency.py path/to/dependencies.json
```

### Example Dependencies File Format

The dependencies file should be a JSON array containing objects with the following properties:

```json
[
  {
    "name": "PackageName",
    "url": "https://github.com/author/package.git",
    "requirement": {
      "kind": "upToNextMajorVersion",
      "minimumVersion": "1.0.0"
    },
    "products": ["ProductName1", "ProductName2"]
  }
]
```

#### Supported Requirement Types

- **Up to Next Major Version**:
  ```json
  "requirement": {
    "kind": "upToNextMajorVersion",
    "minimumVersion": "1.0.0"
  }
  ```

- **Exact Version**:
  ```json
  "requirement": {
    "kind": "exactVersion",
    "version": "1.2.3"
  }
  ```

- **Branch**:
  ```json
  "requirement": {
    "kind": "branch",
    "branch": "main"
  }
  ```

- **Revision (specific commit)**:
  ```json
  "requirement": {
    "kind": "revision",
    "revision": "abcdef123456789"
  }
  ```

### Example

A sample dependencies file is included at `scripts/sample-dependencies.json`. You can use it as a reference or test the script with:

```bash
python scripts/add_dependency.py scripts/sample-dependencies.json
```

## Add Single Dependency Script

For convenience, a bash script is provided to quickly add a single dependency without having to create a JSON file:

```bash
./scripts/add_single_dependency.sh --name PackageName --url https://github.com/author/package.git --kind upToNextMajorVersion --version 1.0.0 --products Product1,Product2
```

### Examples

```bash
# Add a dependency with version requirement
./scripts/add_single_dependency.sh --name SDWebImage --url https://github.com/SDWebImage/SDWebImage.git --kind upToNextMajorVersion --version 5.18.3 --products SDWebImage,SDWebImageMapKit

# Add a dependency with branch requirement
./scripts/add_single_dependency.sh --name SwiftUIX --url https://github.com/SwiftUIX/SwiftUIX.git --kind branch --branch main --products SwiftUIX
```

Make sure to make the script executable first:

```bash
chmod +x scripts/add_single_dependency.sh
```

### Notes

- The script creates backups of the original files before making any changes
- For dependencies using version requirements, the script will add placeholder revision hashes that Xcode will update on the next build
- If a package with the same name or URL already exists in Package.resolved, it will be updated
