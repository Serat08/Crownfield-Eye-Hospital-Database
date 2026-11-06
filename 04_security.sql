USE crownfield_eye;

-- Transaction demo 1: a prescription and its item belong together. The item fails, so everything is rolled back.

START TRANSACTION;
INSERT INTO prescriptions (PrescriptionID, AppointmentID) VALUES ('RX099', 'A021');
INSERT INTO prescriptionitems (PrescriptionID, ItemNumber, MedicineID, Dose, Route, Frequency, Duration)
VALUES ('RX099', 1, 'M999', '1 drop', 'Eye drops', 'Once daily', '28 days');
ROLLBACK;
SELECT COUNT(*) AS PrescriptionRowsAfterRollback FROM prescriptions WHERE PrescriptionID = 'RX099';

-- Transaction demo 2: prescribe a medicine and book its follow-up as one unit, then COMMIT.

START TRANSACTION;
INSERT INTO prescriptions (PrescriptionID, AppointmentID) VALUES ('RX099', 'A021');
INSERT INTO prescriptionitems (PrescriptionID, ItemNumber, MedicineID, Dose, Route, Frequency, Duration)
VALUES ('RX099', 1, 'M001', '1 drop', 'Eye drops', 'Once daily', '28 days');
INSERT INTO followupplans (FollowUpID, AppointmentID, DueDate, Priority)
VALUES ('F099', 'A021', '2027-01-18', 'Routine');
COMMIT;
SELECT (SELECT COUNT(*) FROM prescriptions WHERE PrescriptionID = 'RX099') AS Prescriptions,
       (SELECT COUNT(*) FROM prescriptionitems WHERE PrescriptionID = 'RX099') AS Items,
       (SELECT COUNT(*) FROM followupplans WHERE FollowUpID = 'F099') AS FollowUps;
       
       
-- Clean-up: remove the demo rows so the data is back to its original state (the item goes with its prescription by CASCADE).
DELETE FROM followupplans WHERE FollowUpID = 'F099';
DELETE FROM prescriptions WHERE PrescriptionID = 'RX099';

-- Part D1: four roles, least privilege (the Patient role and its views come next)
CREATE ROLE IF NOT EXISTS 'crown_admin', 'crown_doctor', 'crown_receptionist', 'crown_patient';

-- Administrator: everything, including DELETE
GRANT ALL PRIVILEGES ON crownfield_eye.* TO 'crown_admin';

-- Doctor: read patients and appointments; read and write clinical data and follow-ups
GRANT SELECT ON crownfield_eye.patients TO 'crown_doctor';
GRANT SELECT ON crownfield_eye.appointments TO 'crown_doctor';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.diagnoses TO 'crown_doctor';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.appointmentdiagnoses TO 'crown_doctor';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.prescriptions TO 'crown_doctor';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.prescriptionitems TO 'crown_doctor';
GRANT SELECT ON crownfield_eye.medicines TO 'crown_doctor';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.followupplans TO 'crown_doctor';

-- Receptionist: manage patients, appointments and follow-ups; no access to clinical data
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.patients TO 'crown_receptionist';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.appointments TO 'crown_receptionist';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.followupplans TO 'crown_receptionist';

-- Doctor and Receptionist can look up reference data
GRANT SELECT ON crownfield_eye.clinicians TO 'crown_doctor', 'crown_receptionist';
GRANT SELECT ON crownfield_eye.clinics TO 'crown_doctor', 'crown_receptionist';
GRANT SELECT ON crownfield_eye.specialties TO 'crown_doctor', 'crown_receptionist';

SHOW GRANTS FOR 'crown_doctor';

-- Part D1 (continued): the Patient role sees only its own rows, through views.
-- A patient logs in with the lower-case patient ID as the user name (for example op001), and USER() returns that name.
CREATE OR REPLACE VIEW v_my_patient AS
SELECT PatientID, PatientName, Postcode
FROM patients
WHERE LOWER(PatientID) = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW v_my_appointments AS
SELECT AppointmentID, ClinicianID, ClinicID, AppointmentDate, AppointmentTime
FROM appointments
WHERE LOWER(PatientID) = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW v_my_diagnoses AS
SELECT appointments.AppointmentID, diagnoses.DiagnosisName
FROM appointments
JOIN appointmentdiagnoses ON appointmentdiagnoses.AppointmentID = appointments.AppointmentID
JOIN diagnoses ON diagnoses.DiagnosisID = appointmentdiagnoses.DiagnosisID
WHERE LOWER(appointments.PatientID) = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW v_my_prescriptions AS
SELECT appointments.AppointmentID, prescriptions.PrescriptionID, medicines.MedicineName,
       prescriptionitems.Dose, prescriptionitems.Route, prescriptionitems.Frequency, prescriptionitems.Duration
