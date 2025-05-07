# Backdoor-Signer CodeBERT Dataset

This dataset contains code-documentation pairs extracted from the Backdoor-Signer repository, formatted for training CodeBERT models. The dataset focuses on Swift, Objective-C++, and C++ code from the iOS app.

## Dataset Format

The dataset is available in two formats:

1. **JSON** (`codebert_dataset.json`): Structured data following the CodeBERT format
2. **CSV** (`codebert_dataset.csv`): Tabular format for easy viewing

Each entry in the dataset contains:
- **id**: Unique identifier
- **code**: Code snippet (function, class, struct, etc.)
- **nl**: Natural language description or documentation
- **language**: Programming language (swift, cpp, objc)
- **folder**: Source folder (Shared, iOS)
- **file_path**: Original file location
- **code_type**: Type of code snippet (function, class, struct, enum, protocol)

## Extraction Process

The dataset was created by:
1. Analyzing Swift, C++, and header files from the Shared and iOS directories
2. Extracting functions, methods, classes, and structs along with their documentation
3. For undocumented code, generating descriptive natural language based on naming conventions
4. Cleaning and formatting the data for CodeBERT compatibility

## Usage

This dataset can be used to fine-tune CodeBERT models for:
- Code understanding and documentation generation
- Code search based on natural language queries
- Code completion with documentation context

## Statistics

- Total pairs: 3478
- Language distribution:
  - swift: 2899 (83.4%)
  - cpp: 579 (16.6%)
- Code type distribution:
  - function: 2791 (80.2%)
  - extension: 248 (7.1%)
  - class: 203 (5.8%)
  - struct: 133 (3.8%)
  - enum: 92 (2.6%)
  - protocol: 11 (0.3%)
