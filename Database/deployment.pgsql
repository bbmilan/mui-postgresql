-- Create a new schema
CREATE SCHEMA IF NOT EXISTS todoschema;

-- Create the Todo table within the schema
CREATE TABLE IF NOT EXISTS todoschema."Todo" (
    Id BIGSERIAL PRIMARY KEY,
    Name VARCHAR(255),
    IsComplete BOOLEAN
);

-- Insert sample data into the Todo table
INSERT INTO todoschema."Todo" (Name, IsComplete)
VALUES 
    ('Learn SQL', true),
    ('Build a Blazor app', false),
    ('Write documentation', true),
    ('Test application', false);
