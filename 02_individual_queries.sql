-- =====================================================================
-- CPU4103 Part C: individual queries (GROUP BY/HAVING, 3-table INNER JOIN, LEFT JOIN, subquery)
-- Student: Serat Choudhury (G1411615). Module: CPU4:103 Introduction to Database.
-- =====================================================================

USE crownfield_eye;

-- Query 1 (GROUP BY with HAVING): which clinicians have 2 or more appointments?

SELECT clinicians.ClinicianID, clinicians.ClinicianName, COUNT(*) AS TotalAppointments
FROM appointments
JOIN clinicians ON clinicians.ClinicianID = appointments.ClinicianID
GROUP BY clinicians.ClinicianID, clinicians.ClinicianName
HAVING COUNT(*) >= 2;

-- Query 2 (LEFT JOIN): which appointments have no follow-up plan

SELECT appointments.AppointmentID, appointments.AppointmentDate
FROM appointments
LEFT JOIN followupplans ON followupplans.AppointmentID = appointments.AppointmentID
WHERE followupplans.FollowUpID IS NULL;

-- Query 3 (INNER JOIN, 3 tables): which diagnosis was recorded at each appointment, and when?

SELECT appointments.AppointmentID, appointments.AppointmentDate, diagnoses.DiagnosisName
FROM appointments
INNER JOIN appointmentdiagnoses ON appointmentdiagnoses.AppointmentID = appointments.AppointmentID
INNER JOIN diagnoses ON diagnoses.DiagnosisID = appointmentdiagnoses.DiagnosisID
ORDER BY appointments.AppointmentID;

-- Query 4 (subquery): which patients have more appointments than the average patient?

SELECT patients.PatientID, patients.PatientName, COUNT(*) AS TotalAppointments
FROM patients
INNER JOIN appointments ON appointments.PatientID = patients.PatientID
GROUP BY patients.PatientID, patients.PatientName
HAVING COUNT(*) > (SELECT COUNT(*) / COUNT(DISTINCT PatientID) FROM appointments);
