# PerturbScope-GPT 项目设计与演进方案（2026-03 审计版）

## 1. 文档角色

本文件不再只是“待实现功能列表”，而是当前仓库的设计基线与演进约束。

与其他文档的分工如下：

- `README.md`：面向使用者和面试演示的运行说明、结果展示、命令入口。
- `docs/architecture.md`：面向实现者的模块结构、数据流与 artifact 合同。
- `PROJECT_PLAN.md`：面向项目 owner 的范围边界、阶段状态、设计决策、后续演进优先级。

如果实现超出本文件定义的 MVP 边界，应先更新本文件，再扩展代码与 README。

## 2. 审计结论

基于当前仓库、配置、脚本、测试与本地 artifact 的审计，结论如下：

1. 项目已经完成“本地可运行 MVP”的核心闭环，不再处于早期脚手架阶段。
2. `Norman2019 -> preprocess -> bundle -> train -> evaluate -> rank -> Streamlit demo` 主链路已经打通。
3. 仓库已经演进出一层明确的“求职展示 / demo 交付层”，包括：
   - `doctor` 项目健康检查
   - `snapshot` 项目快照导出
   - `showcase` 现场演示准备
   - `pitch` 面试话术生成
   - 多 seed 汇总
   - 误差分析与失败样本摘要
4. 原方案文档已出现明显漂移，主要体现在：
   - 仍以“Phase 0-4 待实施”表述当前系统
   - 仍把 `requirements.txt` 视为关键交付物，而当前环境事实已经切换到 `uv + pyproject.toml + uv.lock`
   - 未明确真实数据路径与 synthetic fallback 的双模式运行约束
   - 未定义当前实际存在的 artifact 合同与演示链路

因此，本次演进目标不是扩 scope，而是把设计文档升级为与当前仓库状态一致的“交付设计文档”。

## 3. 当前阶段与目标交付

### 当前阶段

当前项目处于：

`Phase 5：稳定性、诊断能力与演示交付打磨`

这意味着：

- 核心建模闭环已完成
- 真实 Norman2019 结果已生成
- synthetic 离线演示链路已具备
- 当前重点从“补功能”转为“稳交付、控漂移、讲清楚”

### 当前目标交付

当前版本的目标不是扩展到多数据集平台，而是保持以下能力稳定、可复现、可展示：

1. 在单机上复现实验环境与基础测试。
2. 基于 `scPerturb / Norman2019` 单基因扰动子集产出标准 bundle。
3. 训练并比较 Transformer、MLP、XGBoost。
4. 输出 seen / unseen 两套评估、DEG overlap 与 target ranking。
5. 在 Streamlit 中展示推理结果与误差分析。
6. 通过 `doctor / snapshot / showcase / pitch` 完成求职场景下的演示闭环。

## 4. 稳定范围与明确非目标

### 4.1 MVP 稳定范围

本项目稳定锁定以下范围：

- 数据集：`scPerturb / Norman2019`
- 细胞上下文：`K562`
- 样本范围：单基因扰动
- 对照策略：control mean
- 目标：`delta expression`
- 主模型：Transformer Encoder
- baseline：MLP、XGBoost
- 主报告粒度：`per-perturbation`
- 必要指标：Pearson、MSE、Top-k DEG overlap
- 演示方式：本地 Streamlit app

### 4.2 明确不在当前范围内

除非先更新本文件，否则不引入以下扩展：

- 多数据集联合训练
- 多基因组合扰动建模
- 分布式训练
- foundation model 级别预训练
- 复杂工作流编排平台
- 云端服务、数据库或在线 API
- 把项目演进成通用 perturbation 平台

## 5. 当前参考结果（本地 artifact 基线）

以下结果来自当前仓库本地 artifact，作为当前设计基线的参考，不应与 synthetic 演示结果混用。

| Model | Unseen Pearson | Unseen MSE | Top-100 DEG Overlap | Reference Artifact |
| --- | ---: | ---: | ---: | --- |
| Transformer | 0.8243 | 0.00105 | 0.9755 | `artifacts/transformer_seen_norman2019_demo/run_summary.json` |
| MLP | 0.8374 | 0.00085 | — | `artifacts/mlp_seen_norman2019_demo/run_summary.json` |
| XGBoost | 0.8405 | 0.00084 | — | `artifacts/xgboost_seen_norman2019_demo/xgboost_run_summary.json` |

Transformer 多 seed 汇总基线：

- seeds：`7, 21, 42`
- unseen Pearson：`0.8304 +/- 0.0067`
- unseen top-100 DEG overlap：`0.9850 +/- 0.0067`
- reference：`artifacts/multi_seed_report.json`

