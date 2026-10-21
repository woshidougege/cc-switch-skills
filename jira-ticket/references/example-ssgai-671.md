# 参考单：SSGAI-671

一张真实存在的单（2026-10-14 创建），可以照着它的信息密度来写。

| 项 | 值 |
|---|---|
| 单号 | `SSGAI-671` |
| 项目 | SSGAI（SSG Sales Ops BAU） |
| 类型 | Bug |
| 标题 | ARS 发布报错，新增 ARS 维护信息 |
| 报告人 | xuxl7 |
| 经办人 | zhangqp5 |
| 优先级 | Highest |
| 标签 | `Bookings_Raw`、`DataMind_AI` |
| 组件 | SSG portal |
| Test Phase | `Pre-Production Test` |
| Creation Source | `AI Generated(Datamind)` |
| Reject Reason | `Question` |
| 链接 | https://jira.xpaas.lenovo.com/browse/SSGAI-671 |

## 它的正文（原文）

```
【用户原文】
ARS 还没维护进去，你帮我加一下呀，谢谢！
我在新的平台里发布ARS的时候报错了，@Yu Yu3 Long帮忙看下啊，谢谢

【期望解决方式】
请协助在新的平台中补充/维护 ARS 相关信息，并排查发布 ARS 时的报错原因。

【推断原因】
推测是 ARS 尚未完成维护，导致在新平台发布 ARS 时校验失败或配置缺失，从而触发报错。

【补充信息】
Test Phase = Pre-Production Test
tag = Bookings_Raw
```

## 从这张单能学到的

1. **标题是「现象 + 要做什么」**：`ARS 发布报错，新增 ARS 维护信息`，一眼能看懂，不带类名和接口路径。
2. **正文分节**，而不是一大段：用户原文 / 期望解决方式 / 推断原因 / 补充信息。
3. **推断原因要标成"推测"**，不要写成像已经证实过一样。
4. **带上环境和标签**（Test Phase、tag），方便后面检索。
5. 它把用户原话整段保留了下来 —— 这在排查时很有用。

## 我们提单时可用的模板

```
【问题现象】
<一句话说清在哪个页面/流程、出现什么现象>

【复现步骤】
1. ...
2. ...
3. ...

【期望结果】
<应该是什么样>

【实际结果】
<实际是什么样，含页面原文报错>

【影响范围】
环境：TST / 生产
影响：<哪些流程不可用、影响多少人>

【补充信息】
<截图、相关单号、临时规避办法>
```