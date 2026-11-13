@echo off
REM Pre-commit secret scan (gitleaks via Docker). Bypass forbidden by policy except explicit approval.
REM To enable: git config core.hooksPath .githooks

set REPO_ROOT=%~dp0..
set REPO_ROOT=%REPO_ROOT:\=/%

docker run --rm -v "%REPO_ROOT%:/repo" zricethezav/gitleaks:latest protect --staged --source /repo --redact --verbose
if errorlevel 1 (
    echo gitleaks pre-commit scan failed; commit blocked. >&2
    exit /b 1
)