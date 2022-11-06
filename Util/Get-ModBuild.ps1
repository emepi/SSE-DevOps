<# Script to handle build.json standards.
 #
 # Authors: Elmeri Kemppainen (emepi)
 # Date: 6-11-2022
 #>

function Get-ModBuild {
    #Expect build.json to exist in the folder where function is being called.
    Try {
        $Build = (Get-Content "build.json" -Raw -ErrorAction Stop) | ConvertFrom-Json

        #Trim a trailing slash from the file path if present.
        $Build.skyrimPath = $Build.skyrimPath.trimEnd("/")
        
        #Default to current folder if destination is not set.
        if (!$Build.trackedFiles.destination) {
            $Build.trackedFiles | Add-Member -MemberType NoteProperty -Name destination -Value "."
        }

        return $Build
    } 
    Catch {
        Write-Output "Build.json not found! Command shall be used in the project root folder containing the build.json configuration."
    }

    return $null
}