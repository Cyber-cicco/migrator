# Database Migration Tool

A simple PostgreSQL database migration system for managing schema changes across development and production environments.

## Features

- Create new migrations from SQL statements
- Merge pending migrations into versioned files
- Execute migrations between specific versions
- Seamless integration with version control
- Support for multiple database environments

## Usage

### Environment Variables

Set these environment variables for database connection:

```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=yourdb
DB_USER=youruser
DB_PASSWORD=yourpassword
TEST_DB_NAME=yourtestdb
```

### Creating Migrations

```bash
# Create a migration from migration.sql file
./migration.create.sh

# Create a migration directly from command line
./migration.create.sh "ALTER TABLE users ADD COLUMN email VARCHAR(255);"
```

### Merging Pending Migrations

```bash
# Merge all pending migrations into a versioned migration file
./migration.merge.sh

# Merge and clean up pending migrations directory
./migration.merge.sh --clean
```

### Executing Migrations

```bash
# Execute all migrations
./migration.exec.sh

# Execute migrations between specific versions
./migration.exec.sh 0001 0003

# Execute migrations between commit hashes
./migration.exec.sh f7ea55d 2b63530
```

### Database Creation

```bash
# Create database from all SQL files in creation_bdd directory
./creation.sh
```

## License

See [LICENSE](LICENSE) file for details.
