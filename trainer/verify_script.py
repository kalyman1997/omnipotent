"""Verify the compiled loop retains the proven field-only VM layout."""
import hashlib
import json
from pathlib import Path
import re
import sys
from controller import FLAGS, NUMERIC_FLAGS, PROTOCOL


def script_hash(name):
    name = name.lower().replace("\\", "/")
    value = 0x1C2F2E3C8A257D07
    for character in name[0] + "zt@f3yp(d[kkd=_@" + name[1:]:
        value = ((value ^ ord(character)) * 0x10000000233) & 0xFFFFFFFFFFFFFFFF
    return value


def verify(decompiled_path):
    root = Path(__file__).resolve().parent
    source = root / "kronos/codex_solo_trainer.gsc"
    text = source.read_text(encoding="utf-8-sig")
    compiled = Path(decompiled_path).read_text(encoding="utf-8-sig")
    name = f"function_{script_hash('codex_solo_trainer_loop'):x}"
    loop = re.search(r"function " + name + r"\(\)\s*gscasm \{(.*?)\n\}", compiled, re.S)
    assert loop, "Main loop not found in the decompiled bytecode"
    forbidden = re.findall(r"\b(?:\w*CachedLocal\w*|\w*RegisterLocal\w*|SafeCreateLocalVariables|Modulus|Inc)\b", loop[1])
    assert not forbidden, forbidden
    fields = sorted(set(re.findall(r"\b(?:level|player|self)\.(codex_\w+)", text)))
    assert len({script_hash(field) for field in fields}) == len(fields), "Field hash collision"
    for flag in FLAGS:
        assert f'nengine_store_get("codexcmd", "{flag}")' in text, flag
        assert f'nengine_store_set("codexack", "{flag}",' in text, flag
    for flag in NUMERIC_FLAGS:
        assert f'nengine_store_get("codexcmd", "{flag}_value")' in text, flag
    assert f'nengine_store_set("codexack", "protocol", {PROTOCOL})' in text
    report = dict(protocol=PROTOCOL, flags=sorted(FLAGS), numeric_flags=sorted(NUMERIC_FLAGS),
                  loop=name, forbidden_loop_opcodes=forbidden, unique_fields=len(fields),
                  source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  note="Static compiled-layout/schema validation; not gameplay validation.")
    (root / "kronos/build/static-validation-v7.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    verify(sys.argv[1])
