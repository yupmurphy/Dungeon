@echo off
rem Generates resources/items/*.tres from data/items/items.csv. Double-click after editing the table.
"D:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path "%~dp0.." -- --generate-items
pause
