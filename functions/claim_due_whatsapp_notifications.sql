
BEGIN
  IF p_after_id IS NULL OR p_after_id < 0
     OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN
    RAISE EXCEPTION 'Invalid claim parameters';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT n.id
    FROM public.notifications AS n
    WHERE n.channel = 'whatsapp'
      AND n.type = 'missed_alert'
      AND n.status = 'pending'
      AND n.scheduled_time <= NOW()
      AND n.id > p_after_id
    ORDER BY n.id
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.notifications AS n
  SET status = 'processing'
  FROM candidates AS c
  WHERE n.id = c.id
  RETURNING n.*;
END;
