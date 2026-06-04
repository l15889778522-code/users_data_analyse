USE instagram;

-- 1. Dataset size and date range
SELECT
  'users' AS metric,
  COUNT(*) AS value,
  MIN(created_at) AS min_date,
  MAX(created_at) AS max_date
FROM users
UNION ALL
SELECT 'photos', COUNT(*), MIN(created_date), MAX(created_date) FROM photos
UNION ALL
SELECT 'likes', COUNT(*), MIN(created_at), MAX(created_at) FROM likes
UNION ALL
SELECT 'comments', COUNT(*), MIN(created_at), MAX(created_at) FROM comments
UNION ALL
SELECT 'follows', COUNT(*), MIN(created_at), MAX(created_at) FROM follows;

-- 2. Monthly new users
SELECT
  DATE_FORMAT(created_at, '%Y-%m') AS month,
  COUNT(*) AS new_users
FROM users
GROUP BY 1
ORDER BY 1;

-- 3. User activity summary
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
  ROUND(AVG(follows_given), 2) AS avg_follows_given
FROM activity;

-- 4. Outbound activity bands
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

-- 5. Photo publishing distribution
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
),
a AS (
  SELECT u.id, COALESCE(p.photos, 0) AS photos
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

-- 6. Outbound event mix
WITH user_events AS (
  SELECT user_id, 'photo' AS event_type FROM photos
  UNION ALL
  SELECT user_id, 'like' FROM likes
  UNION ALL
  SELECT user_id, 'comment' FROM comments
  UNION ALL
  SELECT follower_id, 'follow' FROM follows
)
SELECT
  event_type,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS active_users,
  ROUND(COUNT(*) / COUNT(DISTINCT user_id), 2) AS events_per_active_user
FROM user_events
GROUP BY event_type
ORDER BY events DESC;

-- 7. Average engagement per photo
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

-- 8. Top users by inbound influence
WITH
p AS (
  SELECT user_id, COUNT(*) AS photos
  FROM photos
  GROUP BY user_id
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
  COALESCE(fr.followers_received, 0) AS followers_received,
  COALESCE(pr.likes_received, 0) AS likes_received,
  COALESCE(cr.comments_received, 0) AS comments_received,
  COALESCE(pr.likes_received, 0)
    + COALESCE(cr.comments_received, 0)
    + COALESCE(fr.followers_received, 0) AS inbound_score
FROM users u
LEFT JOIN p ON p.user_id = u.id
LEFT JOIN fr ON fr.user_id = u.id
LEFT JOIN pr ON pr.user_id = u.id
LEFT JOIN cr ON cr.user_id = u.id
ORDER BY inbound_score DESC
LIMIT 10;

-- 9. Signup cohort activity summary
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

-- 10. Top tags
SELECT
  t.tag_name,
  COUNT(*) AS photo_count,
  COUNT(DISTINCT pt.photo_id) AS photos
FROM tags t
JOIN photo_tags pt ON pt.tag_id = t.id
GROUP BY t.id, t.tag_name
ORDER BY photo_count DESC
LIMIT 10;
