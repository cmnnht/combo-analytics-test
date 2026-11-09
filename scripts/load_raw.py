"""Charge les CSV de data/raw dans combo_project.raw (toutes colonnes en VARCHAR)."""
import csv
import os
import re
from pathlib import Path

from dotenv import load_dotenv
import snowflake.connector # connecteur pour snowflake

RAW_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"
TABLES = ["accounts", "locations", "memberships", "user_contracts", "shifts", "rests"]

DATABASE = "combo_project"
SCHEMA = "raw"

# Charge les variables du fichier .env dans l'environnement du processus
load_dotenv()


def clean(col: str) -> str:
    """Nom de colonne sûr : majuscules, caractères non alphanumériques -> _."""
    return re.sub(r"\W+", "_", col.strip()).upper()


def main() -> None:
    # Connexion à Snowflake -- définition du connecteur
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ["DBT_SNOWFLAKE_ROLE"],
        warehouse=os.environ["DBT_SNOWFLAKE_WAREHOUSE"],
        database=os.environ["DBT_SNOWFLAKE_DATABASE"],
        schema=os.environ["DBT_SRC_SNOWFLAKE_SCHEMA"],
        host=f"{os.environ['SNOWFLAKE_ACCOUNT']}.snowflakecomputing.com"
    )
    cur = conn.cursor()

    cur.execute(
        """
        CREATE OR REPLACE FILE FORMAT csv_ff
          TYPE = CSV
          SKIP_HEADER = 1
          FIELD_OPTIONALLY_ENCLOSED_BY = '"'
          NULL_IF = ('', 'NULL', 'null')
          EMPTY_FIELD_AS_NULL = TRUE
          ENCODING = 'UTF8'
        """
    )
    cur.execute("CREATE OR REPLACE STAGE raw FILE_FORMAT = csv_ff")

    for table in TABLES:
        path = RAW_DIR / f"{table}.csv"
        if not path.exists():
            raise FileNotFoundError(f"Fichier manquant : {path}")

        with path.open(newline="", encoding="utf-8-sig") as f:
            header = next(csv.reader(f))
        columns = [clean(c) for c in header]

        ddl_cols = ", ".join(f"{c} VARCHAR" for c in columns)
        cur.execute(f"CREATE OR REPLACE TABLE {table} ({ddl_cols})")

        cur.execute(
            f"PUT 'file://{path.as_posix()}' @raw/{table} "
            "AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
        )
        cur.execute(
            f"COPY INTO {table} FROM @raw/{table} "
            "ON_ERROR = ABORT_STATEMENT"
        )

        cur.execute(f"SELECT COUNT(*) FROM {table}")
        print(f"{table:<16} {cur.fetchone()[0]:>10} lignes")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()