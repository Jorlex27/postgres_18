-- Create databases for JAM Auth application
-- This script runs automatically when the container is first created

-- Create development database
CREATE DATABASE jam_auth_dev
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Create test database
CREATE DATABASE jam_auth_test
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Create production database
CREATE DATABASE jam_auth_prod
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Grant all privileges to postgres user (default user)
GRANT ALL PRIVILEGES ON DATABASE jam_auth_dev TO postgres;
GRANT ALL PRIVILEGES ON DATABASE jam_auth_test TO postgres;
GRANT ALL PRIVILEGES ON DATABASE jam_auth_prod TO postgres;

-- Print confirmation
\echo 'Successfully created jam_auth_dev, jam_auth_test, and jam_auth_prod databases'
