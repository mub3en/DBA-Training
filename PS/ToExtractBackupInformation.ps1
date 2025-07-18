# Define the base directory
##This goes two level down - for example: D:\Root\Client_name\FULL\<backup_file>.bak
$baseDirectory = "<Root directory>"

# Function to get and sort .bak files by size
function Check-And-Sort-BackupFiles {
    # Create a collection to hold backup file details
    $backupFiles = @()

    # Get all directories under the base directory
    $clientFolders = Get-ChildItem -Path $baseDirectory -Directory

    foreach ($clientFolder in $clientFolders) {
        # Define the 'FULL' folder path for the client
        $fullFolderPath = Join-Path -Path $clientFolder.FullName -ChildPath "FULL"

        # Check if 'FULL' folder exists
        if (Test-Path -Path $fullFolderPath) {
            # Get all .bak files in the 'FULL' folder
            $bakFiles = Get-ChildItem -Path $fullFolderPath -Filter "*.bak" -File

            # Add each file to the collection with details
            foreach ($file in $bakFiles) {
                $backupFiles += [pscustomobject]@{
                    Client          = $clientFolder.Name
                    FileName        = $file.Name
                    FilePath        = $file.FullName
                    FileSizeInMB    = [math]::Round(($file.Length / 1MB), 2)
                    LastModified    = $file.LastWriteTime
                }
            }
        }
    }

    # Sort the results by file size in descending order
    $sortedBackupFiles = $backupFiles | Sort-Object -Property FileSizeInMB -Descending

    # Output the results
    foreach ($backup in $sortedBackupFiles) {
        Write-Output "Client: $($backup.Client)"
        Write-Output "  File: $($backup.FileName)"
        Write-Output "  Path: $($backup.FilePath)"
        Write-Output "  Size: $($backup.FileSizeInMB) MB"
        Write-Output "  Last Modified: $($backup.LastModified)"
        Write-Output ""
    }
}

# Run the function
Check-And-Sort-BackupFiles
