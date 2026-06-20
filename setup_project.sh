#!/bin/bash

PROJECT_NAME="sales-intelligence-platform"

echo "Creating project: $PROJECT_NAME"

mkdir -p "$PROJECT_NAME"/{data/raw,data/staging,data/processed,sql/ddl,sql/dml,sql/analytics,src/ingestion,src/transformation,src/utils,tests,dashboard,docs,configs,logs}

touch "$PROJECT_NAME"/sql/ddl/schema.sql

touch "$PROJECT_NAME"/sql/dml/{load_raw_data.sql,transform_data.sql}

touch "$PROJECT_NAME"/sql/analytics/{revenue_analysis.sql,customer_analysis.sql,product_analysis.sql,regional_analysis.sql}

touch "$PROJECT_NAME"/src/ingestion/ingest_data.py

touch "$PROJECT_NAME"/src/transformation/{clean_data.py,build_dimensions.py,build_fact_table.py}

touch "$PROJECT_NAME"/src/utils/helpers.py

touch "$PROJECT_NAME"/tests/test_data_quality.py

touch "$PROJECT_NAME"/dashboard/executive_dashboard.pbix

touch "$PROJECT_NAME"/docs/{architecture.md,data_dictionary.md,business_requirements.md}

touch "$PROJECT_NAME"/configs/config.yaml

touch "$PROJECT_NAME"/{README.md,requirements.txt,.gitignore}

echo "Done!"
echo
tree "$PROJECT_NAME" 2>/dev/null || find "$PROJECT_NAME"