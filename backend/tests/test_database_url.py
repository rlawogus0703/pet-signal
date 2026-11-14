from app.config import normalize_database_url, redact_secrets


def test_normalize_postgres_schemes():
    assert normalize_database_url("postgres://u:p@h/db") == "postgresql+psycopg://u:p@h/db"
    assert normalize_database_url("postgresql://u:p@h/db") == "postgresql+psycopg://u:p@h/db"
    assert (
        normalize_database_url("postgresql+psycopg://u:p@h/db?sslmode=require")
        == "postgresql+psycopg://u:p@h/db?sslmode=require"
    )


def test_normalize_scheme_less_and_sqlite():
    assert normalize_database_url("u:p@ep-test.example.tech/db?sslmode=require") == (
        "postgresql+psycopg://u:p@ep-test.example.tech/db?sslmode=require"
    )
    assert normalize_database_url("") == "sqlite:///./petsignal.db"
    assert normalize_database_url("sqlite:///./petsignal.db") == "sqlite:///./petsignal.db"


def test_redact_secrets():
    raw = "postgresql+psycopg://neondb_owner:super-secret@ep-test.example.tech/db"
    out = redact_secrets(raw, "abcd1234key")
    assert "super-secret" not in out
    assert "***:***@" in out
    assert "abcd1234key" not in redact_secrets("error abcd1234key oops", "abcd1234key")
