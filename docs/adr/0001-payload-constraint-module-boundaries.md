# 模块边界由载荷约束决定

bashlet 的 `tools/build` 会把每个 import 到的模块**内联进最终脚本**，因此框架代码就是每个产物的载荷（字节数）。这使模块边界不只是可读性问题，而是运行时代价问题：一个罕见的重能力（SSE、写盘）若留在常用模块里，会给所有消费者增重。

因此模块按「语意性 × 反冗余」权衡切分：先保证模块作为概念完整可理解，只有当某部分是罕见重能力、且能从常见 import 组合中摘出去省下可观字节时才独立成模块。

已据此把 `ext/requests.sse` 从 `ext/requests` 摘出，把 `core/config.persist`（update/save/_yq_try）从 `core/config` 摘出，把终端渲染分为基座 `std/console`（原语 + `console.list`）与 `std/console.layout`（section/item/footer，仅 binup 需要）。

## 关键约束：`core/args → core/usage` 是全员热路径

每个脚本都 import `core/args`，而 args import `core/usage`，所以 **usage 依赖什么，所有脚本就会背什么**。据此把通用对齐列表 `console.list` 放在基座 `std/console` 而非 `console.layout`：usage 需要它，但不该因此把 section/item/footer 一并拖给所有脚本。

替代方案是「一模块一概念」地无限细分，但会让模块数膨胀、import 样板变多，且大量模块小到不值得独立；另一个极端是保持大模块，牺牲所有消费者的载荷。两者都被否决。
