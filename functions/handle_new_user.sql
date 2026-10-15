
DECLARE
  requested_role TEXT;
BEGIN
  requested_role :=
    NEW.raw_user_meta_data ->> 'role';

  INSERT INTO public.profiles (
    id,
    full_name,
    username,
    role
  )
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'username',
    CASE
      WHEN requested_role IN ('patient', 'caretaker', 'family')
        THEN requested_role
      ELSE 'patient'
    END
  );

  RETURN NEW;
END;
