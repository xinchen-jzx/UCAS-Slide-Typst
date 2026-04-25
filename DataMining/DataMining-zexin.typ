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
    title: [cuDNN: Efficient Primitives for Deep Learning],
    subtitle: [NVIDIA CUDA DEEP NEURAL NETWORK LIBRARY],
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

= Background

== Deep Learning

- 模型复杂度爆炸式增长
  - 从 AlexNet 的 6000 万参数到 GPT-3 的 1750 亿参数，深度学习模型规模呈指数级增长。以 ResNet-152 为例,，其参数量达 6000 万，单次前向传播需要超过 100 亿次浮点运算
- 训练时间成本高昂
  - 在 CPU 上训练一个 ResNet-50 模型需要数周甚至数月时间。以 ImageNet 数据集为例，使用传统 CPU 集群训练可能需要超过 30 天，严重影响研究迭代速度
- 内存带宽瓶颈
  - 深度学习涉及大量数据搬运，传统 CPU 的内存带宽成为性能瓶颈。卷积操作需要频繁访问内存，导致计算单元经常处于等待状态，利用率低下

#figure(image("images/Model-Compute.png", width: 100%))

== GPU Architecture

- CPU v.s. GPU
  - CPU：设计用于串行处理，拥有少量强大核心（通常 4-64 核），擅长复杂逻辑控制和分支预测，但并行计算能力有限
  - GPU：专为并行计算设计，拥有数千个简单核心（NVIDIA A100 拥有 6912 个 CUDA 核心），适合执行大量相同操作的计算任务
- CUDA

> 深度学习中的卷积、矩阵乘法等操作具有天然的并行性，完美契合 GPU 的架构特点。一个卷积层计算可以分解为数千个独立的乘加运算，在 GPU 上可同时执行

#figure(image("images/CPU-GPU.png", width: 52%))

== Why cuDNN? 

- CUDA 编程困难
  - Grid、Block、Warp、Thread、Shared Memory...
  - Simplify？ TileLang、Triton、cuTile...
- 性能优化需要专业知识
  - 需要深入理解 GPU 架构特性，如 warp 调度、内存合并访问、bank conflict 避免
- 算法选择的复杂性
  - 卷积操作有多种实现算法（直接卷积、im2col+GEMM、Winograd 等），每种算法在不同输入尺寸和硬件上性能差异巨大。手动选择最优算法需要大量实验和经验

#figure(image("images/TileLang-CUDA.png", width: 115%))

== cuDNN

- *预优化算子库*：提供经过高度优化的深度学习基础算子，包括卷积、池化、归一化、激活函数等，开发者只需调用 API 即可获得极致性能
- *自动算法选择*：内置启发式算法，根据输入尺寸、硬件特性自动选择最优实现算法，无需开发者手动调优
- *跨架构兼容*：自动适配不同代际的 NVIDIA GPU，从 Maxwell 到 Hopper 架构
- *框架集成*：被 TensorFlow、PyTorch 等主流框架深度集成

= Related Work

== Deep Learning Framework

- TensorFlow：采用数据流图计算模型，支持静态图优化
  - TensorBoard 可视化
  - TensorFlow Serving 部署
  - TPU 支持
- PyTorch：采用动态计算图。简洁的 API 设计和 Pythonic 风格
  - 动态图机制
  - TorchScript 部署
  - 强大的生态系统
- Caffe：专注于卷积神经网络和计算机视觉

> *分层设计*：所有主流深度学习框架都深度依赖 cuDNN 作为底层加速库。框架提供高层次的神经网络抽象和自动微分能力，而 cuDNN 负责将计算密集型的操作高效地映射到 GPU 硬件上

== Evolution of GPU Acceleration

#figure(image("images/GPU-History.png", width: 105%))

= cuDNN

== cuDNN

#figure(image("images/cuDNN.png", width: 50%))

== Key Abstraction: Handle

- Handle (句柄)：库的核心上下文对象，管理所有 cuDNN 操作的状态和资源。每个线程需要创建独立的句柄，确保线程安全
  - 封装了特定的 GPU 设备和 CUDA 流，确保所有操作都在正确的上下文中执行
```c
typedef struct cudnnContext *cudnnHandle_t;

// 创建 cuDNN 句柄
cudnnHandle_t handle;
cudnnCreate(&handle);
// 使用句柄进行操作...
cudnnDestroy(handle);
```

- *一个线程一个句柄*：cuDNN 句柄不是线程安全的。不能在线程 1 和线程 2 中同时使用同一个 handle 调用函数，否则会内部状态错乱崩溃
- *资源占用*：一个 cudnnHandle_t 占用的额外 CPU/GPU 资源极少

== Key Abstraction: Descriptor

- Descriptor (描述符)：使用多种描述符来封装复杂的数据和操作参数
- 张量描述符：统一描述了 3 到 8 维张量的所有属性，如维度、数据类型（FP32/FP16/INT8等）、步长和数据布局（如NCHW/NHWC），使得同一个函数可以处理各种形状的张量
```c
typedef struct cudnnTensorStruct *cudnnTensorDescriptor_t;

// 创建 4D 张量描述符
cudnnTensorDescriptor_t desc;
cudnnCreateTensorDescriptor(&desc);
cudnnSetTensor4dDescriptor(
  desc, CUDNN_TENSOR_NCHW,
  CUDNN_DATA_FLOAT,
  batch, channels, height, width);
```

#pagebreak()

