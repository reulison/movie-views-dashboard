-- View 1: User KPIs (perfil do usuário + métricas)
CREATE OR REPLACE VIEW vw_user_kpi AS
SELECT
    u.user_id,
    u.full_name,
    u.email,
    u.gender,
    u.age,
    u.country,
    u.city,
    COUNT(DISTINCT fv.view_id)::INT AS total_movies_watched,
    COUNT(DISTINCT fv.movie_id)::INT AS unique_movies_count,
    COALESCE(ROUND(AVG(fv.duration_minutes), 2), 0) AS avg_viewing_time_minutes,
    COALESCE(ROUND(SUM(fv.duration_minutes), 2), 0) AS total_viewing_time_minutes,
    COALESCE(ROUND(AVG(fv.watch_progress), 2), 0) AS avg_watch_progress_pct,
    COUNT(DISTINCT CASE WHEN fv.liked THEN fv.movie_id END)::INT AS liked_movies_count,
    COUNT(DISTINCT DATE(fv.date))::INT AS active_days,
    MAX(fv.date) AS last_view_date,
    MIN(fv.date) AS first_view_date
FROM dim_users u
LEFT JOIN fact_views fv ON u.user_id = fv.user_id
GROUP BY u.user_id, u.full_name, u.email, u.gender, u.age, u.country, u.city;

-- View 2: Visualização por gênero de filme
CREATE OR REPLACE VIEW vw_genre_analysis AS
SELECT
    u.user_id,
    u.full_name,
    TRIM(genre) AS genre,
    COUNT(DISTINCT fv.view_id)::INT AS views_count,
    COUNT(DISTINCT fv.movie_id)::INT AS movies_count,
    COALESCE(ROUND(AVG(fv.duration_minutes), 2), 0) AS avg_viewing_time_minutes,
    COALESCE(ROUND(SUM(fv.duration_minutes), 2), 0) AS total_viewing_time_minutes
FROM dim_users u
JOIN fact_views fv ON u.user_id = fv.user_id
JOIN dim_movies m ON fv.movie_id = m.movie_id
CROSS JOIN LATERAL unnest(string_to_array(m.genres, ',')) AS genre
GROUP BY u.user_id, u.full_name, TRIM(genre);

-- View 3: Visualizações diárias (tendência)
CREATE OR REPLACE VIEW vw_daily_views AS
SELECT
    date,
    COUNT(DISTINCT view_id)::INT AS total_views,
    COUNT(DISTINCT user_id)::INT AS unique_users,
    COUNT(DISTINCT movie_id)::INT AS unique_movies,
    COALESCE(ROUND(AVG(duration_minutes), 2), 0) AS avg_duration_minutes,
    COALESCE(ROUND(SUM(duration_minutes), 2), 0) AS total_duration_minutes
FROM fact_views
GROUP BY date
ORDER BY date;

-- View 4: Análise por dispositivo / plataforma
CREATE OR REPLACE VIEW vw_device_analysis AS
SELECT
    device,
    platform,
    browser,
    COUNT(DISTINCT view_id)::INT AS views_count,
    COUNT(DISTINCT user_id)::INT AS unique_users,
    COALESCE(ROUND(AVG(duration_minutes), 2), 0) AS avg_duration_minutes,
    COALESCE(ROUND(SUM(duration_minutes), 2), 0) AS total_duration_minutes
FROM fact_views
GROUP BY device, platform, browser;

-- View 5: Popularidade dos filmes
CREATE OR REPLACE VIEW vw_movie_popularity AS
SELECT
    m.movie_id,
    m.title,
    m.release_year,
    m.genres,
    m.director,
    m.imdb_rating,
    COUNT(DISTINCT fv.view_id)::INT AS total_views,
    COUNT(DISTINCT fv.user_id)::INT AS unique_viewers,
    COALESCE(ROUND(AVG(fv.duration_minutes), 2), 0) AS avg_viewing_time_minutes,
    COALESCE(ROUND(AVG(fv.watch_progress), 2), 0) AS avg_watch_progress,
    COUNT(DISTINCT CASE WHEN fv.liked THEN fv.user_id END)::INT AS likes_count
FROM dim_movies m
LEFT JOIN fact_views fv ON m.movie_id = fv.movie_id
GROUP BY m.movie_id, m.title, m.release_year, m.genres, m.director, m.imdb_rating;

-- View 6: Sessões por usuário
CREATE OR REPLACE VIEW vw_user_sessions AS
SELECT
    u.user_id,
    u.full_name,
    fv.session_id,
    MIN(fv.timestamp) AS session_start,
    MAX(fv.timestamp) AS session_end,
    COUNT(DISTINCT fv.view_id)::INT AS views_in_session,
    COUNT(DISTINCT fv.movie_id)::INT AS movies_in_session,
    ROUND(SUM(fv.duration_minutes)::numeric, 2) AS session_duration_minutes
FROM dim_users u
JOIN fact_views fv ON u.user_id = fv.user_id
GROUP BY u.user_id, u.full_name, fv.session_id;
