############################
# download offline packages helper
############################
mkdir -p /nexus
cat << 'EOF' > "/nexus/download-upload-rpms.sh"
#!/bin/bash

# ---------------------------
# Dynamic Configuration Input
# ---------------------------
# Input for Nexus URL (Press Enter for default)
read -p "Enter Nexus URL [http://10.10.0]: " NEXUS_URL
NEXUS_URL="${NEXUS_URL:-http://10.10.0}"

# Input for Username (Press Enter for default)
read -p "Enter Nexus Username [admin]: " NEXUS_USER
NEXUS_USER="${NEXUS_USER:-admin}"

# Input for Password (Hidden while typing. Type your exact password, even with $)
read -s -p "Enter Nexus Password: " NEXUS_PASS
echo "" # Prints a new line after password entry

# Input for Packages (Mandatory input)
while true; do
    read -p "Enter packages to download (separated by space): " PACKAGES
    # Check if the user entered anything
    if [ -n "$PACKAGES" ]; then
        break
    else
        echo "Error: You must enter at least one package name."
    fi
done

# ---------------------------
# Temporary download directory
# ---------------------------
TEMP_DIR="/tmp/nexus_rpms"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# ---------------------------
# Download packages and dependencies
# ---------------------------
echo "Downloading packages: $PACKAGES ..."
for pkg in $PACKAGES; do
    yumdownloader --resolve "$pkg"
done

# ---------------------------
# Upload RPMs to Nexus
# ---------------------------
echo "Uploading RPMs to Nexus..."
for rpm in *.rpm; do
    # Check if files actually exist to avoid loop errors
    [ -e "$rpm" ] || continue
    
    echo "Uploading $rpm ..."
    
    # Double quotes around variables ensure '$' inside the password is read literally
    curl -f -u "${NEXUS_USER}:${NEXUS_PASS}" \
         --upload-file "$rpm" \
         "${NEXUS_URL}${rpm}"

    if [ $? -eq 0 ]; then
        echo "SUCCESS: $rpm"
    else
        echo "FAILED: $rpm"
    fi
done

echo "All uploads completed."

EOF

############################
# download offline repo helper
############################
cat << 'EOF' > "/nexus/download-upload-repo.sh"
#!/bin/bash
# ---------------------------
# Dynamic Configuration Input
# ---------------------------
read -p "Enter Nexus URL [http://10.10.0]: " NEXUS_URL
NEXUS_URL=${NEXUS_URL:-http://10.10.0}

read -p "Enter Nexus Username [admin]: " NEXUS_USER
NEXUS_USER=${NEXUS_USER:-admin}

read -s -p "Enter Nexus Password: " NEXUS_PASS
echo 

while true; do
    read -p "Enter Repository IDs to download (e.g., epel) separated by space: " PACKAGES
    if [ -n "$PACKAGES" ]; then
        break
    else
        echo "Error: You must enter at least one repository ID."
    fi
done

# ---------------------------
# Temporary download directory
# ---------------------------
TEMP_DIR=/tmp/nexus_repo
mkdir -p $TEMP_DIR
cd $TEMP_DIR || exit 1

# ---------------------------
# Download entire repositories (With Metadata)
# ---------------------------
echo "Downloading repositories and metadata: $PACKAGES ..."
for pkg in $PACKAGES; do
    # --download-metadata pulls repomd.xml and repo layout indexes
    dnf reposync --repo=$pkg -p . --downloadonly --download-metadata
done

# ---------------------------
# Smart Upload Loop (Preserves Layout & Skips Existing Assets)
# ---------------------------
echo "Scanning layout, uploading metadata, and syncing files to Nexus..."

# Use find to locate EVERY file (RPMs, XMLs, metadata) to preserve the full mirror structure
find . -type f | while read -r file_path; do
    # Strip the leading './' to get the clean relative directory path
    clean_path=${file_path#./}
    
    # 1. Skip temporary or hidden system tracking files if they exist
    [[ "$clean_path" == .drpm* ]] && continue

    # 2. Check if the file already exists on Nexus via a quick HTTP HEAD check
    # Exception: Always re-upload metadata files (like xml) because they change when a repo updates
    if [[ "$clean_path" == *.rpm ]]; then
        curl -s -I -u "${NEXUS_USER}:${NEXUS_PASS}" "${NEXUS_URL}/${clean_path}" | grep -q "HTTP/.* 200"
        if [ $? -eq 0 ]; then
            echo "EXISTS: ${clean_path} is already on Nexus. Skipping..."
            continue
        fi
    fi
    
    # 3. Upload the file keeping its exact relative structural directory path
    echo "UPLOADING: ${clean_path} ..."
    curl -f -u "${NEXUS_USER}:${NEXUS_PASS}" \
        --upload-file "$file_path" \
        "${NEXUS_URL}/${clean_path}"
        
    if [ $? -eq 0 ]; then
        echo "SUCCESS: ${clean_path}"
    else
        echo "FAILED: ${clean_path}"
    fi
done

echo "All tasks completed. Perfect structural repository mirror successfully established."

EOF
