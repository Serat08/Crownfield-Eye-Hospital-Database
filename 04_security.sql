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


       