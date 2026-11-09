-- ============================================================================
-- Paragon Anniversary: custom categories and statistics
-- 5 categories, 20 stats
--
-- WHEN TO RUN
--   After the module's numbered install SQL (01_ to 06_) has been run.
--   Do NOT run 11-13-2026_Example_Data.sql: this file makes the one table
--   change from it that is needed (type_value), without dropping any tables.
--   Run this on a fresh install, before anyone has spent paragon points:
--   it replaces all categories/stats, and stat IDs may change.
--   Safe to run more than once.
--
-- WHAT IT DOES
--   1. type_value INT -> ENUM of stat names. The numbered migrations create
--      it as INT, but the Lua scripts and the validation triggers expect
--      names such as 'HIT_MELEE', so no stat can be inserted until this runs.
--   2. icon VARCHAR(50) -> VARCHAR(64), so longer icon paths fit
--      (Interface/Icons/spell_holy_prayerofshadowprotection is 51).
--   3. Replaces all categories and stats with the layout below.
--
-- ORDER
--   Categories show top to bottom by id. Stats inside a category show
--   left to right by id (requires the sort added to the addon's
--   Paragon_Network.lua).
--
-- COLUMNS
--   factor      ignored by the current server code (each point = +1)
--   limit       max points per stat
--   application UNIT_MODS only: 0 = base value, 1 = total value
-- ============================================================================

USE `acore_ale`;

-- ----------------------------------------------------------------------------
-- 1) Table fixes (ALTER TABLE cannot be inside a transaction, so these run first)
-- ----------------------------------------------------------------------------

