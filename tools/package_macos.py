#!/usr/bin/env python3
"""Package an offline macOS app using the installed Godot binary and an exported PCK.
No download, export-template installation, signing identity, or browser is needed.
"""
import os,pathlib,plistlib,shutil,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
godot=pathlib.Path(os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot'))
out=root/'builds'
app=out/'INKWAVE.app'
exe=app/'Contents'/'MacOS'
resources=app/'Contents'/'Resources'
exe.mkdir(parents=True,exist_ok=True)
resources.mkdir(parents=True,exist_ok=True)
subprocess.run([str(godot),'--headless','--path',str(root),'--export-pack','Desktop Pack',str(resources/'inkwave.pck')],check=True)
shutil.copy2(godot,exe/'GodotRuntime')
launcher='''#!/bin/sh
INKWAVE_APP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec "$INKWAVE_APP_DIR/MacOS/GodotRuntime" --main-pack "$INKWAVE_APP_DIR/Resources/inkwave.pck" "$@"
'''
(exe/'INKWAVE').write_text(launcher)
(exe/'INKWAVE').chmod(0o755)
icon=root/'source_reference/build/icon.icns'
if icon.exists():shutil.copy2(icon,resources/'icon.icns')
info={'CFBundleName':'INKWAVE','CFBundleDisplayName':'INKWAVE','CFBundleExecutable':'INKWAVE','CFBundleIdentifier':'org.inkwave.godot','CFBundleVersion':'1','CFBundleShortVersionString':'0.1.0','CFBundlePackageType':'APPL','CFBundleIconFile':'icon.icns','NSHighResolutionCapable':True,'LSMinimumSystemVersion':'12.0'}
with (app/'Contents/Info.plist').open('wb') as f:plistlib.dump(info,f)
shutil.copy2(root/'LICENSE',resources/'INKWAVE-LICENSE.txt')
for license_file in (root/'assets/licenses').glob('*.txt'):shutil.copy2(license_file,resources/license_file.name)
for license_file in (root/'assets/fonts').glob('*-OFL.txt'):shutil.copy2(license_file,resources/license_file.name)
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
print(app)
