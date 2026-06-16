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
    title: [Huawei CloudMatrix384 SuperNode],
    subtitle: [A3: 384-Node Supercomputing System],
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

== Table of contents <touying:hidden>

#components.adaptive-columns(outline(title: none, indent: 1em))

== Huawei Tau (τ) Scaling Law

#figure(image("images/price.jpg", width: 21%))

= Introduction

== Model Parameter

#figure(image("images/model-parameters-english.png", width: 100%))

== Overview

#figure(image("images/Huawei-A3.png", width: 38%))

#pagebreak()

> Key Idea: AI speed is not only about a powerful chip. It is also about how well many chips cooperate.

For Example: 
- One student = slow for a giant task
- 384 AI workers + fast chatting = one super team
- CloudMatrix384 is the machine version of this teamwork

> Research Question: *How to scale the AI performance by cooperation Hardware and Software?*

== Introduction

#figure(image("images/A3-Architecture.png", width: 84%))

== Huawei CloudMatrix384

#figure(image("images/cloudmatrix-topo.pdf", width: 100%))

= Design

== Overview

#figure(image("images/memfabric.png", width: 63%))

= Experiment

== Experiment

#figure(image("images/result-1.png", width: 90%))

#pagebreak()

#figure(image("images/result-2.png", width: 100%))

= Takeaways & Discussion

== Conclusion

- Collectively, our findings validate Huawei CloudMatrix as a highly effective, scalable, and performance-optimized platform for deploying large-scale AI workloads, setting a benchmark for future AI datacenter infrastructures.

== Takeaways & Discussion

- Why should non-CS students care?
  - New Competition
    - Countries and companies compete not only on chips, but also on system design and networking
  - Real Tradeoffs
    - More power also means more energy, cooling, cost, and engineering complexity

#pagebreak()

- For CS students, 
  - Hardware Trends:
    - CloudMatrix384 focuses on full interconnectivity and resource pooling, not just adding more NPUs.
  - Abstraction Trends:
    - MemFabric uses GVA + xcopy to transform remote HBM/DRAM into memory resources that can be directly expressed by applications.
  - System Opportunities:
    - Memory-intensive workloads such as KV Cache, Embedding, and parameter caching will benefit first.
  - Research Space:
    - Placement, prefetching, consistency, and runtime scheduling still require workload-aware design.


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