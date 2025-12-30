@echo off
python -u "%~dp0predict.py" %*
IF %ERRORLEVEL% NEQ 0 (
    echo Python script failed with error level %ERRORLEVEL% 1>&2
    exit /b %ERRORLEVEL%
)
