function jidem {
    Set-Location "$HOME\Documents"
}

function academia {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Academia"
    }
    else {
        Write-Host "Academia is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function dissertation {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Academia\Dissertation"
    }
    else {
        Write-Host "Dissertation is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function research {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Academia\Research"
    }
    else {
        Write-Host "Research is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function writing {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Academia\Writing"
    }
    else {
        Write-Host "Writing is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function development {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Development"
    }
    else {
        Write-Host "Development is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function personaleditor {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Development\Personal-Editor"
    }
    else {
        Write-Host "Personal Editor is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function pythonwork {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Development\Python"
    }
    else {
        Write-Host "Python development is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function rwork {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\Development\R"
    }
    else {
        Write-Host "R development is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function github {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\GitHub"
    }
    else {
        Write-Host "GitHub workspace is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function inbox {
    if ($HOME -eq "C:\Users\jidem") {
        Set-Location "$HOME\Documents\ACADEMIC\00_INBOX"
    }
    else {
        Write-Host "Academic inbox is assigned to the JIDEM account." -ForegroundColor Yellow
    }
}

function archive {
    Set-Location "$HOME\Documents\Archive"
}
function school {
    Set-Location "$HOME\Documents\UC-Merced"
}

function courses {
    Set-Location "$HOME\Documents\UC-Merced\Courses"
}

function ta {
    Set-Location "$HOME\Documents\UC-Merced\TA"
}

function teaching {
    Set-Location "$HOME\Documents\UC-Merced\Teaching"
}

function university {
    Set-Location "$HOME\Documents\UC-Merced\University"
}

function admin {
    Set-Location "$HOME\Documents\UC-Merced\Administration"
}

function currentwork {
    Set-Location "$HOME\Documents\Current-Work"
}

function shared {
    # The bridge between JIDEM and MAKIN: one folder both accounts can open.
    $bridge = "C:\Users\Public\Documents\Shared"
    if (Test-Path $bridge) {
        Set-Location $bridge
    }
    else {
        Write-Host "Shared folder not found: $bridge" -ForegroundColor Yellow
        Write-Host "Create it with: New-Item -ItemType Directory -Path '$bridge'"
    }
}

function makinarchive {
    Set-Location "$HOME\Documents\Archive"
}