- 其他描述符：类似地还有 cudnnFilterDescriptor_t（描述卷积核）、cudnnConvolutionDescriptor_t（描述卷积操作参数）、cudnnPoolingDescriptor_t（描述池化操作）等，它们共同构成了 cuDNN 高度参数化的接口

== Algorithm Selection Mechanism

- Workspace：某些算法（如 FFT、Winograd）需要额外的临时内存。cuDNN 提供 API 查询所需工作空间大小，由应用分配并传入
- 启发式算法：
  - 张量尺寸和维度、GPU 架构和显存、数据类型、卷积核大小核步长
- 穷举搜索模式：
  - cuDNN 可以运行所有可用算法并实测性能，选择最快的实现
```C
cudnnFindConvolutionForwardAlgorithm(
  handle, xDesc, wDesc, convDesc,
  yDesc, requestedAlgoCount,
  &returnedAlgoCount, &perfResults);
```

> 对于 cuDNN v8 引入的图 API (Graph API)，它提供了一种更精细的控制方式。你可以获取一个按性能排序的引擎配置列表，然后使用 cudnnFindPlan 或自定义函数，从该列表中迭代测试，以找到当前图的最优引擎配置

= Core Functions and Optimizations

== Convolution

- 直接卷积（Direct Convolution）：直接在输入特征图上滑动卷积核进行计算。适用于小卷积核 (1x1, 3x3)，无需额外内存
- img2col+gemm：将卷积展开为矩阵乘法，利用高度优化的 BLAS 库（如 cuBLAS）
- Winograd 算法：通过数学变换减少乘法次数，对小卷积核 (3x3)特别有效
- FFT 卷积：利用快速傅里叶变换将卷积转换为频域乘法，对大卷积核特别有效

== Direct Convolution

#figure(image("images/conv.png", width: 64%))

== img2col

#figure(image("images/img2col.png", width: 57%))

== Winograd

以一维卷积为例，
```py
# 输入信号
d = [d1, d2, d3, d4]^T

# 卷积信号
g = [g1, g2, g3]^T
```

#figure(image("images/conv-compute-1.png", width: 57%))

一共需要 6 次乘法和 4 次加法

== Winograd

仔细观察一下，卷积运算中输入信号转换得到的矩阵不是任意矩阵，其有规律的分布着大量的重复元素

#figure(image("images/conv-compute-2.png", width: 50%))

其中，在 CNN 的推理阶段，卷积核上的元素是固定的，所以上式中和 g 相关的式子可以提前在模型初始化阶段算好，整个推理阶段只用计算一次，因此可以忽略。所以这里一共需要 4 次乘法 和 8 次加法

#figure(image("images/conv-compute-3.png", width: 50%))

== FFT

- 当卷积核非常大时，直接卷积计算量会急剧膨胀，FFT 提供了一种从时域 $O(N^2)$ 到频域 $O(N log N)$ 的转换路径
- 卷积定理：
#figure(image("images/conv-theory.png", width: 33%))
- 解释：时域里复杂的滑窗、乘加累积，变换到频域后，直接变成了对应元素的相乘
- 计算流程：
  - 变换：分别对信号和卷积核做 FFT ($O(N log N)$)
  - 点乘：频域复数直接相乘 ($O(N)$)
  - 逆变换：对乘积结果做 IFFT 回到时域 ($O(N log N)$)


== Forward

```C
// 卷积前向传播
cudnnConvolutionForward(
  handle, &alpha,
  xDesc, x, wDesc, w,
  convDesc, algo,
  workspace, workspaceSize,
  &beta, yDesc, y);
```

== Backward

```C
// 数据梯度
cudnnConvolutionBackwardData(...)
// 权重梯度
cudnnConvolutionBackwardFilter(...)
// 偏置梯度
cudnnConvolutionBackwardBias(...)
```

== Mixing Accuracy & TensorCore

- cuDNN 混合精度 API
```C
// 设置张量数据类型为 FP16
cudnnSetTensor4dDescriptor(
  desc, format,
  CUDNN_DATA_HALF, ...);
// 启用 Tensor Core
cudnnSetConvolutionMathType(
  convDesc, CUDNN_TENSOR_OP_MATH);
```

== GPU Memory

- Workspace
```C
// 查询 workspace 大小
cudnnGetConvolutionForwardWorkspaceSize(
  handle, xDesc, wDesc, convDesc,
  yDesc, algo, &workspaceSize);
// 分配 workspace 内存
cudaMalloc(&workspace, workspaceSize);
```

- 多 GPU 支持
  - cuDNN 本身不直接管理多 GPU，但与 NCCL（NVIDIA Collective Communications Library）配合实现高效分布式训练

= Performance

== Performance

- on an NVIDIA Tesla K40 of three convolution implementations: cuDNN, Caffe, and cuda-convnet2
#figure(image("images/performance-1.png", width: 57%))

== Performance

- the cuDNN's performance portability across GPU architectures
  - The Tesla K40 is built using the Kepler architecture, and has a peak single-precision throughput of 4.29 TFlops
  - The Geforce GTX 980 is built using the newer Maxwell architecture, and has a peak single-precision throughput of 4.95 TFlops
#figure(image("images/performance-2.png", width: 89%))

== Performance

- the performance improvements gained from integrating cuDNN into Caffe
#figure(image("images/performance-3.png", width: 100%))

#focus-slide[
  #set text(size: 48pt, fill: white, weight: "bold")
  Thank you!
  #v(1em)
  #set text(size: 36pt)
  Q & A
]

#show: appendix