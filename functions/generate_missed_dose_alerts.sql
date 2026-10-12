
DECLARE
    v_created INTEGER := 0;
BEGIN
    -- Insert one alert for each missed dose that has
    -- an active caretaker assigned to the patient.
    WITH inserted AS (
        INSERT INTO public.notifications (
            patient_id,
            dose_log_id,
            type,
            channel,
            message,
            scheduled_time,
            status
        )
        SELECT
            m.patient_id,
            d.id,
            'missed_alert',
            'web',
            'Missed medication dose: ' || m.name,
            clock_timestamp(),
            'pending'
        FROM public.dose_logs AS d
        JOIN public.medications AS m
            ON m.id = d.medication_id
        WHERE d.status = 'missed'
          AND EXISTS (
              SELECT 1
              FROM public.caretaker_assignments AS a
              WHERE a.patient_id = m.patient_id
                AND a.status = 'active'
          )
        ON CONFLICT (dose_log_id)
          WHERE type = 'missed_alert'
            AND channel = 'web'
            AND dose_log_id IS NOT NULL
        DO NOTHING
        RETURNING id
    )
    SELECT COUNT(*) INTO v_created
    FROM inserted;

    -- Create the caretaker recipient record.
    INSERT INTO public.notification_recipients (
        notification_id,
        user_id,
        status
    )
    SELECT
        n.id,
        a.caretaker_id,
        'pending'
    FROM public.notifications AS n
    JOIN public.caretaker_assignments AS a
        ON a.patient_id = n.patient_id
       AND a.status = 'active'
    WHERE n.type = 'missed_alert'
      AND n.channel = 'web'
      AND NOT EXISTS (
          SELECT 1
          FROM public.notification_recipients AS nr
          WHERE nr.notification_id = n.id
            AND nr.user_id = a.caretaker_id
      )
    ON CONFLICT DO NOTHING;

    RETURN v_created;
END;
