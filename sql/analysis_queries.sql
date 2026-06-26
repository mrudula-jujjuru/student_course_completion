-- ============================================================
-- FILE: analysis_queries.sql
-- DESCRIPTION: 10 analytical queries covering completion rates,
--              engagement patterns and student segmentation
-- ============================================================

USE student_completion;

-- ─────────────────────────────────────────
-- Q1. Overall completion rate
-- Result: 57.2% completion across 1,207 enrollments
-- ─────────────────────────────────────────
SELECT
    COUNT(*)                                                   AS total_enrollments,
    SUM(status = 'Completed')                                  AS completed,
    SUM(status = 'In Progress')                                AS in_progress,
    SUM(status = 'Dropped')                                    AS dropped,
    ROUND(100.0 * SUM(status = 'Completed') / COUNT(*), 1)    AS completion_rate_pct
FROM enrollments;

-- ─────────────────────────────────────────
-- Q2. Completion rate by course
-- Insight: Beginner courses dominate top spots;
--          Advanced ML courses struggle most (42-48%)
-- ─────────────────────────────────────────
SELECT
    c.title, c.difficulty, c.category,
    COUNT(*)                                                        AS total,
    SUM(e.status = 'Completed')                                     AS completed,
    ROUND(100.0 * SUM(e.status = 'Completed') / COUNT(*), 1)       AS completion_pct,
    ROUND(AVG(e.final_score), 1)                                    AS avg_score
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
GROUP BY c.course_id, c.title, c.difficulty, c.category
ORDER BY completion_pct DESC;

-- ─────────────────────────────────────────
-- Q3. Completion rate by difficulty
-- Insight: Beginner 62.5% → Intermediate 59.8% → Advanced 45.4%
--          Advanced courses have 31.6% dropout rate
-- ─────────────────────────────────────────
SELECT
    c.difficulty,
    COUNT(*)                                                        AS total_enrollments,
    SUM(e.status = 'Completed')                                     AS completed,
    SUM(e.status = 'Dropped')                                       AS dropped,
    ROUND(100.0 * SUM(e.status = 'Completed') / COUNT(*), 1)       AS completion_pct
FROM enrollments e
JOIN courses c ON e.course_id = c.course_id
GROUP BY c.difficulty
ORDER BY completion_pct DESC;

-- ─────────────────────────────────────────
-- Q4. Completion rate by education level
-- Insight: PhD holders complete at 66.9% vs High School at 51.6%
-- ─────────────────────────────────────────
SELECT
    s.education_level,
    COUNT(*)                                                        AS total,
    SUM(e.status = 'Completed')                                     AS completed,
    ROUND(100.0 * SUM(e.status = 'Completed') / COUNT(*), 1)       AS completion_pct
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
GROUP BY s.education_level
ORDER BY completion_pct DESC;

-- ─────────────────────────────────────────
-- Q5. Completion rate by employment status
-- Insight: Students (62.3%) outperform Employed (53.5%)
--          due to time availability and learning mindset
-- ─────────────────────────────────────────
SELECT
    s.employment,
    COUNT(*)                                                        AS total,
    SUM(e.status = 'Completed')                                     AS completed,
    ROUND(100.0 * SUM(e.status = 'Completed') / COUNT(*), 1)       AS completion_pct
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
GROUP BY s.employment
ORDER BY completion_pct DESC;

-- ─────────────────────────────────────────
-- Q6. Completion rate by age band
-- Insight: 18-24 year olds lead at 69.1%;
--          35-44 struggle most at 48.4% (peak career/family pressure)
-- ─────────────────────────────────────────
SELECT
    CASE
        WHEN s.age BETWEEN 18 AND 24 THEN '18-24'
        WHEN s.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN s.age BETWEEN 35 AND 44 THEN '35-44'
        ELSE '45+'
    END AS age_band,
    COUNT(*)                                                        AS total,
    SUM(e.status = 'Completed')                                     AS completed,
    ROUND(100.0 * SUM(e.status = 'Completed') / COUNT(*), 1)       AS completion_pct
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
GROUP BY age_band
ORDER BY age_band;

