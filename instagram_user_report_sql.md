# Instagram 用户报告 SQL 查询指令文档

生成日期：2026-06-04  
数据库：MySQL 8.0.44  
分析库：`instagram`

> 说明：以下命令默认在 PowerShell 中执行。为了安全，连接命令使用 `-p` 交互输入密码，不把密码写入命令。

## 1. 连接 MySQL

```powershell
& 'H:\MySQL\MySQL Server 8.0\bin\mysql.exe' -h localhost -P 3306 -u root -p
```

进入 MySQL 后切换数据库：

```sql
USE instagram;
```

也可以在 PowerShell 中直接执行单条 SQL：

```powershell
& 'H:\MySQL\MySQL Server 8.0\bin\mysql.exe' -h localhost -P 3306 -u root -p instagram -e "SELECT VERSION();"
```

## 2. 数据库与表结构检查

```sql
SHOW DATABASES;

SHOW TABLES;

SELECT
  table_schema,
  table_name,
  table_rows
FROM information_schema.tables
WHERE table_schema IN ('instagram', 'learning')
ORDER BY table_schema, table_name;

SELECT
  table_schema,
  table_name,
  column_name,
  data_type,
  column_key
FROM information_schema.columns
WHERE table_schema = 'instagram'
ORDER BY table_name, ordinal_position;
```

## 3. 全量规模与时间范围

```sql
SELECT
  'users' AS metric,
  COUNT(*) AS value,
  MIN(created_at) AS min_date,
  MAX(created_at) AS max_date
FROM users
UNION ALL
SELECT
  'photos',
  COUNT(*),
  MIN(created_date),
  MAX(created_date)
FROM photos
UNION ALL
SELECT
  'likes',
  COUNT(*),
  MIN(created_at),
  MAX(created_at)
FROM likes
UNION ALL
SELECT
  'comments',
  COUNT(*),
  MIN(created_at),
  MAX(created_at)
FROM comments
UNION ALL
SELECT
  'follows',
  COUNT(*),
  MIN(created_at),
  MAX(created_at)
FROM follows;
```

## 4. 月度新增用户

```sql
SELECT
  DATE_FORMAT(created_at, '%Y-%m') AS month,
  COUNT(*) AS new_users
FROM users
GROUP BY 1
ORDER BY 1;
```

## 5. 星期维度新增用户

```sql
SELECT
  DAYNAME(created_at) AS weekday,
  COUNT(*) AS new_users
FROM users
GROUP BY weekday
ORDER BY FIELD(
  weekday,
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
);
```

## 6. 用户活跃总览

统计每个用户的发图、点赞、评论、关注、被关注情况，再汇总整体活跃水平。

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
l AS (
  SELECT user_id, COUNT(*) AS likes_given
  FROM likes
  GROUP BY user_id
),
c AS (
  SELECT user_id, COUNT(*) AS comments_given
  FROM comments
  GROUP BY user_id
),
fg AS (
  SELECT follower_id AS user_id, COUNT(*) AS follows_given
  FROM follows
  GROUP BY follower_id
),
fr AS (
  SELECT followee_id AS user_id, COUNT(*) AS followers_received
  FROM follows
  GROUP BY followee_id
),
activity AS (
  SELECT
    u.id,
    u.username,
    COALESCE(p.photos, 0) AS photos,
    COALESCE(l.likes_given, 0) AS likes_given,
    COALESCE(c.comments_given, 0) AS comments_given,
    COALESCE(fg.follows_given, 0) AS follows_given,
    COALESCE(fr.followers_received, 0) AS followers_received
  FROM users u
  LEFT JOIN p ON p.user_id = u.id
  LEFT JOIN l ON l.user_id = u.id
  LEFT JOIN c ON c.user_id = u.id
  LEFT JOIN fg ON fg.user_id = u.id
  LEFT JOIN fr ON fr.user_id = u.id
)
SELECT
  COUNT(*) AS users,
  SUM(photos > 0) AS posters,
  SUM(likes_given > 0) AS likers,
  SUM(comments_given > 0) AS commenters,
  SUM(follows_given > 0) AS follow_initiators,
  SUM(followers_received > 0) AS users_with_followers,
  ROUND(AVG(photos), 2) AS avg_photos,
  ROUND(AVG(likes_given), 2) AS avg_likes_given,
  ROUND(AVG(comments_given), 2) AS avg_comments_given,
  ROUND(AVG(follows_given), 2) AS avg_follows_given,
  ROUND(AVG(followers_received), 2) AS avg_followers_received
