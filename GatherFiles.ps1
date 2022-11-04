<# Script to fetch files from skyrim game directory with configurable json-file.
 #
 # Authors: Elmeri Kemppainen (emepi)
 # Date: 4-11-2022
 #>


function CopyFilteredGameFiles {
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
        $TargetPath = $Target + ($_.DirectoryName.Remove(0, $build.skyrimPath.Length + 1))

        #Copy the matched files and make related directories.
        $_ | Copy-Item -Destination (New-Item -Force -Type Directory -Path $TargetPath)
    }
}

<# Recursive function to filter and copy relevant files in tracked files tree. #>
function GatherTrackedFiles {
    param (
        $TrackedFilesTree, #TrackedFiles object from build.json or equivalent.
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
        GatherTrackedFiles $_.value $ParentFilters ($FilePath + "/" + $_.Name)
    }

    #File search for private filters.
    if ($CurrentFolder.files) {
        $Regex = $CurrentFolder.files -join "|"

        CopyFilteredGameFiles $Regex $FilePath $false "target/"
    }

    #File search for inherited filters.
    if ($ParentFilters.Count -gt 0) {
        $Regex = $ParentFilters -join "|"

        #Filter subfolders if a leaf node.
        CopyFilteredGameFiles $Regex $FilePath $($ChildNodes.Length -eq 0) "target/"
    }
}

<# Run the script with build.json configurations. #>

$build = (Get-Content "build.json" -Raw) | ConvertFrom-Json

#Trim a trailing slash from the file path if present.
$build.skyrimPath = $build.skyrimPath.trimEnd("/")

if ($build.trackedFiles)
{
    GatherTrackedFiles $build.trackedFiles ([System.Collections.ArrayList]::new()) $build.skyrimPath
}