-- ─────────────────────────────────────────
-- Q7. Weekly engagement by outcome
-- Insight: Completers study 2.7x more hours than dropouts
--          Forum participation drops 7x between completers and dropouts
-- ─────────────────────────────────────────
SELECT
    e.status,
    ROUND(AVG(al.hours_spent), 2)     AS avg_hours_per_week,
    ROUND(AVG(al.videos_watched), 1)  AS avg_videos,
    ROUND(AVG(al.forum_posts), 2)     AS avg_forum_posts,
    ROUND(AVG(al.quizzes_taken), 1)   AS avg_quizzes
FROM enrollments e
JOIN activity_logs al ON al.enrollment_id = e.enrollment_id
GROUP BY e.status;

-- ─────────────────────────────────────────
-- Q8. Top 10 most engaged students
-- ─────────────────────────────────────────
SELECT
    s.name, s.education_level, s.location,
    COUNT(DISTINCT e.enrollment_id)              AS courses_enrolled,
    SUM(e.status = 'Completed')                  AS courses_completed,
    ROUND(SUM(al.hours_spent), 1)                AS total_hours
FROM students s
JOIN enrollments e    ON e.student_id     = s.student_id
JOIN activity_logs al ON al.enrollment_id = e.enrollment_id
GROUP BY s.student_id, s.name, s.education_level, s.location
ORDER BY total_hours DESC
LIMIT 10;

-- ─────────────────────────────────────────
-- Q9. At-risk students
-- Students who are In Progress but have dangerously low engagement
-- Insight: Cloud Computing appears 4x — has a specific retention problem
-- ─────────────────────────────────────────
SELECT
    s.name, c.title AS course,
    e.completion_pct,
    ROUND(AVG(al.hours_spent), 2)     AS avg_weekly_hours,
    ROUND(AVG(al.quiz_avg_score), 1)  AS avg_quiz_score,
    e.status
FROM enrollments e
JOIN students s        ON s.student_id     = e.student_id
JOIN courses c         ON c.course_id      = e.course_id
JOIN activity_logs al  ON al.enrollment_id = e.enrollment_id
WHERE e.status = 'In Progress'
  AND e.completion_pct > 25
GROUP BY e.enrollment_id, s.name, c.title, e.completion_pct, e.status
HAVING avg_weekly_hours < 2 OR avg_quiz_score < 50
ORDER BY avg_weekly_hours ASC
LIMIT 15;

-- ─────────────────────────────────────────
-- Q10. Completion prediction score (0-100)
-- Weighted composite score using 5 engagement signals:
--   30% hours studied + 30% quiz performance
--   20% videos watched + 10% quizzes taken + 10% forum activity
-- ─────────────────────────────────────────
WITH student_metrics AS (
    SELECT
        e.enrollment_id,
        s.name,
        c.title                                                  AS course,
        e.completion_pct,
        LEAST(1.0, AVG(al.hours_spent)    / 8.0)                AS hours_norm,
        LEAST(1.0, AVG(al.videos_watched) / 5.0)                AS videos_norm,
        LEAST(1.0, AVG(al.quizzes_taken)  / 3.0)                AS quizzes_norm,
        COALESCE(AVG(al.quiz_avg_score) / 100.0, 0)             AS quiz_score_norm,
        LEAST(1.0, AVG(al.forum_posts)    / 2.0)                AS forum_norm
    FROM enrollments e
    JOIN students s        ON s.student_id     = e.student_id
    JOIN courses c         ON c.course_id      = e.course_id
    JOIN activity_logs al  ON al.enrollment_id = e.enrollment_id
    WHERE e.status = 'In Progress'
    GROUP BY e.enrollment_id, s.name, c.title, e.completion_pct
)
SELECT
    name, course,
    ROUND(completion_pct, 1)      AS progress_pct,
    ROUND(
        (hours_norm * 0.30 + quiz_score_norm * 0.30
       + videos_norm * 0.20 + quizzes_norm * 0.10
       + forum_norm  * 0.10) * 100
    , 1)                          AS predicted_score,
    CASE
     WHEN (hours_norm*0.30 + quiz_score_norm*0.30
            + videos_norm*0.20 + quizzes_norm*0.10
            + forum_norm*0.10) >= 0.65 THEN 'High'
        WHEN (hours_norm*0.30 + quiz_score_norm*0.30
            + videos_norm*0.20 + quizzes_norm*0.10
            + forum_norm*0.10) >= 0.40 THEN 'Medium'
        ELSE 'Low'
    END                           AS completion_likelihood
FROM student_metrics
