
BEGIN
  IF p_after_id IS NULL OR p_after_id < 0
     OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Invalid claim parameters';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT n.id
    FROM public.notifications n
    WHERE n.channel = 'web'
      AND n.type IN ('reminder', 'missed_alert')
      AND n.status = 'pending'
      AND n.scheduled_time <= NOW()
      AND n.id > p_after_id
    ORDER BY n.scheduled_time, n.id
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.notifications n
  SET status = 'processing'
  FROM candidates c
  WHERE n.id = c.id
  RETURNING n.*;
END;
