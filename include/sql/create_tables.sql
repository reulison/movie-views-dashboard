-- Dimension: Users
CREATE TABLE IF NOT EXISTS dim_users (
    user_id VARCHAR(100) PRIMARY KEY,
    full_name VARCHAR(200),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(200),
    gender VARCHAR(20),
    age INT,
    country VARCHAR(100),
    city VARCHAR(200),
    registered_date DATE,
    phone VARCHAR(50),
    cell VARCHAR(50),
    nationality VARCHAR(10),
    picture_url VARCHAR(500)
);

-- Backward-compatible schema fix for environments where dim_users
-- already existed before picture_url was introduced.
ALTER TABLE dim_users
ADD COLUMN IF NOT EXISTS picture_url VARCHAR(500);

-- Dimension: Movies
CREATE TABLE IF NOT EXISTS dim_movies (
    movie_id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(500),
    content_type VARCHAR(50),
    release_year INT,
    genres TEXT,
    director VARCHAR(200),
    country VARCHAR(100),
    language VARCHAR(100),
    imdb_rating NUMERIC(3,1),
    cast_text TEXT,
    synopsis TEXT
);

-- Fact: Views
CREATE TABLE IF NOT EXISTS fact_views (
    view_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(100) REFERENCES dim_users(user_id),
    movie_id VARCHAR(50) REFERENCES dim_movies(movie_id),
    timestamp TIMESTAMP,
    date DATE,
    time TIME,
    duration_seconds INT,
    duration_minutes NUMERIC(10,2),
    view_type VARCHAR(20),
    device VARCHAR(50),
    browser VARCHAR(50),
    platform VARCHAR(50),
    liked BOOLEAN,
    rating INT,
    wishlist_added BOOLEAN,
    favorite_added BOOLEAN,
    shared BOOLEAN,
    session_id VARCHAR(100),
    ip_address VARCHAR(50),
    referrer VARCHAR(500),
    watch_progress INT,
    quality VARCHAR(10),
    buffering_events INT,
    seeks_forward INT,
    seeks_backward INT
);
