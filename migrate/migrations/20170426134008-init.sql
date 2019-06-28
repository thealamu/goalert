-- +migrate Up

CREATE TABLE goalert_user (
	id UUID PRIMARY KEY,
	bio TEXT,
	first_name TEXT,
	last_name TEXT,
	login TEXT UNIQUE,
	email TEXT UNIQUE,
	email_verified BOOLEAN NOT NULL default false,
	role TEXT,
	schedule_color TEXT,
	time_zone TEXT,
	title TEXT
);
-- type can be PUSH, EMAIL, VOICE, SMS
-- carrier can be ATT, VERIZON, SPRINT, TMOBILE, FI, or NULL, if set is used to send SMS via email
CREATE TABLE contact (
	id TEXT PRIMARY KEY,
  name TEXT,
	type TEXT,
	value TEXT,
  carrier TEXT,
  opt_out BOOLEAN DEFAULT false,
	user_id UUID REFERENCES goalert_user (id)
);
CREATE TABLE team (
  id TEXT PRIMARY KEY,
  description TEXT,
  name TEXT
);
CREATE TABLE team_user (
	id TEXT PRIMARY KEY,
	team_id TEXT REFERENCES team(id),
	user_id UUID REFERENCES goalert_user (id)
);
CREATE TABLE escalation_policy (
  id TEXT PRIMARY KEY,
  description TEXT,
  name TEXT,
  repeat INTEGER,
  team_id TEXT REFERENCES team(id)
);
-- urgency_rule can be HIGH, LOW, HIGH_LOW, LOW_HIGH
CREATE TABLE service (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ,
  description TEXT,
  summary TEXT,
  type TEXT,
  self TEXT,
  html_url TEXT,
  status TEXT,
  last_incident_timestamp TIMESTAMPTZ,
  conference_url TEXT,
  dialin_number TEXT,
  name TEXT,
  acknowledgement_timeout INTEGER,
  auto_resolve_timeout INTEGER,
  maintenance_mode BOOLEAN,
  escalation_policy_id TEXT REFERENCES escalation_policy(id),
  incident_urgency_type TEXT,
  incident_urgency_value TEXT
);

