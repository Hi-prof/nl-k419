#!/usr/bin/env bash
# 修补公开分支里"引用了但没给"的 Kconfig。
#
# 现象：oppo-source 公开分支里部分厂商目录（如 block/uxio_first）被省略，
# 但上层 Kconfig 仍然 source 它，导致
#     block/Kconfig:251: can't open file "block/uxio_first/Kconfig"
#     make[1]: *** [scripts/kconfig/Makefile:69: olddefconfig] Error 1
# 处理：把所有指向不存在文件的 source "..." 行注释掉（只注释，不删）。
#
# 用法：./compat/prep_source.sh ksrc
set -euo pipefail

K="${1:?用法: prep_source.sh <内核树目录>}"
[ -d "$K" ] || { echo "::error::$K 不存在"; exit 1; }

python3 - "$K" <<'PY'
import os, re, sys, glob

K = sys.argv[1]
patched = []
missing = []

for path in glob.glob(os.path.join(K, "**", "Kconfig*"), recursive=True):
    try:
        src = open(path, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    out, mod = [], False
    for ln in src.splitlines(True):
        m = re.match(r'\s*source\s+"([^"]+)"', ln)
        if m:
            tgt = m.group(1)
            if not tgt.startswith("$"):
                cand = os.path.normpath(os.path.join(os.path.dirname(path), tgt))
                cand2 = os.path.normpath(os.path.join(K, tgt))
                if not os.path.exists(cand) and not os.path.exists(cand2):
                    missing.append(os.path.relpath(cand, K))
                    out.append("# NL-STRIPPED (missing): " + ln)
                    mod = True
                    continue
        out.append(ln)
    if mod:
        open(path, "w", encoding="utf-8").write("".join(out))
        patched.append(os.path.relpath(path, K))

print("== 被注释掉的缺失引用 (%d 处) ==" % len(missing))
for m in missing[:40]:
    print("   -", m)
print("== 被修改的 Kconfig 文件 (%d 个) ==" % len(patched))
for p in patched[:40]:
    print("   *", p)
PY

# 公开树里的 scripts/gcc-wrapper.py 是 python2 写法；只在用它时才需要治，
# 我们在 make 时显式传 CC，所以这里只做兜底修一下 print 语法。
W="$K/scripts/gcc-wrapper.py"
if [ -f "$W" ] && grep -qE '^\s*print\s+"' "$W"; then
    python3 - "$W" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="ignore").read()
s = re.sub(r'print\s+"([^"]*)"\s*,\s*([^\n]+)', r'print("\1", \2)', s)
s = re.sub(r'print\s+"([^"]*)"\s*$', r'print("\1")', s, flags=re.M)
open(p, "w", encoding="utf-8").write(s)
print("gcc-wrapper.py: print 语法已转 python3")
PY
fi

echo "== 校验 block/Kconfig 引用 =="
grep -n 'uxio_first' "$K/block/Kconfig" || echo "   已无 uxio_first 引用"
