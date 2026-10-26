
DECLARE
    v_dose public.dose_logs%ROWTYPE;
    v_user_id UUID;
BEGIN
    v_user_id := (SELECT auth.uid());

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;

    IF p_status IS NULL OR
       p_status NOT IN ('taken', 'skipped', 'snoozed') THEN
        RAISE EXCEPTION 'Invalid dose status'
            USING ERRCODE = '22023';
    END IF;

    IF p_notes IS NOT NULL AND
       char_length(p_notes) > 2000 THEN
        RAISE EXCEPTION 'Notes too long'
            USING ERRCODE = '22023';
    END IF;

    IF p_status = 'snoozed' THEN
        IF p_snoozed_until IS NULL OR
           p_snoozed_until <= NOW() OR
           p_snoozed_until > NOW() + INTERVAL '24 hours' THEN
            RAISE EXCEPTION
                'Snooze must be within the next 24 hours'
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_snoozed_until IS NOT NULL THEN
        RAISE EXCEPTION
            'Snooze time is only valid for snoozed status'
            USING ERRCODE = '22023';
    END IF;

    -- Lock the record to prevent concurrent changes.
    SELECT d.*
    INTO v_dose
    FROM public.dose_logs d
    JOIN public.medications m
      ON m.id = d.medication_id
    JOIN public.profiles p
      ON p.id = m.patient_id
    WHERE d.id = p_dose_id
      AND m.patient_id = v_user_id
      AND p.role = 'patient'
    FOR UPDATE OF d;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dose not found or access denied'
            USING ERRCODE = '42501';
    END IF;

    IF v_dose.status NOT IN ('pending', 'snoozed') THEN
        RAISE EXCEPTION 'Dose already finalized'
            USING ERRCODE = '23514';
    END IF;

    UPDATE public.dose_logs
    SET
        status = p_status,
        notes = COALESCE(p_notes, v_dose.notes),
        actual_time_taken =
            CASE WHEN p_status = 'taken'
                 THEN NOW() ELSE NULL END,
        snoozed_until =
            CASE WHEN p_status = 'snoozed'
                 THEN p_snoozed_until ELSE NULL END,
        responded_at = NOW(),
        response_source = 'web'
    WHERE id = p_dose_id
    RETURNING * INTO v_dose;

    RETURN v_dose;
END;
