# Kokoro-82M v1.1 multi-lang 神经语音接入 — 研发计划与验收标准

> 目标：用 sherpa-onnx（v1.13.3 预编译 iOS xcframework）运行 **Kokoro-82M v1.1 multi-lang（int8）**，
> 替换生硬的系统朗读。中英双语一个模型；模型（~170MB 级）**不打入安装包**，App 内异步下载，
> 支持镜像前缀（国内用户）。Provider 架构、模型状态机、设置 UI 已就绪（见 `Modules/Audio/`）。
> 技术方案全文：`~/.claude/plans/immutable-singing-pillow.md`。

## 里程碑总览

| 里程碑 | 内容 | 预估 |
|---|---|---|
| M0 | 去风险探针：产物布局 / 模拟器 slice / 三端链接冒烟 | 0.5 天 |
| M1 | Vendor 脚本 + Tuist 接线（xcframework、modulemap、SWCompression） | 0.5 天 |
| M2 | 真引擎：KokoroSynthesizer(actor) + SherpaOnnxEngine(播放/流水线) | 1–1.5 天 |
| M3 | 真下载 + 流式解压 + 原子安装 + 镜像 | 1 天 |
| M4 | 接线收尾：默认引擎切换、Settings 文案、临时测试清理 | 0.5 天 |
| M5 | 真机验收（iPhone 12 Pro / A14）+ CI/TestFlight | 1 天 |

---

## M0 — 去风险探针

**做什么**：手动下载 `sherpa-onnx-v1.13.3-ios.tar.bz2`，确认解包布局与 `c-api.h` 位置；查 xcframework 是否含
`ios-arm64_x86_64-simulator` slice；写一个调用 C 符号的冒烟文件，device / simulator / My Mac 三个 destination 各 build 一次。

**验收标准**
- [ ] 产物布局书面确认（写进 fetch 脚本注释），`c-api.h` 来源确定
- [ ] 模拟器 slice 结论明确（决定 Placeholder 的去留范围）
- [ ] 三端链接冒烟全绿（`xcodebuild build` × 3）

## M1 — Vendor + Tuist 接线

**做什么**：`scripts/fetch-sherpa-onnx.sh`（pin 版本 + SHA256 校验 + `SHERPA_ONNX_MIRROR` 支持 + 幂等戳）；
`Modules/Audio/SherpaOnnxC/`、`CBzip2/` modulemap shim；`Project+Module.swift` 加 `targetSettings`；
Audio 挂两个 xcframework（`.when([.ios])`）+ `-lc++` + 搜索路径；`Tuist/Package.swift` 加 SWCompression；
bootstrap.sh / Fastfile 挂钩；.gitignore 与 lint 排除。

**验收标准**
- [ ] 全新 clone 跑 `bootstrap.sh` 一次成功（fetch → tuist install → generate）
- [ ] fetch 脚本重复执行秒退（幂等）；SHA256 不匹配时报错退出
- [ ] `import SherpaOnnxC` 在 Audio 内编译通过；App / 全模块 build 绿；macOS destination build 绿
- [ ] 现有单测全部仍绿（其他模块零影响）

## M2 — 真引擎

**做什么**：`KokoroSynthesizer`（actor 持有 OfflineTts 指针，懒加载 + warmUp，`generate → [Float]@24kHz`）；
`KokoroModelLayout`（目录→配置路径+必需文件清单，纯函数）；`SherpaOnnxEngine: NeuralTTSEngine`
（AVAudioEngine+PlayerNode 播放、最多预生成 2 段的 lookahead、epoch 防 stop 误报、rateScale→speed、
`KokoroVoice.zh/.en` 按内容语言选 sid、synthesizer 按 modelDir 静态缓存）。

**验收标准**
- [ ] 严格并发（`SWIFT_STRICT_CONCURRENCY=complete`）零警告零报错
- [ ] `KokoroModelLayout` 单测：路径拼装、lexicon 串、必需清单
- [ ] 模拟器装真模型后：中文/英文各能合成出声（人工听）；播放中生成不断流
- [ ] pause → resume 精确续播；播放中 stop 后 `progress` 归零且**不再**收到多余段完成回调
- [ ] 语速 0.5–1.5 生效（Kokoro speed 直通）