FROM appointments
JOIN prescriptions ON prescriptions.AppointmentID = appointments.AppointmentID
JOIN prescriptionitems ON prescriptionitems.PrescriptionID = prescriptions.PrescriptionID
JOIN medicines ON medicines.MedicineID = prescriptionitems.MedicineID
WHERE LOWER(appointments.PatientID) = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW v_my_followups AS
SELECT appointments.AppointmentID, followupplans.DueDate, followupplans.Priority, followupplans.FollowUpStatus
FROM appointments
JOIN followupplans ON followupplans.AppointmentID = appointments.AppointmentID
WHERE LOWER(appointments.PatientID) = SUBSTRING_INDEX(USER(), '@', 1);

GRANT SELECT ON crownfield_eye.v_my_patient TO 'crown_patient';
GRANT SELECT ON crownfield_eye.v_my_appointments TO 'crown_patient';
GRANT SELECT ON crownfield_eye.v_my_diagnoses TO 'crown_patient';
GRANT SELECT ON crownfield_eye.v_my_prescriptions TO 'crown_patient';
GRANT SELECT ON crownfield_eye.v_my_followups TO 'crown_patient';

SHOW GRANTS FOR 'crown_patient';


-- Part D1 (continued): one demo account per role. Demo passwords for the fictional scenario only.
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'Admin#Demo2026';
CREATE USER IF NOT EXISTS 'dr_shah'@'localhost' IDENTIFIED BY 'Doctor#Demo2026';
CREATE USER IF NOT EXISTS 'recep_ann'@'localhost' IDENTIFIED BY 'Recep#Demo2026';
CREATE USER IF NOT EXISTS 'op001'@'localhost' IDENTIFIED BY 'Patient#Demo2026';

GRANT 'crown_admin' TO 'admin_user'@'localhost';
GRANT 'crown_doctor' TO 'dr_shah'@'localhost';
GRANT 'crown_receptionist' TO 'recep_ann'@'localhost';
GRANT 'crown_patient' TO 'op001'@'localhost';

SET DEFAULT ROLE ALL TO 'admin_user'@'localhost', 'dr_shah'@'localhost', 'recep_ann'@'localhost', 'op001'@'localhost';

SHOW GRANTS FOR 'dr_shah'@'localhost' USING 'crown_doctor';


-- Part D2: data protection. Passwords are stored as SHA-256 hashes, never as plain text.
-- Run the ALTER once: on a re-run MySQL answers error 1060 (duplicate column), which is harmless.
ALTER TABLE patients ADD COLUMN PasswordHash CHAR(64) NULL;

-- Demo passwords for the fictional scenario only
UPDATE patients SET PasswordHash = SHA2('Amina#Demo2026', 256) WHERE PatientID = 'OP001';
UPDATE patients SET PasswordHash = SHA2('Daniel#Demo2026', 256) WHERE PatientID = 'OP002';

-- What is stored: a 64-character hash, not the password
SELECT PatientID, PatientName, PasswordHash FROM patients WHERE PasswordHash IS NOT NULL;

-- Login check: hash what the user typed and compare it with the stored hash (1 = match, 0 = no match)
SELECT COUNT(*) AS LoginRight FROM patients WHERE PatientID = 'OP001' AND PasswordHash = SHA2('Amina#Demo2026', 256);
SELECT COUNT(*) AS LoginWrong FROM patients WHERE PatientID = 'OP001' AND PasswordHash = SHA2('wrong-password', 256);


-- Part D2 (extra credit): SQL injection and a secure alternative
-- UNSAFE: the input is glued into the query text, so ' OR '1'='1 makes the WHERE clause always true
SET @unsafe_input = "x' OR '1'='1";
SET @unsafe_sql = CONCAT("SELECT PatientID, PatientName FROM patients WHERE PatientName = '", @unsafe_input, "'");
PREPARE unsafe_stmt FROM @unsafe_sql;
EXECUTE unsafe_stmt;
DEALLOCATE PREPARE unsafe_stmt;

-- SECURE: a prepared statement with a ? placeholder, so the input is treated as data only
SET @safe_input = "x' OR '1'='1";
PREPARE safe_stmt FROM 'SELECT PatientID, PatientName FROM patients WHERE PatientName = ?';
EXECUTE safe_stmt USING @safe_input;
DEALLOCATE PREPARE safe_stmt;
       