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

def gen_exists(inc):
    """构建时才生成的头文件（include/generated/uapi 等）也算能解析。"""
    for r in (os.path.join(K, "include", "generated", "uapi"),
              os.path.join(K, "include", "generated"),
              os.path.join(K, "arch", "arm64", "include", "generated")):
        if os.path.exists(os.path.join(r, inc)):
            return True
    return False

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
            # 还有一批"名字在 include/ 下但文件是构建时生成"的：<linux/version.h>
            # 实际来自 include/generated/uapi/linux/version.h（Kbuild 的 filechk_version.h），
            # 源码树里没有，但 include 路径里有，所以不能算缺；同理 utsrelease/compile 等。
            GEN_NAMES = ("linux/version.h", "linux/utsrelease.h", "linux/compile.h",
                         "linux/bounds.h", "asm-offsets.h", "linux/timeconst.h")
            if inc.startswith(SKIP) or inc.startswith(".") or "/" not in inc or inc in GEN_NAMES:
                out.append(ln)
                continue
            if not resolves(inc) and not gen_exists(inc) and topdir_exists(inc):
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
if os.path.isfile(os.path.join(sys.argv[1], "include/soc/oplus/system/boot_mode.h")):
    print("== 配套厂商源码已就绪，保留 OPLUS 功能宏 ==")
    raise SystemExit(0)
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

# 第四遍 a：把引用了"不存在的子目录"的 obj-* 行注释掉。
# arch/arm64/kernel/Makefile:77-79 是个假 #ifdef（Makefile 不认识 C 注释），
# 只要 CONFIG_OPLUS_SECURE_GUARD 非空就会去编 rootguard/，而公开分支没有这个目录；
# 而 OplusKernelEnvConfig.mk:146-148 会直接 export CONFIG_OPLUS_SECURE_GUARD=y，
# 所以关 .config 根本没用。
python3 - "$K" <<'PY'
import os, re, sys
K = sys.argv[1]
pat = re.compile(r'^(\s*)(obj-\S*|extra-\S*)\s*(\+=|\?=)\s*([^\s#]+/)\s*$')
n = 0
for root, dirs, files in os.walk(K):
    if '/.git' in root or '/tools/' in root:
        continue
    for fn in files:
        if fn not in ("Makefile", "Kbuild"):
            continue
        p = os.path.join(root, fn)
        try:
            lines = open(p, encoding="utf-8", errors="ignore").read().split("\n")
        except OSError:
            continue
        ch = False
        for i, ln in enumerate(lines):
            m = pat.match(ln)
            if not m:
                continue
            d = os.path.join(root, m.group(4))
            if os.path.isfile(os.path.join(d, "Makefile")) or os.path.isfile(os.path.join(d, "Kbuild")):
                continue
            lines[i] = "# NL-NODIR: " + ln
            ch = True; n += 1
        if ch:
            open(p, "w", encoding="utf-8").write("\n".join(lines))
print("== obj-* 指向缺失目录已注释 %d 处 ==" % n)
PY

# 第四遍 b：stackprotector.h:33 用 LINUX_VERSION_CODE 却没 include linux/version.h
# （4.19 原版靠 init/main.c 的隐式包含；厂商的 oplus_phoenix.h 被我们跳过后就断了）
python3 - "$K" <<'PY'
import os, sys
p = os.path.join(sys.argv[1], "arch/arm64/include/asm/stackprotector.h")
if os.path.exists(p):
    s = open(p, encoding="utf-8", errors="ignore").read()
    if "linux/version.h" not in s:
        s = s.replace("#define _ASM_STACKPROTECTOR_H",
                      "#define _ASM_STACKPROTECTOR_H\n\n#include <linux/version.h>", 1)
        open(p, "w", encoding="utf-8").write(s)
        print("== stackprotector.h 补 #include <linux/version.h> ==")
PY

# 第五遍 a：.c 文件里的 #include 也要处理。第二遍只扫了头文件，但厂商在
# kernel/irq/cpuhotplug.c:18 之类的地方直接 #include <soc/oplus/system/oplus_project.h>，
# 这些目录公开分支没有。规则与第二遍一致（含 generated 白名单，避免误伤）。
python3 - "$K" <<'PY'
import os, re, sys
K = sys.argv[1]
roots = [K, os.path.join(K, "arch/arm64")]
def resolves(inc):
    hdrs = (inc, os.path.join("uapi", inc), os.path.join("generated", inc))
    for r in roots:
        for h in hdrs:
            if os.path.exists(os.path.join(r, "include", h)):
                return True
    return False