FROM activity;
```

## 7. 用户主动活跃分层

主动事件 = 发图 + 点赞 + 评论 + 关注。

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
l AS (
  SELECT user_id, COUNT(*) AS likes_given
  FROM likes
  GROUP BY user_id
),
c AS (
  SELECT user_id, COUNT(*) AS comments_given
  FROM comments
  GROUP BY user_id
),
fg AS (
  SELECT follower_id AS user_id, COUNT(*) AS follows_given
  FROM follows
  GROUP BY follower_id
),
a AS (
  SELECT
    u.id,
    u.username,
    COALESCE(p.photos, 0) AS photos,
    COALESCE(l.likes_given, 0) AS likes_given,
    COALESCE(c.comments_given, 0) AS comments_given,
    COALESCE(fg.follows_given, 0) AS follows_given,
    COALESCE(p.photos, 0)
      + COALESCE(l.likes_given, 0)
      + COALESCE(c.comments_given, 0)
      + COALESCE(fg.follows_given, 0) AS outbound_events
  FROM users u
  LEFT JOIN p ON p.user_id = u.id
  LEFT JOIN l ON l.user_id = u.id
  LEFT JOIN c ON c.user_id = u.id
  LEFT JOIN fg ON fg.user_id = u.id
)
SELECT
  CASE
    WHEN outbound_events = 0 THEN '0 no outbound activity'
    WHEN outbound_events < 50 THEN '1-49 light'
    WHEN outbound_events < 150 THEN '50-149 medium'
    ELSE '150+ heavy'
  END AS activity_band,
  COUNT(*) AS users,
  ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM users), 1) AS pct_users,
  SUM(outbound_events) AS total_outbound_events
FROM a
GROUP BY activity_band
ORDER BY activity_band;
```

## 8. 沉默用户明细

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
l AS (
  SELECT user_id, COUNT(*) AS likes_given
  FROM likes
  GROUP BY user_id
),
c AS (
  SELECT user_id, COUNT(*) AS comments_given
  FROM comments
  GROUP BY user_id
),
fg AS (
  SELECT follower_id AS user_id, COUNT(*) AS follows_given
  FROM follows
  GROUP BY follower_id
),
a AS (
  SELECT
    u.username,
    u.created_at,
    COALESCE(p.photos, 0) AS photos,
    COALESCE(l.likes_given, 0) AS likes_given,
    COALESCE(c.comments_given, 0) AS comments_given,
    COALESCE(fg.follows_given, 0) AS follows_given,
    COALESCE(p.photos, 0)
      + COALESCE(l.likes_given, 0)
      + COALESCE(c.comments_given, 0)
      + COALESCE(fg.follows_given, 0) AS outbound_events
  FROM users u
  LEFT JOIN p ON p.user_id = u.id
  LEFT JOIN l ON l.user_id = u.id
  LEFT JOIN c ON c.user_id = u.id
  LEFT JOIN fg ON fg.user_id = u.id
)
SELECT
  username,
  created_at,
  photos,
  likes_given,
  comments_given,
  follows_given,
  outbound_events
FROM a
WHERE outbound_events = 0
ORDER BY created_at;
```

## 9. 用户发图数分布

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
a AS (
  SELECT
    u.id,
    COALESCE(p.photos, 0) AS photos
  FROM users u
  LEFT JOIN p ON p.user_id = u.id
)
SELECT
  CASE
    WHEN photos = 0 THEN '0 photos'
    WHEN photos = 1 THEN '1 photo'
    WHEN photos BETWEEN 2 AND 4 THEN '2-4 photos'
    WHEN photos BETWEEN 5 AND 9 THEN '5-9 photos'
    ELSE '10+ photos'
  END AS photo_band,
  COUNT(*) AS users,
  ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM users), 1) AS pct_users,
  SUM(photos) AS total_photos
FROM a
GROUP BY photo_band
ORDER BY MIN(photos);
```

## 10. 主动行为构成

```sql
WITH user_events AS (
  SELECT user_id, 'photo' AS event_type
  FROM photos
  UNION ALL
  SELECT user_id, 'like'
  FROM likes
  UNION ALL
  SELECT user_id, 'comment'
  FROM comments
  UNION ALL
  SELECT follower_id, 'follow'
  FROM follows
)
SELECT
  event_type,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS active_users,
  ROUND(COUNT(*) / COUNT(DISTINCT user_id), 2) AS events_per_active_user
FROM user_events
GROUP BY event_type
ORDER BY events DESC;
```

## 11. 单张照片互动表现

### 11.1 Top 10 高互动照片

