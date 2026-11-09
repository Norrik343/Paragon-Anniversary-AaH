-- ============================================================================
-- Paragon Anniversary: Azeroth at Home config settings
--
-- Sets all 17 paragon_config values. Safe to run more than once: each row is
-- inserted, or updated if it already exists.
--
-- WHEN TO RUN
--   After the module's numbered install SQL (01_ to 06_).
--   The server reads paragon_config at startup: run this with the worldserver
--   stopped, or restart it afterwards.
--
-- NOTES
--   - UNIVERSAL_ACHIEVEVEMENT_EXPERIENCE is spelled this way in the module's
--     code, so the misspelling is intentional.
--   - Experience multipliers are effectively off: LOW_LEVEL_THRESHOLD 0 means
--     no level is below it, HIGH_LEVEL_THRESHOLD 1000 equals the level cap so
--     no level is above it, and both multipliers are 1.
--   - Level L -> L+1 takes BASE_MAX_EXPERIENCE x L (400 x L).
--     Level 1 -> 1000 = 199,800,000 experience (~4 million creature kills).
--   - DEFAULT_STAT_LIMIT is not used by the current code; each statistic's
--     own `limit` column applies (see paragon_stats_setup.sql).
--   - Lowering POINTS_PER_LEVEL later requires resetting spent points
--     (character_paragon_stats).
-- ============================================================================

INSERT INTO `acore_ale`.`paragon_config` (`field`, `value`) VALUES
-- System
('ENABLE_PARAGON_SYSTEM',              '1'),
('LEVEL_LINKED_TO_ACCOUNT',            '0'),     -- 0 = per character
('MINIMUM_LEVEL_FOR_PARAGON_XP',       '80'),    -- below 80: achievement claim only

-- Levels and points
('PARAGON_STARTING_LEVEL',             '1'),
('PARAGON_STARTING_EXPERIENCE',        '0'),
('PARAGON_LEVEL_CAP',                  '1000'),
('BASE_MAX_EXPERIENCE',                '400'),
('POINTS_PER_LEVEL',                   '1'),
('DEFAULT_STAT_LIMIT',                 '255'),

-- Experience per source
('UNIVERSAL_CREATURE_EXPERIENCE',      '50'),
('UNIVERSAL_QUEST_EXPERIENCE',         '75'),
('UNIVERSAL_ACHIEVEVEMENT_EXPERIENCE', '100'),
('UNIVERSAL_SKILL_EXPERIENCE',         '25'),

-- Experience multipliers (effectively off)
('LOW_LEVEL_THRESHOLD',                '0'),
('EXPERIENCE_MULTIPLIER_LOW_LEVEL',    '1'),
('HIGH_LEVEL_THRESHOLD',               '1000'),
('EXPERIENCE_MULTIPLIER_HIGH_LEVEL',   '1')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);

-- Check: should list 17 rows with the values above
SELECT `field`, `value` FROM `acore_ale`.`paragon_config` ORDER BY `field`;