-- Stat names instead of numbers (same list as the author's example database)
ALTER TABLE `paragon_config_statistic`
  MODIFY `type_value` ENUM(
    'WEAPON_SKILL','DEFENSE_SKILL','DODGE','PARRY','BLOCK',
    'HIT_MELEE','HIT_RANGED','HIT_SPELL',
    'CRIT_MELEE','CRIT_RANGED','CRIT_SPELL',
    'HIT_TAKEN_MELEE','HIT_TAKEN_RANGED','HIT_TAKEN_SPELL',
    'CRIT_TAKEN_MELEE','CRIT_TAKEN_RANGED','CRIT_TAKEN_SPELL',
    'HASTE_MELEE','HASTE_RANGED','HASTE_SPELL',
    'WEAPON_SKILL_MAINHAND','WEAPON_SKILL_OFFHAND','WEAPON_SKILL_RANGED',
    'EXPERTISE','ARMOR_PENETRATION',
    'STAT_STRENGTH','STAT_AGILITY','STAT_STAMINA','STAT_INTELLECT','STAT_SPIRIT',
    'HEALTH','MANA','RAGE','FOCUS','ENERGY','HAPPINESS','RUNE','RUNIC_POWER','ARMOR',
    'RESISTANCE_HOLY','RESISTANCE_FIRE','RESISTANCE_NATURE','RESISTANCE_FROST',
    'RESISTANCE_SHADOW','RESISTANCE_ARCANE',
    'ATTACK_POWER','ATTACK_POWER_RANGED',
    'DAMAGE_MAINHAND','DAMAGE_OFFHAND','DAMAGE_RANGED',
    'LOOT','REPUTATION','EXPERIENCE','GOLD','MOVE_SPEED'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'STAT_STRENGTH';

-- Allow icon paths longer than 50 characters
ALTER TABLE `paragon_config_statistic` MODIFY `icon` VARCHAR(64) NOT NULL DEFAULT '0';

-- ----------------------------------------------------------------------------
-- 2) Layout (all or nothing: if any insert fails, nothing is changed)
-- ----------------------------------------------------------------------------
START TRANSACTION;

-- Clear the old layout so the inserts below can't create duplicates.
-- Stats first, because they reference categories (foreign key).
-- "id >= 0" matches every row; the WHERE clause keeps HeidiSQL's
-- "unsafe query" safety prompt from appearing.
DELETE FROM `paragon_config_statistic` WHERE `id` >= 0;
DELETE FROM `paragon_config_category`  WHERE `id` >= 0;

INSERT INTO `paragon_config_category` (`id`, `name`) VALUES
(1, 'Primary Stats'),
(2, 'Melee'),
(3, 'Ranged'),
(4, 'Spell'),
(5, 'Resistances');

INSERT INTO `paragon_config_statistic`
(`id`, `category`, `type`, `type_value`, `icon`, `factor`, `limit`, `application`) VALUES
-- 1: Primary Stats
( 1, 1, 'UNIT_MODS',     'STAT_STRENGTH',     'Interface/Icons/Spell_Nature_Strength',                1, 255, 0),
( 2, 1, 'UNIT_MODS',     'STAT_AGILITY',      'Interface/Icons/Ability_Rogue_Sprint',                 1, 255, 0),
( 3, 1, 'UNIT_MODS',     'STAT_STAMINA',      'Interface/Icons/Spell_Holy_WordFortitude',             1, 255, 0),
( 4, 1, 'UNIT_MODS',     'STAT_INTELLECT',    'Interface/Icons/Spell_Holy_MagicalSentry',             1, 255, 0),
( 5, 1, 'UNIT_MODS',     'STAT_SPIRIT',       'Interface/Icons/Spell_Holy_DivineSpirit',              1, 255, 0),
( 6, 1, 'UNIT_MODS',     'ARMOR',             'Interface/Icons/INV_Chest_Plate01',                    1, 255, 0),
-- 2: Melee
( 7, 2, 'COMBAT_RATING', 'HIT_MELEE',         'Interface/Icons/Ability_Warrior_Riposte',              1, 255, 0),
( 8, 2, 'COMBAT_RATING', 'CRIT_MELEE',        'Interface/Icons/Ability_CriticalStrike',               1, 255, 0),
( 9, 2, 'COMBAT_RATING', 'HASTE_MELEE',       'Interface/Icons/Spell_Nature_Bloodlust',               1, 255, 0),
-- 3: Ranged
(10, 3, 'COMBAT_RATING', 'HIT_RANGED',        'Interface/Icons/Ability_Marksmanship',                 1, 255, 0),
(11, 3, 'COMBAT_RATING', 'CRIT_RANGED',       'Interface/Icons/Ability_TrueShot',                     1, 255, 0),
(12, 3, 'COMBAT_RATING', 'HASTE_RANGED',      'Interface/Icons/Ability_Hunter_RunningShot',           1, 255, 0),
-- 4: Spell
(13, 4, 'COMBAT_RATING', 'HIT_SPELL',         'Interface/Icons/Spell_Arcane_Blast',                   1, 255, 0),
(14, 4, 'COMBAT_RATING', 'CRIT_SPELL',        'Interface/Icons/Spell_Fire_FireBolt02',                1, 255, 0),
(15, 4, 'COMBAT_RATING', 'HASTE_SPELL',       'Interface/Icons/Spell_Nature_Lightning',               1, 255, 0),
-- 5: Resistances
(16, 5, 'UNIT_MODS',     'RESISTANCE_FIRE',   'Interface/Icons/spell_fire_moltenblood',               1, 255, 0),
(17, 5, 'UNIT_MODS',     'RESISTANCE_NATURE', 'Interface/Icons/spell_nature_wispsplodegreen',         1, 255, 0),
(18, 5, 'UNIT_MODS',     'RESISTANCE_FROST',  'Interface/Icons/spell_frost_wisp',                     1, 255, 0),
(19, 5, 'UNIT_MODS',     'RESISTANCE_SHADOW', 'Interface/Icons/spell_holy_prayerofshadowprotection',  1, 255, 0),
(20, 5, 'UNIT_MODS',     'RESISTANCE_ARCANE', 'Interface/Icons/spell_nature_wispsplode',              1, 255, 0);

COMMIT;

-- ----------------------------------------------------------------------------
-- 3) Check: should list 20 stats across 5 categories
-- ----------------------------------------------------------------------------
SELECT c.`id` AS cat, c.`name`, s.`id` AS stat, s.`type`, s.`type_value`, s.`icon`
FROM `paragon_config_statistic` s
JOIN `paragon_config_category` c ON c.`id` = s.`category`
ORDER BY c.`id`, s.`id`;