误差分析基线：

- unseen split 当前主导 failure mode：`low_signal_condition`
- worst Pearson perturbation：`MAP2K6`
- worst MSE perturbation：`FOXO4`
- reference：`artifacts/transformer_seen_norman2019_demo/unseen_test_error_summary.json`

Provenance guardrail：

- 只有明确标注为 `real Norman2019` 的结果可作为生物学结果陈述。
- synthetic artifact 仅用于离线演示、UI 验证和无网络场景下的产品展示。

## 6. 运行模式设计

### 6.1 Real Norman2019 模式

这是主路径，也是可报告真实结果的路径。

主流程：

```text
download raw h5ad
  -> inspect schema
  -> preprocess to processed bundle
  -> train transformer / baselines
  -> evaluate seen + unseen
  -> generate DEG artifact and figures
  -> launch Streamlit using real artifacts
```

默认关键路径：

- raw file：`data/raw/NormanWeissman2019_filtered.h5ad`
- bundle：`data/processed/norman2019_demo_bundle`
- transformer artifacts：`artifacts/transformer_seen_norman2019_demo`

### 6.2 Synthetic Offline Showcase 模式

这是在原始数据不可用、网络不可用或只需要离线演示工程链路时的 fallback。

主流程：

```text
generate synthetic bundle
  -> train transformer / baselines on synthetic data
  -> export figures and demo artifacts
  -> launch Streamlit using synthetic artifacts
```

默认关键路径：

- bundle：`data/processed/synthetic_demo_bundle`
- transformer artifacts：`artifacts/transformer_seen_synthetic_demo`

### 6.3 App 默认选择逻辑

Streamlit 默认行为保持如下：

1. 优先加载 real Norman2019 bundle / artifact。
2. 若 real artifact 不存在，则自动退化到 synthetic bundle / artifact。
3. UI 必须明确显示当前加载的是 `real` 还是 `synthetic`，避免结果混用。

## 7. 架构与模块边界

### 7.1 模块职责

```text
src/data
  io.py              AnnData / JSON 读写
  schema.py          Norman2019 schema 自动解析与 canonicalization
  preprocess.py      QC / normalize / log1p / HVG / local-first subsampling
  pairing.py         control-mean pairing、bundle 构建与 split 导出
  torch_dataset.py   PyTorch dataset
  synthetic.py       synthetic demo 数据生成

src/models
  transformer.py     主模型
  mlp.py             baseline
  xgboost_baseline.py baseline

src/training
  losses.py
  trainer.py

src/evaluation
  metrics.py         Pearson / MSE / top-k overlap
  deg.py             DEG artifact 生成与读取
  inference.py       saved model 推理与 app 数据拼装
  error_analysis.py  per-perturbation 误差表与 failure summary

src/ranking
  target_ranking.py  目标排序

src/utils
  config.py
  logger.py
  seed.py
  comparison.py
  experiment.py
  multiseed.py
  project_health.py
  project_snapshot.py
  showcase.py
  interview_script.py

scripts
  thin CLI wrappers only

app
  streamlit_app.py   UI only, no training logic
```

### 7.2 边界约束

- UI 不包含训练逻辑。
- `scripts/` 只编排 `src/`，不复制业务逻辑。
- 模型层不直接读 raw 文件。
- ranking 不使用 attention 作为正式评分项。
- 误差分析是诊断工具，不作为新的科学主结论来源。
- 文档中所有默认路径和行为必须可由 config 或 artifact 解析得到。

## 8. 数据设计与 artifact 合同

### 8.1 原始数据与 schema 约束

原始输入固定为 `.h5ad`：

- 默认文件：`data/raw/NormanWeissman2019_filtered.h5ad`
- 默认数据源：`scPerturb benchmark`

schema 自动解析遵循 `configs/data.yaml` 中的 preset 与候选列规则，重点包括：

- perturbation 列自动识别
- control label canonicalization
- batch 列自动识别
- context 列自动识别
- 多基因扰动字符串归一化后过滤

### 8.2 预处理默认配置

当前设计基线与配置保持一致：

- `min_genes_per_cell = 200`
- `min_cells_per_gene = 3`
- `normalize_total_target_sum = 10000`
- `log1p = true`
- `hvg_top_genes = 512`
- `hvg_upper_bound = 800`
- `max_cells_per_perturbation = 500`
- `sparse_to_dense_after_hvg = true`

内存 guardrail 仍然维持：

