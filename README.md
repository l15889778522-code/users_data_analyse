# instagram用户数据分析

这是一个基于 MySQL 的用户数据分析项目，对类 Instagram 社交平台的用户增长、内容生产、互动行为、关注关系和用户分层进行分析。

项目目标是把原始用户行为数据整理成一份适合简历展示的数据分析作品：既包含可复现的数据文件，也包含 SQL 分析脚本、完整查询文档和用户数据分析报告。


源项目许可证：Apache License 2.0

本仓库保留原始 CSV 数据格式，数据文件位于 `data/` 目录：

| 文件 | 含义 |
| --- | --- |
| `users.csv` | 用户注册信息 |
| `photos.csv` | 用户发布照片 |
| `likes.csv` | 用户点赞行为 |
| `comments.csv` | 用户评论行为 |
| `follows.csv` | 用户关注关系 |
| `tags.csv` | 标签字典 |
| `photo_tags.csv` | 照片与标签关系 |

## 项目亮点

- 使用 MySQL CTE、聚合、条件分层、多表关联和窗口函数完成用户行为分析。
- 从用户、照片、点赞、评论、关注、标签等数据中构建完整分析链路。
- 识别核心业务问题：平台互动密度高，但内容供给不足。
- 输出可直接用于简历展示的 SQL 脚本、查询文档和业务分析报告。

## 核心结论

- 数据集中共有 100 个用户、257 张照片、8,782 次点赞、7,488 条评论和 7,623 条关注。
- 77% 的用户属于重度主动互动层，说明社区互动意愿较强。
- 26% 的用户没有发布任何照片，13% 的用户没有任何主动行为。
- 平均每张照片获得 34.17 次点赞和 29.14 条评论，内容一旦发布就能获得较高互动。
- 用户关系网络非常均匀，每个用户收到 76-77 个关注，主要短板不是连接关系，而是内容生产。

## 业务建议

1. 优先激活零发图和低发图用户，降低首次发布门槛。
2. 将高互动但低产出的用户转化为内容创作者。
3. 利用热门标签优化发布提示和内容推荐。
4. 补充真实行为时间线，用于后续留存、周报和趋势分析。

## 项目结构

```text
.
├── README.md
├── data
│   ├── comments.csv
│   ├── follows.csv
│   ├── likes.csv
│   ├── photo_tags.csv
│   ├── photos.csv
│   ├── tags.csv
│   └── users.csv
├── docs
│   └── user_report.md
├── instagram_user_report_sql.md
└── sql
    └── instagram_user_analysis.sql
```

## 如何复现

1. 启动 MySQL。
2. 根据 `data/` 目录中的 CSV 文件创建并导入 `instagram` 数据库。
3. 切换数据库：

```sql
USE instagram;
```

4. 执行 SQL 分析脚本：

```powershell
Get-Content sql\instagram_user_analysis.sql | & 'H:\MySQL\MySQL Server 8.0\bin\mysql.exe' -h localhost -P 3306 -u root -p instagram
```

完整查询说明见：

[instagram_user_report_sql.md](instagram_user_report_sql.md)

完整用户数据分析报告见：

[docs/user_report.md](docs/user_report.md)

## 可展示技能

- SQL 数据清洗与分析
- 多表关联建模
- 用户活跃分层
- 内容表现分析
- 社交网络基础分析
- Cohort 分析
- 业务报告写作

## 适合放在简历里的项目描述

使用 MySQL 对类 Instagram 社交平台原始 CSV 数据进行用户行为分析，围绕用户增长、活跃分层、内容生产、互动质量和关注网络构建 SQL 分析链路。通过 CTE、多表关联、窗口函数和条件聚合识别出平台核心问题：互动密度高但内容供给不足，并提出创作者激活、低发图用户转化和热门标签运营等业务建议。

