# Crownfield Eye Hospital: relational database

**Module:** CPU4:103 Introduction to Database (Global Banking School)
**Student:** Serat Choudhury, G1411615
**Group:** Daniel Camargo Moreira (G1418730), Natalin Tek Ozler (G1438117)
**Assessment:** summative database build, fictional Flytech Ltd scenario for Crownfield Eye Hospital

## What this repository contains

My individual MySQL implementation of the group's ER diagram (11 tables in 3NF), with data,
integrity tests, six SQL queries (including a stored procedure and a trigger) and a security model.
The ER diagram is the group's shared artefact. The implementation, constraints, tests and SQL
features in this repository are my own work.

## Requirements

- MySQL 8.0.16 or later (CHECK constraints are enforced from 8.0.16). Developed on MySQL 8.4.
- MySQL Workbench, or the `mysql` command-line client.
- An account that can create databases (for example `root`). `04_security.sql` also creates users and roles.

## Setup and execution order

Run the files in this order, on an empty server or one where dropping `crownfield_eye` is acceptable.

| Order | File | What it does |
|---|---|---|
| 1 | `01_schema.sql` | Drops and recreates `crownfield_eye`, creates the 11 tables, loads the data, and ends with a row-count check |
| 2 | `01b_integrity_tests.sql` | Test log: 13 integrity tests. Run each `TEST` block on its own; tests marked `EXPECT: error` fail on purpose |
| 3 | `02_individual_queries.sql` | Four Part C queries: GROUP BY with HAVING, 3-table INNER JOIN, LEFT JOIN (appointments with no follow-up) and a subquery. Each is preceded by the question it answers |
| 4 | `03_procedure_and_trigger.sql` | Stored procedure `sp_clinician_appointments` (input parameter) and trigger `trg_followup_due_after_appt`. One statement fails on purpose (trigger test 1, error 1644) |
| 5 | `04_security.sql` | Transaction demos (COMMIT and ROLLBACK), four roles with privileges, demo users, patient views, SHA-256 hashed password column, SQL injection example with a prepared statement. Expected errors: 1452 in transaction demo 1 (on purpose); 1060 if the `ALTER TABLE` is run a second time (harmless) |
| - | `05_ERD` | The group ER diagram (original file) |

In Workbench: **File > Open SQL Script**, then select the part you want and click **Execute** (the first lightning bolt). Run `01_schema.sql` once and in full; for the other files you can run the whole file or one block at a time.
From a terminal: `mysql -u root -p < 01_schema.sql`, then the same for each file in order.

## Assumptions

- One source row in Appendix 1 is one appointment (Appendix 1 has no appointment ID).
- "None" in Appendix 1 means no prescription; other medicines on a row form one prescription.
- A follow-up is a due date and a priority; its status defaults to `Pending`.
- A name is one attribute (as in the group ER diagram), because Appendix 1 gives full names only.
- Dose, route, frequency and duration are synthetic additions. Rows marked `(App1)` in `01_schema.sql` come from Appendix 1; all other rows are synthetic.
- Table names are lowercase because they are case-sensitive on Linux servers.

## My contribution

Schema implementation with extra constraints, the 13-test integrity log, my four queries plus the stored procedure and the trigger, and the security work (roles, hashing, secure coding, transactions). Group work: scope, dataset analysis and the ER diagram.

## AI-use declaration

I used an AI assistant (Claude, Anthropic) during this project. It explained concepts, reviewed my work against the brief and rubric, suggested SQL for the queries, procedure, trigger, security and transaction scripts, and helped draft the slides, speaker notes and report text from my own results. I typed or pasted, ran and tested every script in MySQL Workbench myself, and the screenshots and results are my own. I have checked everything in this repository and can explain every part of it.