```sql
WITH photo_perf AS (
  SELECT
    p.id AS photo_id,
    u.username AS author,
    COUNT(DISTINCT l.user_id) AS likes,
    COUNT(DISTINCT c.id) AS comments,
    COUNT(DISTINCT pt.tag_id) AS tags
  FROM photos p
  JOIN users u ON u.id = p.user_id
  LEFT JOIN likes l ON l.photo_id = p.id
  LEFT JOIN comments c ON c.photo_id = p.id
  LEFT JOIN photo_tags pt ON pt.photo_id = p.id
  GROUP BY p.id, u.username
)
SELECT
  photo_id,
  author,
  likes,
  comments,
  tags,
  likes + comments AS engagement
FROM photo_perf
ORDER BY engagement DESC
LIMIT 10;
```

### 11.2 平均单图互动

```sql
SELECT
  ROUND(AVG(likes), 2) AS avg_likes_per_photo,
  ROUND(AVG(comments), 2) AS avg_comments_per_photo,
  ROUND(AVG(likes + comments), 2) AS avg_engagement_per_photo
FROM (
  SELECT
    p.id,
    COUNT(DISTINCT l.user_id) AS likes,
    COUNT(DISTINCT c.id) AS comments
  FROM photos p
  LEFT JOIN likes l ON l.photo_id = p.id
  LEFT JOIN comments c ON c.photo_id = p.id
  GROUP BY p.id
) x;
```

## 12. 入站影响力最高用户

入站影响分 = 收到关注 + 收到点赞 + 收到评论。

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
l AS (
  SELECT user_id, COUNT(*) AS likes_given
  FROM likes
  GROUP BY user_id
),
c AS (
  SELECT user_id, COUNT(*) AS comments_given
  FROM comments
  GROUP BY user_id
),
fg AS (
  SELECT follower_id AS user_id, COUNT(*) AS follows_given
  FROM follows
  GROUP BY follower_id
),
fr AS (
  SELECT followee_id AS user_id, COUNT(*) AS followers_received
  FROM follows
  GROUP BY followee_id
),
pr AS (
  SELECT p.user_id, COUNT(l.user_id) AS likes_received
  FROM photos p
  LEFT JOIN likes l ON l.photo_id = p.id
  GROUP BY p.user_id
),
cr AS (
  SELECT p.user_id, COUNT(c.id) AS comments_received
  FROM photos p
  LEFT JOIN comments c ON c.photo_id = p.id
  GROUP BY p.user_id
)
SELECT
  u.username,
  COALESCE(p.photos, 0) AS photos,
  COALESCE(l.likes_given, 0) AS likes_given,
  COALESCE(c.comments_given, 0) AS comments_given,
  COALESCE(fg.follows_given, 0) AS follows_given,
  COALESCE(fr.followers_received, 0) AS followers_received,
  COALESCE(pr.likes_received, 0) AS likes_received,
  COALESCE(cr.comments_received, 0) AS comments_received,
  COALESCE(pr.likes_received, 0)
    + COALESCE(cr.comments_received, 0)
    + COALESCE(fr.followers_received, 0) AS inbound_score
FROM users u
LEFT JOIN p ON p.user_id = u.id
LEFT JOIN l ON l.user_id = u.id
LEFT JOIN c ON c.user_id = u.id
LEFT JOIN fg ON fg.user_id = u.id
LEFT JOIN fr ON fr.user_id = u.id
LEFT JOIN pr ON pr.user_id = u.id
LEFT JOIN cr ON cr.user_id = u.id
ORDER BY inbound_score DESC, followers_received DESC
LIMIT 10;
```

## 13. 主动行为最高用户

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
l AS (
  SELECT user_id, COUNT(*) AS likes_given
  FROM likes
  GROUP BY user_id
),
c AS (
  SELECT user_id, COUNT(*) AS comments_given
  FROM comments
  GROUP BY user_id
),
fg AS (
  SELECT follower_id AS user_id, COUNT(*) AS follows_given
  FROM follows
  GROUP BY follower_id
),
a AS (
  SELECT
    u.username,
    COALESCE(p.photos, 0) AS photos,
    COALESCE(l.likes_given, 0) AS likes_given,
    COALESCE(c.comments_given, 0) AS comments_given,
    COALESCE(fg.follows_given, 0) AS follows_given,
    COALESCE(p.photos, 0)
      + COALESCE(l.likes_given, 0)
      + COALESCE(c.comments_given, 0)
      + COALESCE(fg.follows_given, 0) AS outbound_events
  FROM users u
  LEFT JOIN p ON p.user_id = u.id
  LEFT JOIN l ON l.user_id = u.id
  LEFT JOIN c ON c.user_id = u.id
  LEFT JOIN fg ON fg.user_id = u.id
)
SELECT
  username,
  photos,
  likes_given,
  comments_given,
  follows_given,
  outbound_events
FROM a
ORDER BY outbound_events DESC
LIMIT 10;
```

## 14. 关注网络集中度

### 14.1 收到关注最多的用户

