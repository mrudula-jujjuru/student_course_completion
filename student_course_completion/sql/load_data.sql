-- ============================================================
-- FILE: load_data.sql
-- DESCRIPTION: Loads CSV data into all 5 tables
-- NOTE: Update file paths to match your local machine
--       Run from MySQL command line with --local-infile=1
--       Command: mysql --local-infile=1 -u root -p
-- ============================================================

USE student_completion;

-- Enable local file loading
SET GLOBAL local_infile = 1;

-- Load courses first (no dependencies)
LOAD DATA LOCAL INFILE '/your/path/data/courses.csv'
INTO TABLE courses
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Load students second (no dependencies)
LOAD DATA LOCAL INFILE '/your/path/data/students.csv'
INTO TABLE students
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Load enrollments (depends on students and courses)
LOAD DATA LOCAL INFILE '/your/path/data/enrollments.csv'
INTO TABLE enrollments
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(enrollment_id, student_id, course_id, enrolled_date,
 @comp_date, status, completion_pct, @final_score)
SET
  completion_date = NULLIF(@comp_date, ''),
  final_score     = NULLIF(@final_score, '');

-- Load activity logs (depends on enrollments)
LOAD DATA LOCAL INFILE '/your/path/data/activity_logs.csv'
INTO TABLE activity_logs
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(log_id, enrollment_id, week_number, videos_watched,
 quizzes_taken, @quiz_avg, forum_posts, hours_spent)
SET quiz_avg_score = NULLIF(@quiz_avg, '');

-- Load quiz results (depends on enrollments)
LOAD DATA LOCAL INFILE '/your/path/data/quiz_results.csv'
INTO TABLE quiz_results
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Verify row counts after loading
SELECT 'students'     AS table_name, COUNT(*) AS row_count FROM students
UNION ALL
SELECT 'courses',      COUNT(*) FROM courses
UNION ALL
SELECT 'enrollments',  COUNT(*) FROM enrollments
UNION ALL
SELECT 'activity_logs',COUNT(*) FROM activity_logs
UNION ALL
SELECT 'quiz_results', COUNT(*) FROM quiz_results;