- 推荐 HVG 区间：`512-800`
- 未做内存估算前不超过 `1000`
- 资源不足时优先下调 `HVG -> batch size -> model depth`

### 8.3 配对与目标定义

当前 MVP 的训练目标固定为：

```text
delta_expression = perturbed_expression - matched_control_mean
```

control mean 的选择顺序：

1. batch-aware control mean
2. global control mean within cell context

这一定义同时约束：

- 训练目标
- 推理输出含义
- DEG overlap 的比较对象
- target ranking 的数值基础

### 8.4 Processed Bundle 合同

标准 processed bundle 目录至少包含：

- `arrays.npz`
  - `control_expression`
  - `target_delta`
  - `perturbation_index`
  - `sample_ids`
- `splits.npz`
  - `seen_train`
  - `seen_val`
  - `seen_test`
  - `unseen_train`
  - `unseen_val`
  - `unseen_test`
- `metadata.json`
  - `gene_names`
  - `perturbation_names`

这个合同由 `src/data/pairing.py` 与 `src/data/torch_dataset.py` 共同约束，后续如需扩字段，必须保持向后兼容或同步更新加载逻辑。

### 8.5 训练与评估 artifact 合同

以 Transformer 为例，标准 artifact 目录应包含：

- `best_model.pt`
- `history.json`
- `seen_test_metrics.json`
- `unseen_test_metrics.json`
- `seen_test_per_perturbation.csv`
- `unseen_test_per_perturbation.csv`
- `seen_test_error_summary.json`
- `unseen_test_error_summary.json`
- `run_summary.json`

如生成 DEG 相关结果，还应包含：

- `deg_artifact.csv`
- `deg_artifact_metadata.json`

跨 run 汇总 artifact：

- `artifacts/multi_seed_report.json`
- `artifacts/project_snapshot.json`

### 8.6 文档与图像 artifact 合同

当前 docs 目录内的演示资产已经成为交付物的一部分，应继续维护：

- `docs/architecture.md`
- `docs/datasets/norman2019.md`
- `docs/assets/model_comparison_seen_norman2019_demo.png`
- `docs/assets/transformer_inference_preview.png`
- `docs/assets/transformer_error_analysis_preview.png`
- `docs/assets/model_comparison_seen_synthetic_demo.png`
- `docs/assets/transformer_inference_preview_synthetic_demo.png`

这些资产的作用是：

- 支持 README 展示
- 支持 `snapshot / showcase / pitch`
- 支持面试时快速打开静态图示

## 9. 建模、评估与诊断设计

### 9.1 Transformer 设计决策

保持以下设计不变：

- gene 视为 token
- control expression 通过 scalar projection 注入
- perturbation embedding 以 additive 方式广播到所有 gene token
- 默认不使用 positional encoding
- 输出目标为 `delta expression`

默认超参数：

- `d_model = 128`
- `n_heads = 4`
- `n_layers = 2`
- `ffn_dim = 256`
- `dropout = 0.1`

### 9.2 Baseline 设计

- MLP：低复杂度深度学习 baseline
- XGBoost：传统机器学习 baseline

baseline 的目标是建立可比对照，不是抢占项目范围。

### 9.3 评估规则

必须继续明确区分：

- `seen split`
- `unseen split`

主指标粒度：

- `per-perturbation`

必要指标：

- Pearson correlation
- MSE
- Top-k DEG overlap

默认 top-k：

- `20`
- `50`
- `100`

### 9.4 DEG 定义

MVP 默认 DEG 逻辑固定为：

- `scanpy.tl.rank_genes_groups`
- `method = wilcoxon`
- `adjusted p-value < 0.05`
- `abs(logfoldchange) > 0.25`

若改变阈值或方法，必须同步更新：

- `configs/train.yaml`
- `README.md`
- 本文档

### 9.5 Ranking 公式

正式 ranking 仍固定为：

```text
importance_score =
  0.5 * normalized_abs_predicted_delta
+ 0.5 * normalized_deg_significance
```

其中：

```text
deg_significance = -log10(adjusted_p_value + 1e-12)
```

约束：

- 不使用 attention score
- 权重变更必须配置化
- 文档必须说明每个分量的含义

### 9.6 误差分析设计

误差分析已成为当前版本的重要诊断层，但其角色必须继续限定：

- 目标：帮助理解失败模式与准备 demo 讲解
- 形式：per-perturbation error table + summary JSON
- failure mode：启发式标签，不是统计学新发现

当前 failure mode 启发式包括：

- `low_sample_support`
- `low_signal_condition`
- `directional_mismatch`
- `underestimates_response_magnitude`
- `overestimates_response_magnitude`
- `high_residual_condition`
- `mostly_aligned`

