-- Migration: Add 'Diğer' to problem_type enum
ALTER TYPE problem_type ADD VALUE IF NOT EXISTS 'Diğer';
