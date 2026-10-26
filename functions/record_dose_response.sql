
DECLARE
    v_dose public.dose_logs%ROWTYPE;
    v_user_id UUID;
    v_now TIMESTAMPTZ := clock_timestamp();
BEGIN
    -- 1. Identify the signed-in patient.
    v_user_id := (SELECT auth.uid());

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '28000';
    END IF;

    -- 2. Only these three responses are allowed.
    IF p_status IS NULL
       OR p_status NOT IN ('taken', 'skipped', 'snoozed') THEN
        RAISE EXCEPTION 'Invalid dose status'
            USING ERRCODE = '22023';
    END IF;

    -- 3. Validate notes.
    IF p_notes IS NOT NULL AND length(p_notes) > 2000 THEN
        RAISE EXCEPTION 'Notes cannot exceed 2000 characters'
            USING ERRCODE = '22023';
    END IF;

    -- 4. Validate snooze time.
    IF p_status = 'snoozed' THEN
        IF p_snoozed_until IS NULL
           OR p_snoozed_until <= v_now
           OR p_snoozed_until > v_now + INTERVAL '24 hours'
        THEN
            RAISE EXCEPTION
                'Snooze time must be within the next 24 hours'
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_snoozed_until IS NOT NULL THEN
        RAISE EXCEPTION
            'Snooze time is only valid for snoozed status'
            USING ERRCODE = '22023';
    END IF;

    -- 5. Lock the dose to prevent concurrent updates.
    -- Verify ownership through the medications table.
    SELECT d.*
    INTO v_dose
    FROM public.dose_logs AS d
    WHERE d.id = p_dose_id
      AND EXISTS (
          SELECT 1
          FROM public.medications AS m
          WHERE m.id = d.medication_id
            AND m.patient_id = v_user_id
      )
    FOR UPDATE OF d;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dose not found'
            USING ERRCODE = 'P0002';
    END IF;

    -- 6. Only pending or snoozed doses can change.
    IF v_dose.status NOT IN ('pending', 'snoozed') THEN
        RAISE EXCEPTION 'Dose already finalized'
            USING ERRCODE = '23514';
    END IF;

    -- 7. Update only approved columns.
    UPDATE public.dose_logs
    SET
        status = p_status,
        actual_time_taken =
            CASE
                WHEN p_status = 'taken' THEN v_now
                ELSE NULL
            END,
        snoozed_until =
            CASE
                WHEN p_status = 'snoozed'
                THEN p_snoozed_until
                ELSE NULL
            END,
        response_source = 'web',
        responded_at = v_now,
        notes = COALESCE(p_notes, v_dose.notes)
    WHERE id = p_dose_id
    RETURNING * INTO v_dose;

    RETURN v_dose;
END;
