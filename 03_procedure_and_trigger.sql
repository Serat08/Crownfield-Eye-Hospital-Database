USE crownfield_eye;

DROP PROCEDURE IF EXISTS sp_clinician_appointments;

DELIMITER //
CREATE PROCEDURE sp_clinician_appointments (IN p_clinician VARCHAR(10))
BEGIN
    SELECT appointments.AppointmentID, clinicians.ClinicianName, patients.PatientName,
           appointments.AppointmentDate, appointments.AppointmentTime
    FROM appointments
    JOIN patients ON patients.PatientID = appointments.PatientID
    JOIN clinicians ON clinicians.ClinicianID = appointments.ClinicianID
    WHERE appointments.ClinicianID = p_clinician;
END //
DELIMITER ;

CALL sp_clinician_appointments('CN01');
CALL sp_clinician_appointments('CN02');

DROP TRIGGER IF EXISTS trg_followup_due_after_appt;

DELIMITER //
CREATE TRIGGER trg_followup_due_after_appt
BEFORE INSERT ON followupplans
FOR EACH ROW
BEGIN
    IF NEW.DueDate < (SELECT AppointmentDate FROM appointments
                      WHERE AppointmentID = NEW.AppointmentID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Follow-up due date cannot be before the appointment date';
    END IF;
END //
DELIMITER ;

-- Trigger test 1: due date BEFORE the appointment date (A016 is on 2026-10-26). EXPECT: error 1644
INSERT INTO followupplans (FollowUpID, AppointmentID, DueDate, Priority)
VALUES ('F099', 'A016', '2026-10-01', 'Routine');

-- Trigger test 2: due date AFTER the appointment date. EXPECT: row accepted (then rolled back)
START TRANSACTION;
INSERT INTO followupplans (FollowUpID, AppointmentID, DueDate, Priority)
VALUES ('F099', 'A016', '2026-11-23', 'Routine');
SELECT FollowUpID, AppointmentID, DueDate, Priority, FollowUpStatus FROM followupplans WHERE FollowUpID = 'F099';
ROLLBACK;