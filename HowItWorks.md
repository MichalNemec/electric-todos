how to connect to prod db for migrations:
https://github.com/amacneil/dbmate?tab=readme-ov-file#connecting-to-the-database

when prod db changes do here:
dbmate --migrations-dir migrations new <migration_name>

then to have drift files:
dart run electricsql_cli generate
