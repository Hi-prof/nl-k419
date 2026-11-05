#!/usr/bin/env bash
# 把 nl_compat.c 挂进内核树。用法：./compat/apply_compat.sh ksrc
set -euo pipefail

K="${1:?用法: apply_compat.sh <内核树目录>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$K/mm" ] || { echo "::error::$K 不像内核树（缺 mm/）"; exit 1; }
[ -f "$K/Makefile" ] || { echo "::error::$K 缺 Makefile"; exit 1; }

cp "$HERE/nl_compat.c" "$K/mm/nl_compat.c"

if ! grep -q 'nl_compat\.o' "$K/mm/Makefile"; then
    printf '\nobj-y += nl_compat.o\n' >> "$K/mm/Makefile"
fi

echo "== mm/Makefile 末尾 =="
tail -5 "$K/mm/Makefile"

echo "== 头文件里的声明是否与补丁一致 =="
grep -n 'kmalloc_debug' "$K/include/linux/slab.h" || {
    echo "::error::include/linux/slab.h 里没有 kmalloc_debug_* 声明，分支选错了？"
    exit 1
}
