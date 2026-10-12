
    SELECT
        n.id,
        n.patient_id,
        p.full_name::TEXT,
        n.message,
        n.status,
        nr.status,
        n.scheduled_time
    FROM public.notifications n
    JOIN public.notification_recipients nr
        ON nr.notification_id = n.id
    JOIN public.caretaker_assignments ca
        ON ca.patient_id = n.patient_id
       AND ca.caretaker_id = nr.user_id
       AND ca.status = 'active'
    JOIN public.profiles p
        ON p.id = n.patient_id
    JOIN public.profiles caretaker
        ON caretaker.id = ca.caretaker_id
    WHERE nr.user_id = (SELECT auth.uid())
      AND caretaker.role = 'caretaker'
      AND caretaker.organization_id = ca.organization_id
      AND p.organization_id = ca.organization_id
      AND n.type = 'missed_alert'
      AND n.channel = 'web'
    ORDER BY n.scheduled_time DESC
    LIMIT 100;
