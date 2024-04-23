SET client_min_messages = warning;

CREATE OR REPLACE FUNCTION widget()
RETURNS TEXT LANGUAGE SQL AS 'SELECT ''widget''::TEXT';
