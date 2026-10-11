#!/bin/bash
# Stop at the first failed load instead of reporting success.
set -euo pipefail

# Wait until PostgreSQL is ready
until pg_isready -h db -U admin; do
  echo "Waiting for database connection..."
  sleep 2
done

# Load each CSV file into its corresponding table.
# TRUNCATE + COPY in one transaction makes the load repeatable: the data_loader container runs
# again whenever the stack is started again, and must replace the data, not append it.
for file in /raw_data/*.csv; do
  table_name=$(basename "$file" .csv)
  echo "Loading data from $file into table $table_name..."
  psql -h db -U admin -d postgres -v ON_ERROR_STOP=1 --single-transaction \
    -c "TRUNCATE $table_name;" \
    -c "\COPY $table_name FROM '$file' DELIMITER ',' CSV HEADER;"
done

echo "Data loading completed."
