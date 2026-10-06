
BEGIN
    RETURN QUERY
    WITH eligible AS (
        SELECT
            n.id,
            nr.user_id,
            n.message
        FROM public.notifications n
        JOIN public.dose_logs d
            ON d.id = n.dose_log_id
        JOIN public.notification_recipients nr
            ON nr.notification_id = n.id
        WHERE n.type = 'reminder'
          AND n.channel = 'web'
          AND n.status = 'pending'
          AND nr.status = 'pending'
          AND nr.user_id = n.patient_id
          AND d.status = 'pending'
          AND n.scheduled_time <= NOW()
          AND n.scheduled_time >= NOW() - INTERVAL '10 minutes'
        ORDER BY n.scheduled_time
        LIMIT 20
        FOR UPDATE OF n SKIP LOCKED
    ),
    claimed AS (
        UPDATE public.notifications n
        SET status = 'sent'
        FROM eligible e
        WHERE n.id = e.id
        RETURNING n.id
    )
    SELECT
        e.id,
        e.user_id,
        e.message
    FROM eligible e
    JOIN claimed c ON c.id = e.id;
END;
