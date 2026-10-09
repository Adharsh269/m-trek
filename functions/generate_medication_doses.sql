
DECLARE
    med RECORD;
    patient_zone TEXT;
    local_today DATE;
    first_day DATE;
    last_day DATE;
    inserted_count INTEGER;
BEGIN
    SELECT *
    INTO med
    FROM public.medications
    WHERE id = p_medication_id;

    IF NOT FOUND OR NOT med.active THEN
        RETURN 0;
    END IF;

    SELECT timezone
    INTO patient_zone
    FROM public.profiles
    WHERE id = med.patient_id;

    IF patient_zone IS NULL THEN
        RAISE EXCEPTION 'Patient timezone not found';
    END IF;

    local_today := (NOW() AT TIME ZONE patient_zone)::DATE;

    first_day := GREATEST(
        med.start_date,
        local_today
    );

    last_day := LEAST(
        COALESCE(med.end_date, local_today + 13),
        local_today + 13
    );

    IF last_day < first_day THEN
        RETURN 0;
    END IF;

    INSERT INTO public.dose_logs (
        medication_id,
        scheduled_time,
        status
    )
    SELECT
        med.id,
        ((d.day::DATE + t.dose_time)
            AT TIME ZONE patient_zone),
        'pending'
    FROM pg_catalog.generate_series(
        first_day,
        last_day,
        INTERVAL '1 day'
    ) AS d(day)
    CROSS JOIN LATERAL
        pg_catalog.unnest(med.times) AS t(dose_time)
    WHERE
        ((d.day::DATE + t.dose_time)
            AT TIME ZONE patient_zone) >= NOW()
    ON CONFLICT (medication_id, scheduled_time)
    DO NOTHING;

    GET DIAGNOSTICS inserted_count = ROW_COUNT;

    RETURN inserted_count;
END;