## M3 — 真下载 + 解压安装

**做什么**：`URLSessionModelDownloader`（流式写盘、可取消、进度分段映射 0.85/0.93/0.99/1.0）；
镜像：UserDefaults `ttsModelMirrorPrefix` 前缀拼接；`ModelArchiveExtractor`
（CBzip2 流式解 bz2 → SWCompression `TarReader(fileHandle:)` 逐 entry 解 tar → staging 校验 → 原子 move →
`isExcludedFromBackup`）；`TTSModelDescriptor` 切 int8（真实 URL/sizeMB 用 `curl -sIL` 确认）；
默认下载器切真实现（launch arg `simulated-tts-download` 保留模拟）。

**验收标准**
- [ ] 单测：fixture tar.bz2（几 KB，内嵌）全流程通过；损坏包 / 缺文件包 → `.failed` 且磁盘无残留 staging
- [ ] 单测：`file://` fixture 走 downloader，进度单调递增至 1.0，最终目录布局符合清单
- [ ] 单测：镜像前缀拼接正确；未设前缀时用原 URL
- [ ] 模拟器真下载一次成功（GitHub 直连），解压期间内存峰值 **< 250MB**（Xcode gauge）
- [ ] 下载中删除/取消 → 状态回 `.notInstalled`，不出现 `.failed` 误报，可立即重下

## M4 — 接线收尾

**验收标准**
- [ ] iOS 默认神经引擎 = `SherpaOnnxEngine`；macOS 保持 Placeholder（`#if os(iOS)` 隔离）
- [ ] 模型未装选神经 → 自动回退系统声（现有门控不变）；装好后**下一次播放**即切换生效
- [ ] Settings「占位试听」caption 删除；模型状态行常驻（未装/进度/就绪/失败四态）
- [ ] ScreenshotTests 临时用例删除；全部 UITest 绿

## M5 — 真机验收（iPhone 12 Pro / A14）＋发布链路

**性能红线（不达标即不出 M5）**
| 指标 | 标准 |
|---|---|
| 首音延迟（冷：含模型加载） | ≤ 5s（超标则把 warmUp 提前到安装完成/进阅读页时机） |
| 首音延迟（热） | ≤ 2.5s |
| 连续播放 | 不断流、不卡顿（生成快于播放，RTF < 1） |
| 解压安装内存峰值 | < 250MB，无 jetsam |
| 播放期稳态内存增量 | < 300MB |
| App 安装包增量 | ≤ 60MB（PR 注明实测值） |

**功能验收清单**
- [ ] 真机 Settings 下载真模型（Wi-Fi），双阶段进度顺畅；镜像前缀路径各验一次
- [ ] 中文一章 + 英文一章完整听感验收：无杂音/破音，发音无大面积错误，音色 sid 定稿（试听调整）
- [ ] 暂停/恢复/中途停止/语速 0.7 与 1.3/切换 provider/删除模型回退/重下载 全部正常
- [ ] 断网中断下载 → `.failed` 可重试；恢复网络重试成功
- [ ] 锁屏/后台播放行为与系统声音一致（AVAudioSession 已配 .playback）
- [ ] 模拟器 + My Mac 各 build 绿；CI 全绿；beta lane 出 TestFlight 包成功（vendored xcframework 过签名）

**发布前口径**
- 模型下载走用户流量 ~170MB：确认文案里已提示大小（现有 Settings 行已含）
- 已知非目标（v1 不做）：下载断点续传、后台下载、多音色切换 UI、镜像地址用户可见配置项

---

## 风险登记（按优先级）

1. **tarball 布局假设**（M0 先验，隔离在 fetch 脚本 normalize 里）
2. **modulemap 进 framework 的编译细节**（M0 冒烟兜底：手写 `.target` 回退方案）
3. **解压内存**（流式方案；兜底：~80 行手写流式 untar）
4. **中文合成 dict/lexicon 配错 → 静默垃圾音**（清单校验 + M5 真机试听把关）
5. **A14 实时率不达标**（兜底：降 num_threads 调优 → 换 MeloTTS zh_en descriptor，架构无需改动）