## 10. Demo 与交付层设计

### 10.1 Streamlit App

App 当前是正式交付面，不只是调试 UI。必须保持以下行为：

- 加载已保存 checkpoint，不在启动时训练
- 允许用户选择 perturbation
- 展示 predicted vs observed delta
- 展示 target ranking
- 存在 DEG artifact 时显示 DEG 相关结果
- 存在 multi-seed report 时展示稳定性摘要
- 存在 error summary / per-perturbation CSV 时展示 split 级与 condition 级失败分析

### 10.2 CLI 交付链路

以下命令已是当前产品化交付的一部分：

- `./scripts/run_doctor.sh`
- `./scripts/run_snapshot.sh`
- `./scripts/run_showcase.sh`
- `./scripts/run_pitch.sh`
- `./scripts/run_app.sh`

这些命令的职责：

- `doctor`：检查仓库、环境、demo artifact、真实结果是否就绪
- `snapshot`：导出面试友好的项目快照
- `showcase`：生成现场演示计划
- `pitch`：生成面试表达脚本
- `app`：直接启动产品界面

### 10.3 质量门槛

当前仓库的“可展示”不再只等于“代码能跑”，还要求：

- README 与配置一致
- `PROJECT_PLAN.md` 与实际模块边界一致
- 基础测试通过
- app 能在 artifact 缺失时给出明确错误
- real / synthetic provenance 不混用

## 11. 阶段演进与后续优先级

### 11.1 已完成阶段

以下阶段可视为已完成：

- Phase 0：项目初始化与环境切换到 `uv`
- Phase 1：Norman2019 预处理与 bundle 导出
- Phase 2：Transformer / MLP / XGBoost 训练闭环
- Phase 3：seen / unseen 评估、DEG overlap、ranking
- Phase 4：Streamlit demo 与基础结果图

### 11.2 当前阶段（Phase 5）

当前继续推进但仍应严格控 scope 的内容：

1. 稳定性
   - 保持多 seed 汇总可复现
   - 保持 error analysis 结构稳定
2. 交付一致性
   - 让 README、`PROJECT_PLAN.md`、`docs/architecture.md` 对同一系统做出一致描述
3. 演示质量
   - 保持 real / synthetic 的 UI 明确区分
   - 保持 `snapshot / showcase / pitch` 输出可信

### 11.3 下一步建议

下一阶段优先做以下“小而稳”的增强，而不是扩展到新平台：

1. 继续完善 error-analysis 资产和结果图，但不把它升级为复杂解释平台。
2. 让 real-data 全流程重跑说明更顺滑，减少首次复现摩擦。
3. 补充更明确的 artifact 生成顺序与依赖说明。
4. 在不扩 scope 的前提下，打磨 demo 体验与讲述一致性。

## 12. 风险与控制策略

### 风险 1：文档再次漂移

控制：

- 所有 substantial change 必须同步审查 `README.md`、`PROJECT_PLAN.md`、相关 config。
- 若变更影响架构或 artifact 合同，必须同步更新 `docs/architecture.md`。

### 风险 2：真实结果与 synthetic 演示混用

控制：

- 所有文档与 UI 明确标注 provenance。
- 不允许用 synthetic 数值陈述生物学性能。

### 风险 3：本地资源不足导致流程脆弱

控制：

- 保持 local-first 默认配置。
- 优先缩小 HVG、batch size、模型深度，而不是引入新型注意力机制。

### 风险 4：为了“更像平台”而扩 scope

控制：

- 继续坚持单数据集、单机、单基因扰动 MVP。
- 新增重大 subsystem 前，先更新本文件的 scope 与验收标准。

## 13. 当前版本 Definition of Done

当前版本可视为“稳定 MVP”的条件如下：

1. `Norman2019` 单基因路径可稳定生成 processed bundle。
2. Transformer、MLP、XGBoost 均可在标准 bundle 上产出结构化结果。
3. seen / unseen 评估、Top-k DEG overlap、ranking 均有明确 artifact。
4. Streamlit 能加载 real 或 synthetic artifact，并明确 provenance。
5. `doctor / snapshot / showcase / pitch` 能辅助完成一次完整演示。
6. `README.md`、`PROJECT_PLAN.md`、配置文件对系统边界与默认行为描述一致。

## 14. 变更原则

后续所有设计变更按以下顺序决策：

1. 正确性
2. 可复现性
3. 本地可运行性
4. 简洁性
5. 可扩展性

不为了“更先进”牺牲可讲清楚、可跑通、可交付。
