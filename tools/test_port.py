#!/usr/bin/env python3
"""Native smoke suite. Never requires Node, a browser, or the reference source."""
import concurrent.futures, json, os, pathlib, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
CASES=[('tidewater','turf'),('kelpline','turf'),('halyard','zones'),('saltpan','zones'),('crossmarket','turf'),('lockgate','zones'),('terraces','boss')]
def run(case):
    stage, mode=case
    command=[GODOT,'--headless','--path',str(ROOT),'--fixed-fps','60','--','--smoke','--seconds=6',f'--map={stage}',f'--mode={mode}']
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
    log=result.stdout
    (ROOT/'tests'/f'{stage}.log').write_text(log)
    passed=result.returncode==0 and 'SMOKE_RESULT' in log and 'SCRIPT ERROR' not in log and 'ERROR:' not in log
    return {'stage':stage,'mode':mode,'passed':passed,'exit':result.returncode}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results=list(pool.map(run,CASES))
print(json.dumps(results,indent=2))
(ROOT/'tests'/'smoke_results.json').write_text(json.dumps(results,indent=2)+'\n')
sys.exit(0 if all(r['passed'] for r in results) else 1)
