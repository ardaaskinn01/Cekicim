-- Recalculate rating average automatically on the database server side
CREATE OR REPLACE FUNCTION update_user_rating_on_insert()
RETURNS TRIGGER AS $$
DECLARE
    avg_score NUMERIC;
BEGIN
    -- Calculate average score for the rated user
    SELECT COALESCE(AVG(score), 5.0) INTO avg_score
    FROM ratings
    WHERE rated_id = NEW.rated_id;

    -- Update driver rating if the rated user is a driver
    UPDATE drivers
    SET rating = avg_score
    WHERE id = NEW.rated_id;

    -- Update profile rating (for both customer and driver profiles)
    UPDATE profiles
    SET rating = avg_score
    WHERE id = NEW.rated_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute the function on rating inserts/updates
DROP TRIGGER IF EXISTS tr_update_user_rating ON ratings;
CREATE TRIGGER tr_update_user_rating
AFTER INSERT OR UPDATE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_user_rating_on_insert();
