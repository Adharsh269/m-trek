
BEGIN
    PERFORM public.generate_medication_doses(NEW.id);
    RETURN NEW;
END;