CREATE SEQUENCE IF NOT EXISTS incident_number_seq;
-- event_type can be TRIGGER, ACKNOWLEDGE or RESOLVE
-- URGENCY can be HIGH or LOW
CREATE TABLE incident (
	id TEXT PRIMARY KEY,
  number INTEGER DEFAULT NEXTVAL('incident_number_seq'),
  key TEXT, -- this functions as an alias for identifying external systems for dedupe purposes
  event_type TEXT,
	created_at TIMESTAMPTZ,
	description TEXT,
  details JSON,
  client TEXT,
	client_url TEXT,
	contexts JSON,
  status TEXT,
  urgency TEXT,
  resolution TEXT,
  try_count INTEGER,
  escalation_level INTEGER,
  service_id TEXT REFERENCES service(id),
  escalation_policy_id TEXT REFERENCES escalation_policy(id)
);
CREATE TABLE incident_assignment (
  id TEXT PRIMARY KEY,
  assigned_by TEXT, -- system or escalation_policy
  user_id UUID REFERENCES goalert_user(id),
  incident_id TEXT REFERENCES incident(id)
);
CREATE TABLE alert (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ,
  phone_number TEXT,
  channel TEXT,
  acknowledge_key INT,
  resolve_key INT,
  status TEXT,
  incident_ids TEXT ARRAY,
  user_id UUID REFERENCES goalert_user(id)
);
CREATE TABLE maintenance (
  id TEXT PRIMARY KEY,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  description TEXT,
  created_by UUID REFERENCES goalert_user(id)
);
CREATE TABLE service_maintenance (
  id TEXT PRIMARY KEY,
  service_id TEXT REFERENCES service(id),
  maintenance_id TEXT REFERENCES maintenance(id)
);
CREATE TABLE escalation_policy_step (
  id TEXT PRIMARY KEY,
  delay INTEGER,
  step_number INTEGER,
  escalation_policy_id TEXT REFERENCES escalation_policy(id)
);
--state can be TRIGGERED, ACKNOWLEDGED, RESOLVED
--action can be TRIGGERED, ACKNOWLEDGED, RESOLVED, ESCALATED, NOTIFIED, ASSIGNED
CREATE TABLE incident_log (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ,
  state TEXT,
  action TEXT,
  incident_id TEXT REFERENCES incident(id)
);
CREATE TABLE schedule (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ,
  description TEXT,
  name TEXT,
  time_zone INTEGER -- hours east of UTC, e.g. -6 for CST
);
CREATE TABLE schedule_layer (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ,
  effective_date TIMESTAMP,
  description TEXT,
  handoff_day INTEGER, -- day, 0 -> 6
  handoff_time TEXT, -- start time, 00:00 -> 23:30
  name TEXT,
  rotation_type TEXT, -- daily, weekly, or custom
  shift_length INTEGER, -- for custom shift length amount
  shift_length_unit TEXT, -- for custom shift length units (hours, days, weeks)
  schedule_id TEXT REFERENCES schedule(id)
);
CREATE TABLE schedule_layer_user (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ,
  step_number INTEGER, -- starts at 0
  user_id UUID REFERENCES goalert_user(id),
  schedule_layer_id TEXT REFERENCES schedule_layer(id)
);
CREATE TABLE escalation_policy_action (
	id TEXT PRIMARY KEY,
	escalation_policy_step_id TEXT REFERENCES escalation_policy_step(id),
  type_id TEXT, --user or schedule id
  type_text TEXT --can be user_reference or schedule_reference
);
CREATE TABLE integration (
  id TEXT PRIMARY KEY,
  type TEXT, -- EMAIL, API, or CUSTOM
  name TEXT, -- give it a label
  integration_key TEXT UNIQUE, -- the actual key, or email address for type EMAIL
  created_at TIMESTAMPTZ, -- auto generated by system
  service_id TEXT REFERENCES service(id)
);
CREATE TABLE notification_rule (
	id TEXT PRIMARY KEY,
	delay INTEGER,
	user_id UUID REFERENCES goalert_user (id),
  contact_id TEXT REFERENCES contact(id)
);

CREATE TABLE auth_basic_users (
  user_id UUID REFERENCES goalert_user (id) ON DELETE CASCADE PRIMARY KEY,
  username text UNIQUE NOT NULL,
  password_hash text NOT NULL
);

CREATE TABLE auth_github_users (
  user_id UUID REFERENCES goalert_user (id) ON DELETE CASCADE PRIMARY KEY,
  github_id text UNIQUE NOT NULL
);

-- +migrate Down

DROP TABLE IF EXISTS notification_rule;
DROP TABLE IF EXISTS integration;
DROP TABLE IF EXISTS escalation_policy_action;
DROP TABLE IF EXISTS schedule_layer_user;
DROP TABLE IF EXISTS schedule_layer;
DROP TABLE IF EXISTS schedule;
DROP TABLE IF EXISTS service_maintenance;
DROP TABLE IF EXISTS maintenance;
DROP TABLE IF EXISTS incident_log;
DROP TABLE IF EXISTS escalation_policy_step;
DROP TABLE IF EXISTS alert;
DROP TABLE IF EXISTS incident_assignment;
DROP TABLE IF EXISTS incident;
DROP SEQUENCE IF EXISTS incident_number_seq;
DROP TABLE IF EXISTS service;
DROP TABLE IF EXISTS escalation_policy;
DROP TABLE IF EXISTS user_role;
DROP TABLE IF EXISTS goalert_role;
DROP TABLE IF EXISTS team_user;
DROP TABLE IF EXISTS team;
DROP TABLE IF EXISTS contact;
DROP TABLE IF EXISTS auth_basic_users;
DROP TABLE IF EXISTS auth_github_users;
DROP TABLE IF EXISTS goalert_user CASCADE;
