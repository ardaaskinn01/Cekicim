-- Migration: Add 'awaiting_acceptance' to request_status enum
ALTER TYPE request_status ADD VALUE IF NOT EXISTS 'awaiting_acceptance';
