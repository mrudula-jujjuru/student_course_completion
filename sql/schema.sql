-- ============================================================
-- FILE: schema.sql
-- PROJECT: Student Course Completion Prediction
-- DESCRIPTION: Creates the database and all 5 tables
-- AUTHOR: Your Name
-- DATE: April 2026
-- ============================================================

CREATE DATABASE IF NOT EXISTS student_completion;
USE student_completion;

-- Stores student demographic information
CREATE TABLE students (
    student_id      INT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    age             INT,
    gender          ENUM('Male','Female','Other'),
    location        VARCHAR(100),
    employment      ENUM('Employed','Unemployed','Student'),
    education_level ENUM('High School','Bachelor','Master','PhD','Other'),
    enrolled_at     DATE NOT NULL
);

-- Stores course catalog information
CREATE TABLE courses (
    course_id       INT PRIMARY KEY,
    title           VARCHAR(150) NOT NULL,
    category        VARCHAR(100),
    difficulty      ENUM('Beginner','Intermediate','Advanced'),
    duration_weeks  INT,
    total_lessons   INT,
    has_certificate TINYINT DEFAULT 1
);

-- Links students to courses with completion tracking
CREATE TABLE enrollments (
    enrollment_id   INT PRIMARY KEY,
    student_id      INT,
    course_id       INT,
    enrolled_date   DATE NOT NULL,
    completion_date DATE,
    status          VARCHAR(20),
    completion_pct  DECIMAL(5,1) DEFAULT 0,
    final_score     DECIMAL(5,1),
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id)  REFERENCES courses(course_id)
);

-- Weekly activity tracking per enrollment
CREATE TABLE activity_logs (
    log_id          INT PRIMARY KEY,
    enrollment_id   INT,
    week_number     INT,
    videos_watched  INT DEFAULT 0,
    quizzes_taken   INT DEFAULT 0,
    quiz_avg_score  DECIMAL(5,1),
    forum_posts     INT DEFAULT 0,
    hours_spent     DECIMAL(5,1) DEFAULT 0,
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id)
);

-- Individual quiz attempt records
CREATE TABLE quiz_results (
    quiz_id         INT PRIMARY KEY,
    enrollment_id   INT,
    quiz_name       VARCHAR(100),
    score           DECIMAL(5,1),
    taken_at        DATE,
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id)
);