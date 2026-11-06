
DROP DATABASE IF EXISTS crownfield_eye;
CREATE DATABASE crownfield_eye CHARACTER SET utf8mb4;
USE crownfield_eye;

-- ---------------------------------------------------------------------
-- 1. Tables (11), created parents first
-- ---------------------------------------------------------------------

CREATE TABLE specialties (
    SpecialtyID   VARCHAR(10)  NOT NULL,
    SpecialtyName VARCHAR(100) NOT NULL,
    CONSTRAINT pk_specialties      PRIMARY KEY (SpecialtyID),
    CONSTRAINT uq_specialty_name   UNIQUE (SpecialtyName)                       -- EXTRA
) ENGINE=InnoDB;

CREATE TABLE clinics (
    ClinicID   VARCHAR(10)  NOT NULL,
    ClinicName VARCHAR(100) NOT NULL,
    CONSTRAINT pk_clinics      PRIMARY KEY (ClinicID),
    CONSTRAINT uq_clinic_name  UNIQUE (ClinicName)                              -- EXTRA
) ENGINE=InnoDB;

-- The diagram shows one ClinicianName column (title and full name, as in Appendix 1)
-- and SpecialtyID as NOT NULL, so every clinician has exactly one primary specialty.
CREATE TABLE clinicians (
    ClinicianID   VARCHAR(10)  NOT NULL,
    ClinicianName VARCHAR(100) NOT NULL,
    SpecialtyID   VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_clinicians          PRIMARY KEY (ClinicianID),
    CONSTRAINT fk_clinician_specialty FOREIGN KEY (SpecialtyID)
        REFERENCES specialties (SpecialtyID) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- PatientID keeps the identifier used in Appendix 1 (for example OP001).
CREATE TABLE patients (
    PatientID   VARCHAR(10)  NOT NULL,
    PatientName VARCHAR(100) NOT NULL,
    Postcode    VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_patients          PRIMARY KEY (PatientID),
    CONSTRAINT chk_patient_postcode CHECK (LENGTH(Postcode) BETWEEN 5 AND 8)    -- EXTRA
) ENGINE=InnoDB;

CREATE TABLE appointments (
    AppointmentID   VARCHAR(10) NOT NULL,
    PatientID       VARCHAR(10) NOT NULL,
    ClinicianID     VARCHAR(10) NOT NULL,
    ClinicID        VARCHAR(10) NOT NULL,
    AppointmentDate DATE        NOT NULL,
    AppointmentTime TIME        NOT NULL,
    CONSTRAINT pk_appointments        PRIMARY KEY (AppointmentID),
    CONSTRAINT uq_appt_clinician_slot UNIQUE (ClinicianID, AppointmentDate, AppointmentTime),  -- EXTRA
    CONSTRAINT uq_appt_patient_slot   UNIQUE (PatientID, AppointmentDate, AppointmentTime),    -- EXTRA
    CONSTRAINT chk_appt_date          CHECK (AppointmentDate >= '2020-01-01'),                 -- EXTRA
    CONSTRAINT chk_appt_time          CHECK (AppointmentTime BETWEEN '08:00:00' AND '18:00:00'), -- EXTRA
    CONSTRAINT fk_appt_patient   FOREIGN KEY (PatientID)   REFERENCES patients (PatientID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appt_clinician FOREIGN KEY (ClinicianID) REFERENCES clinicians (ClinicianID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appt_clinic    FOREIGN KEY (ClinicID)    REFERENCES clinics (ClinicID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE diagnoses (
    DiagnosisID   VARCHAR(10)  NOT NULL,
    DiagnosisName VARCHAR(150) NOT NULL,
    CONSTRAINT pk_diagnoses      PRIMARY KEY (DiagnosisID),
    CONSTRAINT uq_diagnosis_name UNIQUE (DiagnosisName)                         -- EXTRA
) ENGINE=InnoDB;

-- Resolves the many-to-many between appointments and diagnoses.
-- Deleting an appointment removes only its link rows (CASCADE).
CREATE TABLE appointmentdiagnoses (
    AppointmentID VARCHAR(10) NOT NULL,
    DiagnosisID   VARCHAR(10) NOT NULL,
    CONSTRAINT pk_appointmentdiagnoses PRIMARY KEY (AppointmentID, DiagnosisID),
    CONSTRAINT fk_ad_appointment FOREIGN KEY (AppointmentID) REFERENCES appointments (AppointmentID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ad_diagnosis   FOREIGN KEY (DiagnosisID)   REFERENCES diagnoses (DiagnosisID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- MedicineName holds the substance only; the form is stored as Route
-- (Appendix 1 wrote "Sodium chloride drops", which mixed the two).
CREATE TABLE medicines (
    MedicineID   VARCHAR(10)  NOT NULL,
    MedicineName VARCHAR(100) NOT NULL,
    CONSTRAINT pk_medicines     PRIMARY KEY (MedicineID),
    CONSTRAINT uq_medicine_name UNIQUE (MedicineName)                           -- EXTRA
) ENGINE=InnoDB;

-- A prescription with no rows in prescriptionitems is not meaningful, but MySQL cannot
-- enforce "at least one item" structurally; it is handled in the transaction (Part D).
CREATE TABLE prescriptions (
    PrescriptionID VARCHAR(10) NOT NULL,
    AppointmentID  VARCHAR(10) NOT NULL,
    CONSTRAINT pk_prescriptions     PRIMARY KEY (PrescriptionID),
    CONSTRAINT fk_prescription_appt FOREIGN KEY (AppointmentID) REFERENCES appointments (AppointmentID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- As in the diagram: composite key (PrescriptionID, ItemNumber); Dose, Route, Frequency and
-- Duration are nullable text. They are SYNTHETIC (absent from Appendix 1), not clinical advice.
-- Duration is free text in the group design, so it cannot be validated numerically (a limitation).
CREATE TABLE prescriptionitems (
    PrescriptionID VARCHAR(10)  NOT NULL,
    ItemNumber     INT          NOT NULL,
    MedicineID     VARCHAR(10)  NOT NULL,
    Dose           VARCHAR(100) NULL,
    Route          VARCHAR(50)  NULL,
    Frequency      VARCHAR(100) NULL,
    Duration       VARCHAR(100) NULL,
    CONSTRAINT pk_prescriptionitems PRIMARY KEY (PrescriptionID, ItemNumber),
    CONSTRAINT chk_item_number CHECK (ItemNumber >= 1),                         -- EXTRA
    CONSTRAINT chk_item_route  CHECK (Route IN ('Eye drops','Eye gel','Eye ointment','Intravitreal injection','Oral')), -- EXTRA
    CONSTRAINT fk_item_prescription FOREIGN KEY (PrescriptionID) REFERENCES prescriptions (PrescriptionID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_item_medicine     FOREIGN KEY (MedicineID)     REFERENCES medicines (MedicineID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Appendix 1 gives "6 weeks | High": stored as DueDate (appointment date + interval) and Priority.
-- Notes (for example "Review IOP") are follow-up instructions, so the diagram places them here.
-- UNIQUE (AppointmentID) makes the relationship appointments 1 : 0..1 followupplans.
CREATE TABLE followupplans (
    FollowUpID     VARCHAR(10)  NOT NULL,
    AppointmentID  VARCHAR(10)  NOT NULL,
    DueDate        DATE         NOT NULL,
    Priority       VARCHAR(10)  NOT NULL,
    FollowUpStatus VARCHAR(20)  NOT NULL DEFAULT 'Pending',                      -- EXTRA (DEFAULT)
    Notes          VARCHAR(255) NULL,
    CONSTRAINT pk_followupplans      PRIMARY KEY (FollowUpID),
    CONSTRAINT uq_followup_appt      UNIQUE (AppointmentID),                     -- EXTRA
    CONSTRAINT chk_followup_priority CHECK (Priority IN ('Routine','High','Urgent')),                     -- EXTRA
    CONSTRAINT chk_followup_status   CHECK (FollowUpStatus IN ('Pending','Booked','Completed','Cancelled')), -- EXTRA
    CONSTRAINT chk_followup_due      CHECK (DueDate >= '2020-01-01'),            -- EXTRA
    CONSTRAINT fk_followup_appt FOREIGN KEY (AppointmentID) REFERENCES appointments (AppointmentID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. ALTER TABLE: secondary indexes for date-range queries (for example overdue follow-ups)
-- ---------------------------------------------------------------------
ALTER TABLE appointments  ADD INDEX idx_appointment_date (AppointmentDate);
ALTER TABLE followupplans ADD INDEX idx_followup_due (DueDate);

-- ---------------------------------------------------------------------
-- 3. Data. IDs are explicit text codes so foreign keys are easy to read and the data is reproducible.
-- ---------------------------------------------------------------------

INSERT INTO specialties (SpecialtyID, SpecialtyName) VALUES
('SP01','Glaucoma'),  -- (App1)
('SP02','Retina'),  -- (App1)
('SP03','Cornea'),  -- (App1)
('SP04','Cataract'),
('SP05','Paediatric Ophthalmology'),
('SP06','Oculoplastics'),
('SP07','Neuro-ophthalmology'),
('SP08','Uveitis'),
('SP09','Vitreoretinal Surgery'),
('SP10','Refractive Surgery'),
('SP11','Ocular Oncology'),
('SP12','Strabismus'),
('SP13','External Disease');

INSERT INTO clinics (ClinicID, ClinicName) VALUES
('CL01','City Road'),  -- (App1)
('CL02','Bedford'),  -- (App1)
('CL03','Croydon'),  -- (App1)
('CL04','Northgate'),
('CL05','Riverside'),
('CL06','Harbour Lane'),
('CL07','Elm Park'),
('CL08','Queens Court'),
('CL09','Millbank'),
('CL10','Westfield'),
('CL11','Orchard Way'),
('CL12','Kingsmead'),
('CL13','Abbey Street');

-- Clinician 13 has a specialty because the diagram makes SpecialtyID NOT NULL.
-- Clinicians CN11, CN12 and CN13 have no appointments (deliberate, for LEFT JOIN tests).
INSERT INTO clinicians (ClinicianID, ClinicianName, SpecialtyID) VALUES
('CN01','Dr Maya Shah','SP01'),  -- (App1)
('CN02','Dr Leo Grant','SP02'),  -- (App1)
('CN03','Dr Priya Nair','SP03'),  -- (App1)
('CN04','Dr Samuel Okafor','SP04'),
('CN05','Dr Elena Rossi','SP05'),
('CN06','Mr James Whitfield','SP06'),
('CN07','Dr Aisha Rahman','SP07'),
('CN08','Dr Tomas Novak','SP08'),
('CN09','Mr Kwame Mensah','SP09'),
('CN10','Dr Helen Park','SP01'),
('CN11','Dr Ravi Menon','SP02'),
('CN12','Ms Claire Doyle','SP13'),
('CN13','Dr Hannah Cole','SP12');

-- OP014 has no appointments (deliberate, for LEFT JOIN tests).
INSERT INTO patients (PatientID, PatientName, Postcode) VALUES
('OP001','Amina Yusuf','NE1 4AB'),  -- (App1)
('OP002','Daniel Reed','N16 7QP'),  -- (App1)
('OP003','Sofia Bennett','E8 2LD'),  -- (App1)
('OP004','Michael Okoro','SE6 3RT'),  -- (App1)
('OP005','Grace Mwangi','M14 6HT'),
('OP006','Oliver Chen','LS6 2JT'),
('OP007','Fatima Rahman','B15 2TT'),
('OP008','Henry Walsh','BS8 1QU'),
('OP009','Zainab Hussain','CF10 3AT'),
('OP010','Lucas Moreau','EH8 9YL'),
('OP011','Priyanka Desai','L3 5RF'),
('OP012','Thomas Eriksen','S10 2TN'),
('OP013','Ruth Abara','NG7 2RD'),
('OP014','George Pappas','G12 8QQ');

-- Appointments A001 to A005 are the Appendix 1 rows in their original order.
INSERT INTO appointments (AppointmentID, PatientID, ClinicianID, ClinicID, AppointmentDate, AppointmentTime) VALUES
('A001','OP001','CN01','CL01','2026-10-05','09:00:00'),  -- (App1)
('A002','OP002','CN02','CL01','2026-10-05','09:30:00'),  -- (App1)
('A003','OP001','CN01','CL02','2026-11-16','10:15:00'),  -- (App1)
('A004','OP003','CN01','CL01','2026-10-06','11:00:00'),  -- (App1)
('A005','OP004','CN03','CL03','2026-10-07','14:00:00'),  -- (App1)
('A006','OP005','CN10','CL04','2026-09-14','09:00:00'),
('A007','OP005','CN10','CL04','2026-10-12','09:15:00'),
('A008','OP006','CN04','CL05','2026-09-21','10:00:00'),
('A009','OP007','CN09','CL01','2026-09-28','13:30:00'),
('A010','OP008','CN02','CL01','2026-10-05','10:00:00'),
('A011','OP009','CN05','CL06','2026-10-08','15:00:00'),
('A012','OP010','CN08','CL07','2026-10-13','11:30:00'),
('A013','OP011','CN03','CL03','2026-10-14','14:30:00'),
('A014','OP012','CN01','CL01','2026-10-19','09:00:00'),
('A015','OP013','CN06','CL08','2026-10-21','10:45:00'),
('A016','OP013','CN07','CL09','2026-10-26','12:00:00'),
('A017','OP005','CN04','CL05','2026-10-27','09:30:00'),
('A018','OP006','CN04','CL05','2026-11-23','10:00:00'),
('A019','OP008','CN02','CL01','2026-11-09','10:30:00'),
('A020','OP012','CN10','CL04','2026-11-30','09:45:00'),
('A021','OP004','CN03','CL03','2026-12-07','14:00:00');

INSERT INTO diagnoses (DiagnosisID, DiagnosisName) VALUES
('D001','Ocular hypertension'),  -- (App1)
('D002','Diabetic macular oedema'),  -- (App1)
('D003','Glaucoma suspect'),  -- (App1)
('D004','Keratoconus'),  -- (App1)
('D005','Primary open-angle glaucoma'),
('D006','Age-related macular degeneration'),
('D007','Cataract'),
('D008','Dry eye disease'),
('D009','Anterior uveitis'),
('D010','Amblyopia'),
('D011','Blepharitis'),
('D012','Retinal detachment'),
('D013','Diabetic retinopathy'),
('D014','Thyroid eye disease');

-- Appointment A018 has no diagnosis yet (deliberate).
INSERT INTO appointmentdiagnoses (AppointmentID, DiagnosisID) VALUES
('A001','D001'),  -- (App1)
('A002','D002'),  -- (App1)
('A003','D001'),  -- (App1)
('A004','D003'),  -- (App1)
('A005','D004'),  -- (App1)
('A006','D005'),
('A007','D005'),
('A008','D007'),
('A009','D006'),
('A010','D002'),
('A010','D013'),
('A011','D010'),
('A012','D009'),
('A013','D008'),
('A013','D011'),
('A014','D005'),
('A015','D014'),
('A016','D014'),
('A017','D007'),
('A019','D002'),
('A020','D005'),
('A021','D004');

INSERT INTO medicines (MedicineID, MedicineName) VALUES
('M001','Latanoprost'),  -- (App1)
('M002','Timolol'),  -- (App1)
('M003','Aflibercept'),  -- (App1)
('M004','Sodium chloride'),  -- (App1)
('M005','Brimonidine'),
('M006','Dorzolamide'),
('M007','Bimatoprost'),
('M008','Ranibizumab'),
('M009','Dexamethasone'),
('M010','Cyclopentolate'),
('M011','Chloramphenicol'),
('M012','Prednisolone acetate'),
('M013','Carbomer'),
('M014','Acetazolamide');

-- Appointment A004 (OP003) has "None" in Appendix 1, so it has NO prescription row.
INSERT INTO prescriptions (PrescriptionID, AppointmentID) VALUES
('RX001','A001'),  -- (App1)
('RX002','A002'),  -- (App1)
('RX003','A003'),  -- (App1)
('RX004','A005'),  -- (App1)
('RX005','A006'),
('RX006','A007'),
('RX007','A008'),
('RX008','A009'),
('RX009','A010'),
('RX010','A011'),
('RX011','A012'),
('RX012','A013'),
('RX013','A014'),
('RX014','A015'),
('RX015','A017');

INSERT INTO prescriptionitems (PrescriptionID, ItemNumber, MedicineID, Dose, Route, Frequency, Duration) VALUES
('RX001',1,'M001','1 drop','Eye drops','Once daily (evening)','42 days'),  -- (App1)
('RX001',2,'M002','1 drop','Eye drops','Twice daily','42 days'),  -- (App1)
('RX002',1,'M003','2 mg','Intravitreal injection','Single dose','1 day'),  -- (App1)
('RX003',1,'M001','1 drop','Eye drops','Once daily (evening)','84 days'),  -- (App1)
('RX004',1,'M004','1 drop','Eye drops','Four times daily','56 days'),  -- (App1)
('RX005',1,'M005','1 drop','Eye drops','Twice daily','90 days'),
('RX005',2,'M006','1 drop','Eye drops','Three times daily','90 days'),
('RX006',1,'M007','1 drop','Eye drops','Once daily (evening)','90 days'),
('RX007',1,'M013','1 application','Eye gel','Four times daily','28 days'),
('RX008',1,'M008','0.5 mg','Intravitreal injection','Single dose','1 day'),
('RX009',1,'M003','2 mg','Intravitreal injection','Single dose','1 day'),
('RX010',1,'M010','1 drop','Eye drops','Once, before examination','1 day'),
('RX011',1,'M009','1 drop','Eye drops','Four times daily','14 days'),
('RX011',2,'M010','1 drop','Eye drops','Twice daily','7 days'),
('RX012',1,'M013','1 application','Eye gel','Four times daily','60 days'),
('RX012',2,'M011','1 application','Eye ointment','Twice daily','7 days'),
('RX013',1,'M001','1 drop','Eye drops','Once daily (evening)','90 days'),
('RX014',1,'M004','1 drop','Eye drops','Four times daily','30 days'),
('RX015',1,'M004','1 drop','Eye drops','Four times daily','28 days');

-- DueDate = appointment date + the interval in Appendix 1 (or a synthetic interval).
-- Notes come from the Appendix 1 "Notes" column. Statuses vary on purpose (Pending, Booked,
-- Completed, Cancelled); two Pending rows (F008 and F012) are overdue relative to 29 Oct 2026.
-- Appointments A016 and A018 to A021 have no follow-up (deliberate).
INSERT INTO followupplans (FollowUpID, AppointmentID, DueDate, Priority, FollowUpStatus, Notes) VALUES
('F001','A001','2026-11-16','High','Pending','Review IOP'),  -- (App1)
('F002','A002','2026-11-02','Urgent','Pending','OCT before review'),  -- (App1)
('F003','A003','2027-02-08','Routine','Pending','Visual field test'),  -- (App1)
('F004','A004','2027-04-06','Routine','Pending','Monitor'),  -- (App1)
('F005','A005','2026-12-02','Routine','Pending','Corneal topography'),  -- (App1)
('F006','A006','2026-10-12','Routine','Completed','IOP check after drop change'),
('F007','A007','2027-01-04','Routine','Pending','Visual field test'),
('F008','A008','2026-10-19','Urgent','Pending','Pre-operative assessment'),
('F009','A009','2026-11-09','High','Booked','OCT macula'),
('F010','A010','2026-11-09','Urgent','Booked','Injection review'),
('F011','A011','2026-12-03','Routine','Pending','Patching review'),
('F012','A012','2026-10-27','High','Pending','Flare-up review'),
('F013','A013','2026-11-25','Routine','Pending','Dry eye assessment'),
('F014','A014','2026-11-30','Routine','Booked','IOP review'),
('F015','A015','2026-12-02','Routine','Pending','Eyelid lesion review'),
('F016','A017','2026-11-24','Routine','Cancelled','Cataract listing');

-- ---------------------------------------------------------------------
-- 4. Evidence: row counts (screenshot this result)
-- ---------------------------------------------------------------------
SELECT 'patients' AS TableName, COUNT(*) AS RowsLoaded FROM patients
UNION ALL SELECT 'specialties', COUNT(*) FROM specialties
UNION ALL SELECT 'clinicians', COUNT(*) FROM clinicians
UNION ALL SELECT 'clinics', COUNT(*) FROM clinics
UNION ALL SELECT 'appointments', COUNT(*) FROM appointments
UNION ALL SELECT 'diagnoses', COUNT(*) FROM diagnoses
UNION ALL SELECT 'appointmentdiagnoses', COUNT(*) FROM appointmentdiagnoses
UNION ALL SELECT 'medicines', COUNT(*) FROM medicines
UNION ALL SELECT 'prescriptions', COUNT(*) FROM prescriptions
UNION ALL SELECT 'prescriptionitems', COUNT(*) FROM prescriptionitems
UNION ALL SELECT 'followupplans', COUNT(*) FROM followupplans;
