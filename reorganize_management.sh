#!/bin/bash
set -e

# Create new directory structure
mkdir -p Shared/Management/Network
mkdir -p Shared/Management/Downloads
mkdir -p Shared/Management/Cloud
mkdir -p Shared/Management/Utilities

# Move Network-related files
mv Shared/Management/NetworkManager*.swift Shared/Management/Network/

# Move Download-related files
mv Shared/Management/AppDownload.swift Shared/Management/Downloads/
mv Shared/Management/DownloadTaskManager.swift Shared/Management/Downloads/
mv Shared/Management/SourceDownload.swift Shared/Management/Downloads/
mv Shared/Management/iTunesLookup.swift Shared/Management/Downloads/

# Move Cloud-related files
mv Shared/Management/DropboxService.swift Shared/Management/Cloud/
mv Shared/Management/EnhancedDropboxService.swift Shared/Management/Cloud/
mv Shared/Management/MinimalDropboxService.swift Shared/Management/Cloud/

# Move Utility files
mv Shared/Management/BundleIdChecker.swift Shared/Management/Utilities/
mv Shared/Management/CertData.swift Shared/Management/Utilities/
mv Shared/Management/ImageCache.swift Shared/Management/Utilities/

echo "Management directory reorganized successfully!"
