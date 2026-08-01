-- Migration 002: Add emoji and default columns to notebooks
ALTER TABLE notebooks ADD COLUMN emoji TEXT DEFAULT '📓';
ALTER TABLE notebooks ADD COLUMN "default" INTEGER DEFAULT 0;