```sql
WITH
fr AS (
  SELECT followee_id AS user_id, COUNT(*) AS followers_received
  FROM follows
  GROUP BY followee_id
),
ranked AS (
  SELECT
    u.username,
    COALESCE(fr.followers_received, 0) AS followers_received,
    ROW_NUMBER() OVER (
      ORDER BY COALESCE(fr.followers_received, 0) DESC, u.username
    ) AS rn
  FROM users u
  LEFT JOIN fr ON fr.user_id = u.id
)
SELECT
  username,
  followers_received
FROM ranked
WHERE rn <= 10
ORDER BY followers_received DESC, username;
```

### 14.2 Top 10 收到关注占比

```sql
WITH
fr AS (
  SELECT followee_id AS user_id, COUNT(*) AS followers_received
  FROM follows
  GROUP BY followee_id
),
ranked AS (
  SELECT
    u.username,
    COALESCE(fr.followers_received, 0) AS followers_received,
    ROW_NUMBER() OVER (
      ORDER BY COALESCE(fr.followers_received, 0) DESC, u.username
    ) AS rn
  FROM users u
  LEFT JOIN fr ON fr.user_id = u.id
)
SELECT
  SUM(CASE WHEN rn <= 10 THEN followers_received ELSE 0 END) AS top10_followers,
  SUM(followers_received) AS total_followers,
  ROUND(
    100 * SUM(CASE WHEN rn <= 10 THEN followers_received ELSE 0 END)
    / SUM(followers_received),
    1
  ) AS top10_share_pct,
  MIN(followers_received) AS min_followers,
  MAX(followers_received) AS max_followers
FROM ranked;
```

## 15. 注册月份 cohort 活跃概览

```sql
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
l AS (
  SELECT user_id, COUNT(*) AS likes_given
  FROM likes
  GROUP BY user_id
),
c AS (
  SELECT user_id, COUNT(*) AS comments_given
  FROM comments
  GROUP BY user_id
),
fg AS (
  SELECT follower_id AS user_id, COUNT(*) AS follows_given
  FROM follows
  GROUP BY follower_id
),
a AS (
  SELECT
    u.id,
    DATE_FORMAT(u.created_at, '%Y-%m') AS cohort_month,
    COALESCE(p.photos, 0) AS photos,
    COALESCE(l.likes_given, 0) AS likes_given,
    COALESCE(c.comments_given, 0) AS comments_given,
    COALESCE(fg.follows_given, 0) AS follows_given,
    COALESCE(p.photos, 0)
      + COALESCE(l.likes_given, 0)
      + COALESCE(c.comments_given, 0)
      + COALESCE(fg.follows_given, 0) AS outbound_events
  FROM users u
  LEFT JOIN p ON p.user_id = u.id
  LEFT JOIN l ON l.user_id = u.id
  LEFT JOIN c ON c.user_id = u.id
  LEFT JOIN fg ON fg.user_id = u.id
)
SELECT
  cohort_month,
  COUNT(*) AS users,
  SUM(outbound_events > 0) AS active_users,
  ROUND(100 * SUM(outbound_events > 0) / COUNT(*), 1) AS active_rate_pct,
  SUM(photos > 0) AS posters,
  ROUND(100 * SUM(photos > 0) / COUNT(*), 1) AS poster_rate_pct,
  SUM(outbound_events) AS outbound_events
FROM a
GROUP BY cohort_month
ORDER BY cohort_month;
```

## 16. 热门标签

```sql
SELECT
  t.tag_name,
  COUNT(*) AS photo_count,
  COUNT(DISTINCT pt.photo_id) AS photos
FROM tags t
JOIN photo_tags pt ON pt.tag_id = t.id
GROUP BY t.id, t.tag_name
ORDER BY photo_count DESC
LIMIT 10;
```

## 17. 常用快速检查

```sql
SELECT COUNT(*) AS users FROM users;
SELECT COUNT(*) AS photos FROM photos;
SELECT COUNT(*) AS likes FROM likes;
SELECT COUNT(*) AS comments FROM comments;
SELECT COUNT(*) AS follows FROM follows;

SELECT * FROM users LIMIT 10;
SELECT * FROM photos LIMIT 10;
SELECT * FROM likes LIMIT 10;
SELECT * FROM comments LIMIT 10;
SELECT * FROM follows LIMIT 10;
SELECT * FROM tags LIMIT 10;
SELECT * FROM photo_tags LIMIT 10;
```

## 18. 报告关键结果对照

这组查询在当前数据库中得到的关键结果：

- 用户数：100
- 照片数：257
- 点赞数：8782
- 评论数：7488
- 关注数：7623
- 发图用户：74
- 零发图用户：26
- 沉默用户：13
- 重度主动互动用户：77
- 平均点赞/照片：34.17
- 平均评论/照片：29.14
- 平均互动/照片：63.31

