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
        # 注意：内核 Kconfig 的 source 既可能带引号也可能不带（本树 block/Kconfig:248/251 就没引号）
        # 只认行首（无缩进）的 source 指令：帮助文本里以 "\tsource to the ..." 开头的行会被误伤
        m = re.match(r'source\s+(?:"([^"]+)"|(\S+))', ln)
        if m:
            tgt = m.group(1) or m.group(2)
            # 路径里含 $(...) / ${...} 变量的一律跳过：arch/$(SRCARCH)/Kconfig 这种一旦被注释，conf 就读不到任何架构符号，
            # .config 会被 olddefconfig 洗成空壳（表现为 CONFIG_64BIT/ARM64 全丢、atomic64_t 未定义）
            if "$" not in tgt:
                cands = [
                    os.path.normpath(os.path.join(os.path.dirname(path), tgt)),
                    os.path.normpath(os.path.join(K, tgt)),
                ]
                if not any(os.path.exists(c) for c in cands):
                    missing.append(tgt)
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

# 第二遍：公开分支省略了厂商目录，头文件里却仍 #include 它们。
# 例：include/linux/mutex.h:95  #include <linux/sched_assist/sched_assist_mutex.h>
#    （整个 kernel/sched_assist/ 与 include/linux/sched_assist/ 都没给）
# 处理：只注释掉"根目录存在、但子路径不存在"的 #include，改成 // NL-MISSING-INCLUDE，
#      不动 generated/ 这种会现场生成的，也不动本来就能解析到的。
python3 - "$K" <<'PY'
import os, re, sys, glob

K = sys.argv[1]
ROOTS = [
    "include", "include/uapi", "include/generated", "include/generated/uapi",
    "arch/arm64/include", "arch/arm64/include/uapi", "arch/arm64/include/generated",
]
roots = [os.path.join(K, r) for r in ROOTS if os.path.isdir(os.path.join(K, r))]

def resolves(inc):
    return any(os.path.exists(os.path.join(r, inc)) for r in roots)

def topdir_exists(inc):
    top = inc.split("/")[0]
    return any(os.path.isdir(os.path.join(r, top)) for r in roots)

patched, missing = [], []

for path in glob.glob(os.path.join(K, "include", "**", "*.h"), recursive=True) + \
            glob.glob(os.path.join(K, "arch", "arm64", "include", "**", "*.h"), recursive=True):
    try:
        src = open(path, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    out, mod = [], False
    for ln in src.splitlines(True):
        m = re.match(r'\s*#\s*include\s*<([^>]+)>', ln)
        if m:
            inc = m.group(1)
            # 这些前缀要么是构建时现场生成（generated/、config/），要么走 generic-y 兜底：
            # arm64 的 <asm/types.h> 并不存在于源码树，是 arch/arm64/include/asm/Kbuild 里
            # generic-y 条目在构建时生成到 arch/arm64/include/generated/asm/ 的。
            # 上一轮没排除 asm/，把 <asm/types.h> 注释掉，导致 __u32 全部未定义。
            SKIP = ("generated/", "config/", "asm/", "asm-generic/", "uapi/",
                    "dt-bindings/", "mach/", "plat/", "xen/")
            if inc.startswith(SKIP) or inc.startswith(".") or "/" not in inc:
                out.append(ln)
                continue
            if not resolves(inc) and topdir_exists(inc):
                missing.append(inc)
                out.append("/* NL-MISSING-INCLUDE: " + ln.strip() + " */\n")
                mod = True
                continue
        out.append(ln)
    if mod:
        open(path, "w", encoding="utf-8").write("".join(out))
        patched.append(os.path.relpath(path, K))

print("== 被注释掉的缺失头文件 (%d 处) ==" % len(missing))
for m in sorted(set(missing)):
    print("   -", m)
print("== 被修改的头文件 (%d 个) ==" % len(patched))
for p in patched[:40]:
    print("   *", p)
PY

# 第三遍：OplusKernelEnvConfig.mk 会把一份硬编码的 ALLOWED_MCROS 列表无条件 -D 成宏，
# 跟 CONFIG 一点关系都没有（这就是为什么关了 CONFIG 也没用）：
#   $(foreach myfeature,$(ALLOWED_MCROS), $(eval KBUILD_CFLAGS += -D$(myfeature)))
# 这些宏一旦定义，init/main.c:105 就会去 include 公开分支里根本不存在的
# drivers/soc/oplus/system/oplus_phoenix/oplus_phoenix.h。把 foreach 的列表换成空变量，
# 所有 OPLUS_FEATURE_* 分支统一切到"关"，剩下的就是干净的 AOSP/qcom 代码。
python3 - "$K" <<'PY'
import os, sys
p = os.path.join(sys.argv[1], "OplusKernelEnvConfig.mk")
if not os.path.exists(p):
    print("!! 找不到 OplusKernelEnvConfig.mk"); raise SystemExit(0)
s = open(p, encoding="utf-8", errors="ignore").read()
before = s
s = s.replace("$(foreach myfeature,$(ALLOWED_MCROS),",
              "$(foreach myfeature,$(NL_NO_FEATURE_MACROS),")
s = s.replace("$(foreach myfeature, $(ALLOWED_MCROS),",
              "$(foreach myfeature, $(NL_NO_FEATURE_MACROS),")
if s != before:
    open(p, "w", encoding="utf-8").write(s)
    print("== OplusKernelEnvConfig.mk: ALLOWED_MCROS 宏注入已停用 ==")
else:
    print("!! 没找到 ALLOWED_MCROS 的 foreach，需人工确认")
PY

echo "== 校验 block/Kconfig 引用 =="
grep -n 'uxio_first' "$K/block/Kconfig" || echo "   已无 uxio_first 引用"
