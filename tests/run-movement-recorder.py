"""Run the standalone recorder against a controlled Roblox API fixture.

Usage: python3 tests/run-movement-recorder.py /path/to/luau
Requires the Luau CLI; no Python packages or live Roblox session required.
"""

from pathlib import Path
import json
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "movement-recorder.luau").read_text()
fixture = (root / "tests/movement-recorder.spec.luau").read_text()
assert "]========]" not in source
fixture = fixture.replace("-- RECORDER_SOURCE", "local SOURCE = [========[" + source + "]========]")
with tempfile.TemporaryDirectory(prefix="ftf-recorder-tests-") as folder:
    script = Path(folder) / "fixture.luau"
    script.write_text(fixture)
    run = subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(script)], text=True, capture_output=True)
    if run.returncode:
        print(run.stdout)
        print(run.stderr, file=sys.stderr)
        raise SystemExit(run.returncode)
    exported = []
    for line in run.stdout.splitlines():
        if line.startswith("EXPORT "):
            exported.append(json.loads(line[7:]))
        else:
            print(line)
    assert exported and exported[0]["k"] == "header"
    assert any(x["k"] == "frame" for x in exported)
    assert any(x["k"] == "context" for x in exported)
    assert all(x.get("for_mode") in ("general", "autohelp", "autofarm", "autohide")
               for x in exported if x["k"] != "stop")
    raw = json.dumps(exported)
    assert "SecretPlayerName" not in raw and "DoNotRecordChat" not in raw
    print(f"PASS: exported JSONL independently decoded in Python ({len(exported)} records)")
