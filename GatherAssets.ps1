<# Script to fetch files from skyrim game directory with configurable json-file.
 #
 # Authors: Elmeri Kemppainen (emepi)
 # Date: 6-11-2022
 #>
. ./Util/Get-ModBuild.ps1


function Search-SSEFiles {
    param(
        $Regex,             #Regex for filtering.
        $FilePath,          #Search location.
        $IncludeSubfolders, #Filter child directories.
        $target             #Destination for copied files.
    )

    #Retrieve appropriate files
    $Files = if ($IncludeSubfolders) {
        Get-ChildItem -Path $FilePath -File -recurse
    } else {
        Get-ChildItem -Path $FilePath -File
    }

    $Files | Where-Object {
        $_.Name -Match $Regex
    } | ForEach-Object {
        #Preserve relative paths of the game folder.
        $TargetPath = $Target + $_.DirectoryName.Remove(0, $Build.skyrimPath.Length)

        #Copy the matched files and make related directories.
        $_ | Copy-Item -Destination (New-Item -Force -Type Directory -Path $TargetPath)
    }
}

<# Recursive function to filter and copy relevant files in tracked files tree. #>
function Import-SSEProject {
    param (
        $TrackedFilesTree, #TrackedFiles object from Build.json or equivalent.
        $ParentFilters,    #Collection of inherited file filters.
        $FilePath          #Filepath matching the TrackedFilesTree node.
    )

    #Pointer to the json data object wrapped inside the base object. 
    $CurrentFolder = $TrackedFilesTree[0]

    #Create a node specific instance of filters.
    $ParentFilters = $ParentFilters.Clone()

    #Add inheritable filters if any.
    $TrackedFilesTree.include | Where-Object { ![String]::IsNullOrEmpty($_) } | ForEach-Object {
        [Void]$ParentFilters.add($_)
    }

    #Recurse through the child nodes.
    #NOTE: Any json-object member is assumed to be part of the file tree (a child node).
    $ChildNodes = $CurrentFolder.PSObject.Properties |
    Where-Object {
        $null -ne $_.Value -and [System.Management.Automation.PSCustomObject] -eq $_.Value.GetType()
    }
    $ChildNodes | ForEach-Object {
        Import-SSEProject $_.value $ParentFilters ($FilePath + "/" + $_.Name)
    }

    #Custom file destination.
    $Destination = if ($CurrentFolder.destination) {$CurrentFolder.destination} else {$Build.trackedFiles.destination}
    $Destination = $Destination.trimEnd("/")

    #File search for private filters.
    if ($CurrentFolder.files) {
        $Regex = $CurrentFolder.files -join "|"

        Search-SSEFiles $Regex $FilePath $false $Destination
    }

    #File search for inherited filters.
    if ($ParentFilters.Count -gt 0) {
        $Regex = $ParentFilters -join "|"

        #Filter subfolders if a leaf node.
        Search-SSEFiles $Regex $FilePath $($ChildNodes.Length -eq 0) $Destination
    }
}

<# Run the script with build.json configurations. #>
$Build = Get-ModBuild

if ($null -ne $Build -and $Build.trackedFiles)
{
    Import-SSEProject $Build.trackedFiles ([System.Collections.ArrayList]::new()) $Build.skyrimPath
}
