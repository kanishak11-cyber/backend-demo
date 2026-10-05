CREATE TABLE users (
    id         integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       text        NOT NULL,
    email      text        NOT NULL UNIQUE,
    age        integer     NOT NULL CHECK (age BETWEEN 18 AND 90),
    city       text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
