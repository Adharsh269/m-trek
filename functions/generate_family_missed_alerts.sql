
DECLARE
    v_created INTEGER := 0;
BEGIN
    -- Create WhatsApp alert records for missed doses
    -- belonging to patients with eligible family contacts.
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
            'whatsapp',
            'MedicTrack: A scheduled medication dose was missed. Please check on your family member.',
            clock_timestamp(),
            'pending'
        FROM public.dose_logs AS d
        JOIN public.medications AS m
            ON m.id = d.medication_id
        WHERE d.status = 'missed'
          AND EXISTS (
              SELECT 1
              FROM public.patient_family_contacts AS fc
              WHERE fc.patient_id = m.patient_id
                AND fc.active = TRUE
                AND fc.whatsapp_enabled = TRUE
          )
        ON CONFLICT (dose_log_id)
          WHERE type = 'missed_alert'
            AND channel = 'whatsapp'
            AND dose_log_id IS NOT NULL
        DO NOTHING
        RETURNING id
    )
    SELECT COUNT(*) INTO v_created
    FROM inserted;

    -- Add eligible family contacts as recipients.
    INSERT INTO public.notification_recipients (
        notification_id,
        family_contact_id,
        status
    )
    SELECT
        n.id,
        fc.id,
        'pending'
    FROM public.notifications AS n
    JOIN public.patient_family_contacts AS fc
        ON fc.patient_id = n.patient_id
    WHERE n.type = 'missed_alert'
      AND n.channel = 'whatsapp'
      AND fc.active = TRUE
      AND fc.whatsapp_enabled = TRUE
      AND NOT EXISTS (
          SELECT 1
          FROM public.notification_recipients AS nr
          WHERE nr.notification_id = n.id
            AND nr.family_contact_id = fc.id
      )
    ON CONFLICT DO NOTHING;

    RETURN v_created;
END;
