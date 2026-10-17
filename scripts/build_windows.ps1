param(
  [ValidateSet("build", "run", "smoke")]
  [string]$Mode = "build",
  [string]$GpuiRoot = "",
  [string]$TargetDir = ""
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Module = Join-Path $Root "windows-app"

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
  throw "cl.exe was not found. Run this from a Developer PowerShell for VS 2022, or initialize vcvars64.bat first."
}

$members = @('members = [', '  ".",', '  "..",')
if ($GpuiRoot) {
  if (-not (Test-Path -LiteralPath (Join-Path $GpuiRoot "platform/windows_app/moon.pkg"))) {
    throw "local gpui.mbt with platform/windows_app was requested but not found: $GpuiRoot"
  }
  $GpuiRoot = (Resolve-Path $GpuiRoot).Path
  $relative = [System.IO.Path]::GetRelativePath($Module, $GpuiRoot).Replace('\', '/')
  $members += "  `"$relative`","
}
$members += ']'
$members | Set-Content -LiteralPath (Join-Path $Module "moon.work") -Encoding ascii

if (-not $TargetDir) {
  $TargetDir = Join-Path $Root "build"
}
$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)
$MoonTarget = Join-Path $TargetDir "moon"
New-Item -ItemType Directory -Force $TargetDir | Out-Null

Push-Location $Module
try {
  $previousCl = $env:CL
  try {
    if ($IsWindows) {
      $env:CL = ("/EHsc $previousCl").Trim()
    }
    & moon build --target native --deny-warn --target-dir $MoonTarget src/windows
    if ($LASTEXITCODE -ne 0) {
      throw "moon build src/windows failed with exit code $LASTEXITCODE"
    }
  } finally {
    $env:CL = $previousCl
  }

  $exe = Get-ChildItem -Path (Join-Path $MoonTarget "native/debug/build") -Recurse -Filter "windows.exe" |
    Select-Object -First 1
  if (-not $exe) {
    throw "could not find windows.exe under $MoonTarget/native/debug/build"
  }

  switch ($Mode) {
    "build" {
      Write-Output $exe.FullName
    }
    "run" {
      & $exe.FullName
      if ($LASTEXITCODE -ne 0) {
        throw "Windows demo exited with $LASTEXITCODE"
      }
    }
    "smoke" {
      $smokeDir = Join-Path $TargetDir "windows-smoke"
      Remove-Item -LiteralPath $smokeDir -Recurse -Force -ErrorAction SilentlyContinue
      New-Item -ItemType Directory -Force $smokeDir | Out-Null
      $env:GPUI_NATIVE_E2E = "1"
      $env:GPUI_WINDOWS_READBACK = "1"
      $env:GPUI_SMOKE_DIR = "$smokeDir/"
      try {
        $output = & $exe.FullName --smoke 2>&1
        $status = $LASTEXITCODE
        $output | Tee-Object -FilePath (Join-Path $TargetDir "windows-smoke.log")
        if ($status -ne 0) {
          throw "Windows smoke exited with $status"
        }
        if (-not ($output -match "DEMO_SMOKE PASS")) {
          throw "Windows smoke did not report DEMO_SMOKE PASS"
        }
      } finally {
        Remove-Item Env:GPUI_NATIVE_E2E -ErrorAction SilentlyContinue
        Remove-Item Env:GPUI_WINDOWS_READBACK -ErrorAction SilentlyContinue
        Remove-Item Env:GPUI_SMOKE_DIR -ErrorAction SilentlyContinue
      }
      Write-Output "Windows smoke artifacts: $smokeDir"
    }
  }
} finally {
  Pop-Location
}
