-- ============================================================
-- File: views.sql
-- Description: 6 reusable views for reporting and Power BI
-- Views act like saved queries — call them like tables
-- ============================================================

USE student_completion;

-- View 1: Overall completion summary
-- Use for KPI cards in Power BI
CREATE VIEW vw_completion_summary AS
SELECT
    COUNT(*)                                                    AS total_enrollments,
    SUM(status = 'Completed')                                   AS completed,
    SUM(status = 'In Progress')                                 AS in_progress,
    SUM(status = 'Dropped')                                     AS dropped,
    ROUND(100.0 * SUM(status = 'Completed') / COUNT(*), 1)     AS completion_rate_pct
FROM enrollments;


-- View 2: Course performance breakdown
-- Use for bar charts comparing courses
CREATE VIEW vw_course_performance AS
SELECT
    c.title,
    c.difficulty,
    c.category,
    COUNT(*)                                                        AS total,
    SUM(e.status = 'Completed')                                     AS completed,
    ROUND(100.0 * SUM(e.status = 'Completed') / COUNT(*), 1)       AS completion_pct,
    ROUND(AVG(e.final_score), 1)                                    AS avg_score
FROM enrollments e
JOIN courses c ON c.course_id = e.course_id
GROUP BY c.course_id, c.title, c.difficulty, c.category;


-- View 3: Student engagement profile
-- Use for scatter plots and top student tables
CREATE VIEW vw_student_engagement AS
SELECT
    s.student_id,
    s.name,
    s.education_level,
    s.employment,
    s.location,
    COUNT(DISTINCT e.enrollment_id)          AS courses_enrolled,
    SUM(e.status = 'Completed')              AS courses_completed,
    ROUND(AVG(al.hours_spent), 2)            AS avg_hours_per_week,
    ROUND(AVG(al.videos_watched), 1)         AS avg_videos_per_week,
    ROUND(AVG(al.forum_posts), 2)            AS avg_forum_posts,
    ROUND(SUM(al.hours_spent), 1)            AS total_hours
FROM students s
JOIN enrollments e    ON e.student_id      = s.student_id
JOIN activity_logs al ON al.enrollment_id  = e.enrollment_id
GROUP BY s.student_id, s.name, s.education_level, s.employment, s.location;


-- View 4: At-risk students
-- In Progress students showing low engagement signals
CREATE VIEW vw_at_risk_students AS
SELECT
    s.name,
    c.title                            AS course,
    e.completion_pct,
    ROUND(AVG(al.hours_spent), 2)      AS avg_weekly_hours,
    ROUND(AVG(al.quiz_avg_score), 1)   AS avg_quiz_score,
    e.status
FROM enrollments e
JOIN students s        ON s.student_id     = e.student_id
JOIN courses c         ON c.course_id      = e.course_id
JOIN activity_logs al  ON al.enrollment_id = e.enrollment_id
WHERE e.status = 'In Progress'
  AND e.completion_pct > 25
GROUP BY e.enrollment_id, s.name, c.title, e.completion_pct, e.status
HAVING avg_weekly_hours < 2 OR avg_quiz_score < 50;


-- View 5: Completion prediction scores
-- Composite score predicting likelihood of course completion
CREATE VIEW vw_prediction_scores AS
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
    name,
    course,
    ROUND(completion_pct, 1)      AS progress_pct,
    ROUND(
        (hours_norm      * 0.30
       + quiz_score_norm * 0.30
       + videos_norm     * 0.20
       + quizzes_norm    * 0.10
       + forum_norm      * 0.10) * 100
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
FROM student_metrics;


-- View 6: Segmentation view for clustered bar charts
-- Includes age band, difficulty, education in one place
CREATE VIEW vw_completion_by_segment AS
SELECT
    s.student_id,
    s.name,
    s.education_level,
    s.employment,
    s.gender,
    s.location,
    CASE
        WHEN s.age BETWEEN 18 AND 24 THEN '18-24'
        WHEN s.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN s.age BETWEEN 35 AND 44 THEN '35-44'
        ELSE '45+'
    END                                                         AS age_band,
    c.difficulty,
    c.category,
    c.title                                                     AS course_title,
    e.status,
    e.completion_pct,
    e.final_score
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
JOIN courses c     ON c.course_id  = e.course_id;