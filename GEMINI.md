# Project Overview

This project contains a PostgreSQL event trigger designed for Supabase projects. Its primary purpose is to automatically enable Row Level Security (RLS) with the `FORCE` option on all newly-created tables within the `public` schema. This serves as a security enhancement to prevent accidental data exposure, which can happen if a developer forgets to manually enable RLS on a new table.

The core logic is implemented in a PostgreSQL function that is executed by an event trigger after a `CREATE TABLE`, `CREATE TABLE AS`, or `SELECT INTO` command.

## Building and Running

The project is managed using the Supabase CLI.

### Local Development

1.  **Start Supabase:**
    ```bash
    supabase start
    ```

2.  **Apply Migrations:**
    ```bash
    supabase db reset
    ```

3.  **Run Tests:**
    ```bash
    supabase test db
    ```

### Deploy to Hosted Project

1.  **Link to your project:**
    ```bash
    supabase link --project-ref <your-project-ref>
    ```

2.  **Push migration:**
    ```bash
    supabase db push
    ```

## Development Conventions

*   **Database Migrations:** All database schema changes are managed through migration files in the `supabase/migrations` directory.
*   **Testing:** The project uses `pgTAP` for testing. Tests are located in the `supabase/tests` directory and can be run using the `supabase test db` command. The test suite is comprehensive, covering a wide range of scenarios to ensure the trigger works as expected.
