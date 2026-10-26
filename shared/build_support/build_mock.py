MOCK = '''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\\n")
command = " ".join([name, *args])
if os.environ.get("FAIL_COMMAND") and command.startswith(os.environ["FAIL_COMMAND"]):
    sys.exit(1)
if name == "xcrun" and args[:2] == ["notarytool", "submit"]:
    print("mock submission result")
if name == "plutil":
    print(os.environ.get("NOTARY_STATUS", "Accepted"))
'''
