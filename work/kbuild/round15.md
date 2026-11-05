# ROUND 15

- run：42058202725（提交 df8e3c1ad764dcff045a918ec3e509ba3e61a79b）
- 结果：失败；步骤：拉取内核源码。未进入 Image 编译。

错误原文：

```text
error: patch failed: vendor/oplus/kernel/secureguard/rootguard/oplus_guard_general.c:83
error: vendor/oplus/kernel/secureguard/rootguard/oplus_guard_general.c: patch does not apply
```

归类：补丁应用时的换行格式不一致。上游该文件有 94 行 CRLF；本地默认 core.autocrlf=true 能应用，Linux 默认 false 时失败，已在本地分别复现。

改动：仅在 git apply 命令上指定 -c core.autocrlf=true，使 Git 匹配该厂商文件的 CRLF；不修改持久化 Git 配置。补丁仍只改变 boot_state_exit 的空参数声明。

验证：在临时目录使用对应上游文件实际应用补丁，检查声明替换成功且 CRLF 保持。

下一轮：ROUND 16，确认源码补丁应用并继续编译。
