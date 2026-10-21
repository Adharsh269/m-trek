
DECLARE
    v_count INTEGER;
    v_now TIMESTAMPTZ := clock_timestamp();
BEGIN
    IF p_grace_minutes IS NULL
       OR p_grace_minutes < 1
       OR p_grace_minutes > 1440 THEN
        RAISE EXCEPTION 'Invalid grace period'
        USING ERRCODE = '22023';
    END IF;

    UPDATE public.dose_logs AS d
    SET status = 'missed'
    FROM public.medications AS m
    WHERE d.medication_id = m.id
      AND m.active = TRUE
      AND (
        (
          d.status = 'pending'
          AND d.scheduled_time <
              v_now - (p_grace_minutes * INTERVAL '1 minute')
        )
        OR
        (
          d.status = 'snoozed'
          AND d.snoozed_until IS NOT NULL
          AND v_now >= GREATEST(
            d.snoozed_until,
            d.scheduled_time
              + (p_grace_minutes * INTERVAL '1 minute')
          )
        )
      );

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN v_count;
END;