def gen_exists(inc):
    for r in (os.path.join(K, "include", "generated", "uapi"),
              os.path.join(K, "include", "generated"),
              os.path.join(K, "arch", "arm64", "include", "generated")):
        if os.path.exists(os.path.join(r, inc)):
            return True
    return False
def topdir_exists(inc):
    return any(os.path.isdir(os.path.join(r, "include", inc.split("/")[0])) for r in roots)
SKIP = ("generated/", "config/", "asm/", "asm-generic/", "uapi/",
        "dt-bindings/", "mach/", "plat/", "xen/", "linux/", "net/", "media/", "sound/")
# linux/ 之类的根必须存在（否则把整个内核的头文件全删了）；只处理"根存在、路径不存在"的厂商路径
GEN_NAMES = ("linux/version.h", "linux/utsrelease.h", "linux/compile.h",
             "linux/bounds.h", "asm-offsets.h", "linux/timeconst.h")
n = 0; miss = set()
for base in (os.path.join(K, "kernel"), os.path.join(K, "mm"), os.path.join(K, "fs"),
             os.path.join(K, "drivers"), os.path.join(K, "arch", "arm64"),
             os.path.join(K, "block"), os.path.join(K, "security")):
    for root, dirs, files in os.walk(base):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            try:
                src = open(path, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            out, mod = [], False
            for ln in src.splitlines(True):
                m = re.match(r'\s*#\s*include\s*<([^>]+)>', ln)
                if m:
                    inc = m.group(1)
                    if (inc.startswith(SKIP) or inc in GEN_NAMES or "/" not in inc
                            or resolves(inc) or gen_exists(inc) or not topdir_exists(inc)):
                        out.append(ln); continue
                    miss.add(inc)
                    out.append("/* NL-MISSING-INCLUDE: " + ln.strip() + " */\n")
                    mod = True; n += 1
                    continue
                out.append(ln)
            if mod:
                open(path, "w", encoding="utf-8").write("".join(out))
print("== .c 里被注释的缺失 include: %d 处 ==" % n)
for x in sorted(miss):
    print("   -", x)
PY

# 第五遍 b：Makefile 里引用了不存在的 .c/.S 的 obj-* 行也注释掉。
# 例：mm/Makefile 里有 process_mm_reclaim_weak.o，但公开分支没有对应源文件，
# 会报 "No rule to make target 'mm/process_mm_reclaim_weak.c'"。
python3 - "$K" <<'PY'
import os, re, sys
K = sys.argv[1]
pat = re.compile(r'^(\s*)(obj-\S*|extra-\S*)\s*(\+=|\?=)\s*([^\s#]+\.o)\s*$')
n = 0
for root, dirs, files in os.walk(K):
    if '/.git' in root:
        continue
    for fn in files:
        if fn not in ("Makefile", "Kbuild"):
            continue
        p = os.path.join(root, fn)
        try:
            lines = open(p, encoding="utf-8", errors="ignore").read().split("\n")
        except OSError:
            continue
        rules = "\n".join(lines)
        ch = False
        for i, ln in enumerate(lines):
            m = pat.match(ln)
            if not m:
                continue
            stem = m.group(4)[:-2]
            if "$" in stem:
                continue
            if any(os.path.isfile(os.path.join(root, stem + e)) for e in (".c", ".S", ".s", ".c_shipped", ".S_shipped", ".o_shipped", ".ppm", ".pbm", ".pgm")):
                continue
            # 复合对象和显式生成目标不需要同名源文件。
            composite = r'^\s*' + re.escape(stem) + r'-(?:y|m|objs|\$\([^)]+\))\s*[:+?]?='
            generated = r'^[^#\n]*' + re.escape(m.group(4)) + r'\s*:'
            if re.search(composite, rules, re.M) or re.search(generated, rules, re.M):
                continue
            lines[i] = "# NL-NOSRC: " + ln
            ch = True; n += 1
        if ch:
            open(p, "w", encoding="utf-8").write("\n".join(lines))
print("== obj-* 指向缺失源文件已注释 %d 处 ==" % n)
PY

# 厂商功能关闭时，引用与声明使用相同的编译条件。
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
git -C "$K" apply "$HERE/source-guards.patch"

echo "== 校验 block/Kconfig 引用 =="
grep -n 'uxio_first' "$K/block/Kconfig" || echo "   已无 uxio_first 引用"
