#import "@preview/touying:0.6.1": *
#import "../shahe.typ": *
#import "@preview/cetz:0.3.2"
#import "@preview/fletcher:0.5.5" as fletcher: node, edge
#import "@preview/numbly:0.1.0": numbly
#import "@preview/theorion:0.3.2": *
#import cosmos.clouds: *
#show: show-theorion

// cetz and fletcher bindings for touying
#let cetz-canvas = touying-reducer.with(reduce: cetz.canvas, cover: cetz.draw.hide.with(bounds: true))
#let fletcher-diagram = touying-reducer.with(reduce: fletcher.diagram, cover: fletcher.hide)

#show: university-theme.with(
  aspect-ratio: "16-9",
  // align: horizon,
  // config-common(handout: true),
  config-common(frozen-counters: (theorem-counter,)),  // freeze theorem counter for animation
  header-right: none,  // 隐藏右上角的小标题
  config-info(
    title: [MemFabric Hybrid],
    subtitle: [DRAM&HBM hybrid pooling, memory semantic interface, high-performance cross-machine memory direct access],
    author: [Zexin Jian],
    date: datetime.today(),
    institution: [Institute of Computing Technology, Chinese Academy of Sciences],
    logo: "images/ICT-logo.png",
    email: "jianzexin25z@ict.ac.cn",
    landing: none,
    seclanding: none
  ),
)

// #set heading(numbering: numbly("{1}.", default: "1.1"))

#title-slide()

== 本章目录 <touying:hidden>

#components.adaptive-columns(outline(title: none, indent: 1em))

== 华为韬定律

#figure(image("images/T.png", width: 100%))
#figure(image("images/price.jpg", width: 30%))

= Background

== Challenges

- Challenges: 
  - 算力墙: 模型参数从百亿增至万亿级, 单颗 AI 芯片算力增长趋缓, 大规模并行效率受通信开销严重制约
  - 内存墙: 单节点 HBM 容量有限 (128GB/颗), KV Cache 等中间数据爆炸式增长, 成为模型规模扩展的硬性约束
  - 能效墙: 数据频繁搬运导致能耗激增, 传统架构下大量算力浪费在数据移动而非计算上
- 传统架构: 
  - 传统以 CPU 为中心的分层架构中, 跨节点通信依赖低速网络, 数据需在 CPU 内存与 NPU 显存间多次中转. NPU 算力利用率常因数据等待而降至 30%-50%, 大量昂贵算力被浪费在数据搬运上. 业界亟需一种能够打破单机内存边界、实现全局内存资源共享的新型架构

== 模型增长趋势

#figure(image("images/model-parameters.png", width: 100%))

== Huawei CloudMatrix384

#figure(image("images/cloudmatrix-topo.pdf", width: 90%))

- 核心规格: 
  - 384 颗昇腾 910C NPU; 192 颗鲲鹏 920 CPU; BF16 算力 300 PFLOPS; HBM 高带宽内存 48TB

#pagebreak()

- 网络平面: 
  - UB Plane - Scale-Up 纵向扩展
    - 无阻塞全对全拓扑, 每 NPU >392GB/s 单向带宽, 跨节点带宽衰减 \<3%, 延迟增加 \<1μs
  - NC Plane - Scale-Out 横向扩展
    - RoCE 技术, 每 NPU 400Gbps 单向带宽, 负责跨超节点通信，隔离控制与存储流量
  - VPC Plane - 管理控制与存储
    - 标准以太网/IP, 每节点 400Gbps, 负责部署监控、OBS/EVS/SFS 存储访问
- 核心理念: 
  - "一切可池化、一切皆对等、一切可组合". 通过 UB 网络, 384 个 NPU 和 192 个 CPU 在逻辑上构成一个紧密耦合的大规模逻辑节点

= Design

== MemFabric Architecture

#figure(image("images/memfabric.png", width: 63%))

#pagebreak()

- 设计目的与核心思想: 
  - 异构设备的统一池化: 将多节点的异构设备内存 (DRAM|HBM等)池化, 提供高性能的全局内存"直接访问"的能力
  - 简单的北向接口: 提供内存语义访问接口, 即 xcopy with global virtual address, 向传统的 memcpy 概念靠近, 支持 D2RH, RH2D, RH2H, D2D 等
  - 南向高可扩展: 通过插件的方式支持多种 DMA 引擎和 LD/ST 及多种网络/灵衢互联 (Device UB、Device RoCE、Host UB、Host RoCE 等)

== 多层设计

- Application: 
  - 提供对象级语义 (Put/Get 接口), 面向上层应用, 屏蔽底层内存管理的复杂性
- Runtime: 
  - 提供统一编址的内存语义, 全局虚拟地址空间 (GVA), 跨节点跨介质直接访问
- Hardware: 
  - 支持多种互联协议, Device UB / Device RoCE / Host UB / Host RoCE 等, 高可扩展的插件架构

== Design 1: Global Virtual Address

- 所有进程地址一致, GVA 起始地址全局统一
- 线性排布, uint64 简单地址空间
- 透明访问, 无需关注节点与介质
- 类 memcpy 接口, `xcopy(dest, src, n)`

#figure(image("images/GVA.png", width: 94%))

== Design 2: 跨机跨介质直接访问

- 基于 MemFabric 内存语义统一编址, 数据可以在跨节点的多级存储间实现透明、直接访问
- 典型跨节点跨介质的访问路径有: 
  - D2RH: 本机 HBM 到跨机 DRAM
  - RH2D: 跨机 DRAM 到本机 HBM
  - RH2H: 跨机 DRAM 到本机 DRAM

#figure(image("images/cross-node-access.png", width: 76%))

= Takeaways & Discussion

== Takeaways & Discussion

- 硬件趋势: 
  - CloudMatrix384 的重点是全互联和资源池化, 不只是堆更多 NPU
- 抽象趋势: 
  - MemFabric 用 GVA + xcopy, 把远端 HBM/DRAM 变成可被应用直接表达的内存资源
- 系统机会: 
  - KV Cache、Embedding、参数缓存等 memory-intensive workload 会最先受益
- 研究空间: 
  - placement、prefetch、consistency、runtime scheduling 仍需要 workload-aware design

#focus-slide[
  #set text(size: 48pt, fill: white, weight: "bold")
  Thank you!
  #v(-0.6em)
  #set text(size: 14pt, weight: "regular")
  #link("https://gitcode.com/Ascend/memfabric_hybrid")
  #v(-0.3em)
  #set text(size: 36pt)
  Q & A
]

#show: appendix