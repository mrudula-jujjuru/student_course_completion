-- ============================================================
-- File: stored_procedures.sql
-- Description: Reusable stored procedures for dynamic queries
-- Call using: CALL procedure_name(parameter);
-- ============================================================

USE student_completion;

-- ─────────────────────────────────────────
-- Procedure 1: Get prediction score for a student by name
-- Usage: CALL sp_student_prediction('Priya');
-- Returns prediction score and likelihood for all
-- In Progress enrollments matching the name
-- ─────────────────────────────────────────
DELIMITER $$

CREATE PROCEDURE sp_student_prediction(IN p_name VARCHAR(100))
BEGIN
    SELECT
        s.name,
        c.title                                                  AS course,
        e.completion_pct,
        ROUND(
            (LEAST(1.0, AVG(al.hours_spent)    / 8.0) * 0.30
           + COALESCE(AVG(al.quiz_avg_score) / 100.0, 0) * 0.30
           + LEAST(1.0, AVG(al.videos_watched) / 5.0) * 0.20
           + LEAST(1.0, AVG(al.quizzes_taken)  / 3.0) * 0.10
           + LEAST(1.0, AVG(al.forum_posts)    / 2.0) * 0.10
            ) * 100
        , 1)                                                     AS predicted_score,
        CASE
            WHEN (LEAST(1.0, AVG(al.hours_spent)/8.0)*0.30
                + COALESCE(AVG(al.quiz_avg_score)/100.0,0)*0.30
                + LEAST(1.0, AVG(al.videos_watched)/5.0)*0.20
                + LEAST(1.0, AVG(al.quizzes_taken)/3.0)*0.10
                + LEAST(1.0, AVG(al.forum_posts)/2.0)*0.10) >= 0.65 THEN 'High'
            WHEN (LEAST(1.0, AVG(al.hours_spent)/8.0)*0.30
                + COALESCE(AVG(al.quiz_avg_score)/100.0,0)*0.30
                + LEAST(1.0, AVG(al.videos_watched)/5.0)*0.20
                + LEAST(1.0, AVG(al.quizzes_taken)/3.0)*0.10
                + LEAST(1.0, AVG(al.forum_posts)/2.0)*0.10) >= 0.40 THEN 'Medium'
            ELSE 'Low'
        END                                                      AS completion_likelihood
    FROM enrollments e
    JOIN students s        ON s.student_id     = e.student_id
    JOIN courses c         ON c.course_id      = e.course_id
    JOIN activity_logs al  ON al.enrollment_id = e.enrollment_id
    WHERE e.status = 'In Progress'
      AND s.name LIKE CONCAT('%', p_name, '%')
    GROUP BY e.enrollment_id, s.name, c.title, e.completion_pct;
END$$

DELIMITER ;


-- ─────────────────────────────────────────
-- Procedure 2: Get at-risk students for a specific course
-- Usage: CALL sp_course_at_risk('Cloud Computing');
-- Returns students in that course who are at risk
-- ─────────────────────────────────────────
DELIMITER $$

CREATE PROCEDURE sp_course_at_risk(IN p_course VARCHAR(150))
BEGIN
    SELECT
        s.name,
        e.completion_pct,
        ROUND(AVG(al.hours_spent), 2)     AS avg_weekly_hours,
        ROUND(AVG(al.quiz_avg_score), 1)  AS avg_quiz_score
    FROM enrollments e
    JOIN students s        ON s.student_id     = e.student_id
    JOIN courses c         ON c.course_id      = e.course_id
    JOIN activity_logs al  ON al.enrollment_id = e.enrollment_id
    WHERE e.status = 'In Progress'
      AND c.title LIKE CONCAT('%', p_course, '%')
    GROUP BY e.enrollment_id, s.name, e.completion_pct
    HAVING avg_weekly_hours < 2 OR avg_quiz_score < 50
    ORDER BY avg_weekly_hours ASC;
END$$

DELIMITER ;