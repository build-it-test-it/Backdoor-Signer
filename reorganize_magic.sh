#!/bin/bash
set -e

# Create new directory structure
mkdir -p Shared/Magic/Signing
mkdir -p Shared/Magic/Security
mkdir -p Shared/Magic/FileHandling

# Add a TODO to empty BackdoorCLI.swift
echo "import Foundation

// TODO: Implement BackdoorCLI functionality
// This file is intended to provide CLI capabilities for the Backdoor app
" > Shared/Magic/BackdoorCLI.swift

# Move Signing-related files
mv Shared/Magic/AppSigner.swift Shared/Magic/Signing/
mv Shared/Magic/TweakHandler.swift Shared/Magic/Signing/
mv Shared/Magic/esign Shared/Magic/Signing/
mv Shared/Magic/zsign Shared/Magic/Signing/

# Move Security-related files
mv Shared/Magic/BackdoorEncryption.swift Shared/Magic/Security/
mv Shared/Magic/openssl_tools.hpp Shared/Magic/Security/
mv Shared/Magic/openssl_tools.mm Shared/Magic/Security/

# Move FileHandling-related files
mv Shared/Magic/BackdoorFileHandler.swift Shared/Magic/FileHandling/
mv Shared/Magic/decompression Shared/Magic/FileHandling/

# Move the bridging header to the root of Magic
# It needs to stay at this level for proper inclusion
# mv Shared/Magic/backdoor-Bridging-Header.h Shared/Magic/

echo "Magic directory reorganized successfully!"
