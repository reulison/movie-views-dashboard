import json
from pathlib import Path

from airflow.sdk import DAG, dag, task
from airflow.providers.postgres.hooks.postgres import PostgresHook
from pendulum import datetime

DATA_DIR = Path(__file__).resolve().parents[1] / "include" / "data"
SQL_DIR = Path(__file__).resolve().parents[1] / "include" / "sql"
PG_CONN_ID = "postgres_default"

default_args = {"owner": "Astro", "retries": 2}


def _get_pg_hook() -> PostgresHook:
    return PostgresHook(postgres_conn_id=PG_CONN_ID)


def _run_sql_file(filename: str):
    path = SQL_DIR / filename
    sql = path.read_text(encoding="utf-8")
    hook = _get_pg_hook()
    hook.run(sql)


@dag(
    start_date=datetime(2025, 7, 1),
    schedule=None,
    catchup=False,
    default_args=default_args,
    tags=["etl", "movies", "dashboard"],
)
def movie_views_etl():

    @task
    def create_tables():
        _run_sql_file("create_tables.sql")
        print("Tables created / verified successfully.")

    @task
    def load_users():
        path = DATA_DIR / "users.json"
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)

        rows = []
        for u in raw["results"]:
            rows.append((
                u["login"]["uuid"],
                f"{u['name']['first']} {u['name']['last']}",
                u["name"]["first"],
                u["name"]["last"],
                u.get("email"),
                u.get("gender"),
                u.get("dob", {}).get("age"),
                u.get("location", {}).get("country"),
                u.get("location", {}).get("city"),
                u.get("registered", {}).get("date", "")[:10] if u.get("registered") else None,
                u.get("phone"),
                u.get("cell"),
                u.get("nat"),
                u.get("picture", {}).get("large"),
            ))

        hook = _get_pg_hook()
        conn = hook.get_conn()
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE dim_users CASCADE")
            conn.commit()

        hook.insert_rows(
            table="dim_users",
            rows=rows,
            target_fields=[
                "user_id", "full_name", "first_name", "last_name",
                "email", "gender", "age", "country", "city",
                "registered_date", "phone", "cell", "nationality", "picture_url",
            ],
            replace=False,
        )
        print(f"Loaded {len(rows)} users.")

    @task
    def load_movies():
        path = DATA_DIR / "movie_catalog.json"
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)

        rows = []
        for m in raw:
            genres = ", ".join(m.get("genres", []))
            cast_text = ", ".join(m.get("cast", []))
            rows.append((
                m["id"],
                m.get("title"),
                m.get("content_type"),
                m.get("release_year"),
                genres,
                m.get("director"),
                m.get("country"),
                m.get("language"),
                m.get("imdb_rating"),
                cast_text,
                m.get("synopsis"),
            ))

        hook = _get_pg_hook()
        conn = hook.get_conn()
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE dim_movies CASCADE")
            conn.commit()

        hook.insert_rows(
            table="dim_movies",
            rows=rows,
            target_fields=[
                "movie_id", "title", "content_type", "release_year",
                "genres", "director", "country", "language",
                "imdb_rating", "cast_text", "synopsis",
            ],
            replace=False,
        )
        print(f"Loaded {len(rows)} movies.")

    @task
    def load_views():
        path = DATA_DIR / "views.json"
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)

        rows = []
        for v in raw["views"]:
            u = v["user"]
            m = v["movie"]
            vd = v["view_details"]
            ia = v["interaction"]
            sess = v.get("session", {})
            metrics = v.get("metrics", {})

            rows.append((
                v["view_id"],
                u["uuid"],
                m["id"],
                vd.get("timestamp"),
                vd.get("date"),
                vd.get("time"),
                vd.get("duration_seconds"),
                vd.get("duration_minutes"),
                vd.get("view_type"),
                vd.get("device"),
                vd.get("browser"),
                vd.get("platform"),
                ia.get("liked"),
                ia.get("rating"),
                ia.get("wishlist_added"),
                ia.get("favorite_added"),
                ia.get("shared"),
                sess.get("session_id"),
                sess.get("ip_address"),
                sess.get("referrer"),
                metrics.get("watch_progress"),
                metrics.get("quality"),
                metrics.get("buffering_events"),
                metrics.get("seeks_forward"),
                metrics.get("seeks_backward"),
            ))

        hook = _get_pg_hook()
        conn = hook.get_conn()
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE fact_views")
            conn.commit()

        hook.insert_rows(
            table="fact_views",
            rows=rows,
            target_fields=[
                "view_id", "user_id", "movie_id",
                "timestamp", "date", "time",
                "duration_seconds", "duration_minutes",
                "view_type", "device", "browser", "platform",
                "liked", "rating", "wishlist_added",
                "favorite_added", "shared",
                "session_id", "ip_address", "referrer",
                "watch_progress", "quality",
                "buffering_events", "seeks_forward", "seeks_backward",
            ],
            replace=False,
        )
        print(f"Loaded {len(rows)} views.")

    @task
    def create_analytics_views():
        _run_sql_file("create_views.sql")
        print("Analytics views created / refreshed successfully.")

    tables_created = create_tables()
    users_loaded = tables_created >> load_users()
    movies_loaded = tables_created >> load_movies()
    views_loaded = [users_loaded, movies_loaded] >> load_views()
    [users_loaded, movies_loaded, views_loaded] >> create_analytics_views()


movie_views_etl()
