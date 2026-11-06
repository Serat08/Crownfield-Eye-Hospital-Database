
USE crownfield_eye;

-- TEST 1: duplicate primary key is rejected
-- EXPECT: error (1062 Duplicate entry 'CL01' for key 'clinics.PRIMARY')
INSERT INTO clinics (ClinicID, ClinicName) VALUES ('CL01', 'Duplicate Clinic');

-- TEST 2: foreign key rejects an appointment for a patient that does not exist
-- EXPECT: error (1452 Cannot add or update a child row: a foreign key constraint fails)
INSERT INTO appointments (AppointmentID, PatientID, ClinicianID, ClinicID, AppointmentDate, AppointmentTime)
VALUES ('A099', 'OP999', 'CN01', 'CL01', '2026-12-01', '09:00:00');

-- TEST 3: NOT NULL rejects a patient with no postcode
-- EXPECT: error (1364 Field 'Postcode' doesn't have a default value)
INSERT INTO patients (PatientID, PatientName) VALUES ('OP099', 'Test Patient');

-- TEST 4: CHECK rejects an invalid follow-up priority
-- EXPECT: error (3819 Check constraint 'chk_followup_priority' is violated)
INSERT INTO followupplans (FollowUpID, AppointmentID, DueDate, Priority)
VALUES ('F099', 'A016', '2026-12-01', 'Low');

-- TEST 5: DEFAULT applies Pending when no status is given
-- EXPECT: ok (the SELECT shows FollowUpStatus = Pending)
START TRANSACTION;
INSERT INTO followupplans (FollowUpID, AppointmentID, DueDate, Priority)
VALUES ('F099', 'A016', '2026-12-01', 'Routine');
SELECT FollowUpID, AppointmentID, Priority, FollowUpStatus FROM followupplans WHERE AppointmentID = 'A016';
ROLLBACK;

-- TEST 6: UNIQUE prevents double-booking a clinician (Dr Shah, CN01, is booked 2026-10-05 09:00)
-- EXPECT: error (1062 Duplicate entry for key 'appointments.uq_appt_clinician_slot')
INSERT INTO appointments (AppointmentID, PatientID, ClinicianID, ClinicID, AppointmentDate, AppointmentTime)
VALUES ('A099', 'OP002', 'CN01', 'CL01', '2026-10-05', '09:00:00');

-- TEST 7: controlled UPDATE. One row is changed and every appointment of every clinician in
-- that specialty shows the new name. This is the update anomaly from Appendix 1, resolved.
-- EXPECT: ok (before: 'Glaucoma'; after: 'Glaucoma (adult)' on all 7 rows)
START TRANSACTION;
SELECT a.AppointmentID, c.ClinicianName, s.SpecialtyName
FROM appointments a JOIN clinicians c ON c.ClinicianID = a.ClinicianID
JOIN specialties s ON s.SpecialtyID = c.SpecialtyID
WHERE s.SpecialtyID = 'SP01' ORDER BY a.AppointmentID;
UPDATE specialties SET SpecialtyName = 'Glaucoma (adult)' WHERE SpecialtyID = 'SP01';
SELECT a.AppointmentID, c.ClinicianName, s.SpecialtyName
FROM appointments a JOIN clinicians c ON c.ClinicianID = a.ClinicianID
JOIN specialties s ON s.SpecialtyID = c.SpecialtyID
WHERE s.SpecialtyID = 'SP01' ORDER BY a.AppointmentID;
ROLLBACK;

-- TEST 8: CHECK also guards UPDATE (invalid status)
-- EXPECT: error (3819 Check constraint 'chk_followup_status' is violated)
UPDATE followupplans SET FollowUpStatus = 'Done' WHERE FollowUpID = 'F001';

-- TEST 9: foreign key guards UPDATE (clinician CN99 does not exist)
-- EXPECT: error (1452 Cannot add or update a child row: a foreign key constraint fails)
UPDATE appointments SET ClinicianID = 'CN99' WHERE AppointmentID = 'A001';

-- TEST 10: DELETE blocked by ON DELETE RESTRICT (appointment A001 has a prescription and a follow-up)
-- EXPECT: error (1451 Cannot delete or update a parent row: a foreign key constraint fails)
DELETE FROM appointments WHERE AppointmentID = 'A001';

-- TEST 11: DELETE of a patient with appointments is also blocked
-- EXPECT: error (1451 Cannot delete or update a parent row: a foreign key constraint fails)
DELETE FROM patients WHERE PatientID = 'OP001';

-- TEST 12: controlled DELETE with CASCADE. Appointment A016 has no prescription or follow-up,
-- so it can be deleted, and its link row in appointmentdiagnoses is removed with it.
-- EXPECT: ok (link rows for appointment A016: 1 before, 0 after)
START TRANSACTION;
SELECT COUNT(*) AS LinkRowsBefore FROM appointmentdiagnoses WHERE AppointmentID = 'A016';
DELETE FROM appointments WHERE AppointmentID = 'A016';
SELECT COUNT(*) AS LinkRowsAfter FROM appointmentdiagnoses WHERE AppointmentID = 'A016';
ROLLBACK;

-- TEST 13: DELETE succeeds for a patient with no dependent rows (OP014 has no appointments)
-- EXPECT: ok (1 row affected, then 0 rows remain inside the transaction)
START TRANSACTION;
DELETE FROM patients WHERE PatientID = 'OP014';
SELECT COUNT(*) AS Remaining FROM patients WHERE PatientID = 'OP014';
ROLLBACK;
