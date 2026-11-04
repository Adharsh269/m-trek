
DECLARE
    v_admin_id UUID := auth.uid();
    v_org_id BIGINT;
    v_updated_id BIGINT;
BEGIN
    SELECT organization_id
    INTO v_org_id
    FROM public.profiles
    WHERE id = v_admin_id
      AND role = 'org_admin';

    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Organization admin required'
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.caretaker_assignments
    SET
        status = 'revoked',
        revoked_at = NOW()
    WHERE id = p_assignment_id
      AND organization_id = v_org_id
      AND status = 'active'
    RETURNING id INTO v_updated_id;

    IF v_updated_id IS NULL THEN
        RAISE EXCEPTION 'Active assignment not found'
            USING ERRCODE = 'P0002';
    END IF;

    RETURN TRUE;
END;
