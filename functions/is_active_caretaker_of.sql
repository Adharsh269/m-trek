
    SELECT EXISTS (
        SELECT 1
        FROM public.caretaker_assignments ca
        JOIN public.profiles caretaker
          ON caretaker.id = ca.caretaker_id
        JOIN public.profiles patient
          ON patient.id = ca.patient_id
        WHERE ca.patient_id = p_patient_id
          AND ca.caretaker_id = (SELECT auth.uid())
          AND ca.status = 'active'
          AND ca.organization_id = caretaker.organization_id
          AND ca.organization_id = patient.organization_id
          AND caretaker.role = 'caretaker'
          AND patient.role = 'patient'
    );
