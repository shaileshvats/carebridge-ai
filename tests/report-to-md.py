#!/usr/bin/env python3
"""Turn tests/reports/latest.json (written by CareBridge.Test.Runner) into tests/reports/test-report.md."""
import json, sys
src = sys.argv[1] if len(sys.argv) > 1 else "tests/reports/latest.json"
out = sys.argv[2] if len(sys.argv) > 2 else "tests/reports/test-report.md"
r = json.load(open(src))
EXPECT = {
    "HL7Parser": "Fields parsed / framing tolerated / non-HL7 rejected / hash semantics",
    "Recommendation": "Contract enforced exactly",
    "Validator": "Correct findings and primary exception type",
    "PolicyGate": "Unsafe or unsupported actions refused; safe fallback",
    "Safety": "Immutability, append-only audit, data minimisation",
    "Integration": "End-to-end behaviour through the running production",
}
lines = [
    "# Test report", "",
    f"- **Run:** {r['startedAt']} → {r['finishedAt']} (UTC)",
    f"- **Environment:** {r['iris']}",
    f"- **Agent mode during tests:** {r['agentMode']} (integration tests force REPLAY for determinism)",
    f"- **Result:** {r['passed']} passed, {r['failed']} failed", "",
    "| Class | Test | Expected | Result | Duration (s) | Failures |", "|---|---|---|---|---|---|",
]
for t in r["tests"]:
    short = t["class"].split(".")[-1]
    lines.append(f"| {short} | {t['test']} | {EXPECT.get(short, '')} | {t['result']} | {float(t['durationSec'] or 0):.3f} | {'; '.join(t['failures'])} |")
open(out, "w").write("\n".join(lines) + "\n")
print(out)
