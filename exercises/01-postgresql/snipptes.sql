CREATE TABLE events (
	event_id SERIAL PRIMARY KEY,
	title text,
	starts timestamp,
	ends timestamp,
	venue_id integer,
	FOREIGN KEY (venue_id)
	 REFERENCES venues (venue_id)
);

INSERT INTO events (title,starts,ends) 
  VALUES ('LARP Club','2012-02-15 17:30:00','2012-02-15 19:30:00'),
    ('April Fools Day','2012-04-01 00:00:00','2012-04-01 23:59:59'),
    ('Christmas Day','2012-12-25 00:00:00','2012-12-25 23:59:59');

# Tag 1, Übung 2
SELECT v.country_code, e.title from venues v JOIN events e 
	ON (ei.venue_id = v.venue_id) 
	WHERE e.title = 'LARP Club';

# Tag 1, Übung 3

## In zwei Befehlen.
# In diesem Fall wir der Default-Wert nur für neue Einträge gesetzt
ALTER TABLE venues ADD COLUMN active boolean;
ALTER TABLE venues ALTER COLUMN active SET DEFAULT true;

## In einem Befehl.
# In diesem Fall wir der Default-Wert auch für existierende Einträge gesetzt.
ALTER TABLE venues ADD COLUMN active boolean DEFAULT true;

# Tag 2, Abschnitt Stored Procedures



SELECT * FROM crosstab(
'SELECT extract(year from starts) as year,
extract(month from starts) as month, count(*) FROM events
GROUP BY year, month
ORDER BY year, month',
  'SELECT * FROM generate_series(1,12)'
) AS (
year int,
jan int, feb int, mar int, apr int, may int, jun int, jul int, aug int, sep int, oct int, nov int, dec int
) ORDER BY YEAR;


select * from crosstab
('select extract (week from starts) as week, extract(dow from starts) as day, count(*)
from events 
where extract(month from starts) = 2 and extract(year from starts) = 2014
group by week, day
order by week, day'
,
'SELECT * FROM generate_series(1,7)'
) as (
week int,
sun int, mon int, tue int, wed int, thu int, fri int, sat int
) order by week;

# Tag 3, Projekt

 
CREATE TABLE genres (
	name text UNIQUE,				/* Genres werden nur benannt.*/
	position integer				/* Wofür ist die Position?*/
);
CREATE TABLE movies (
	movie_id SERIAL PRIMARY KEY,	/*SERIAL ist ein 'Auto-Incrementing Integer'*/
	title text,
	genre cube
);
CREATE TABLE actors (
	actor_id SERIAL PRIMARY KEY,
	name text
);

CREATE TABLE movies_actors ( 
	movie_id integer REFERENCES movies NOT NULL,
	actor_id integer REFERENCES actors NOT NULL,	
	/* To avoid that multiple combinations can be stored (they contain exactly the same information)*/
	UNIQUE (movie_id, actor_id) 
);

/* „It’s often good practice to create indexes on foreign keys 
	 to speed up reverse lookups (such as what movies this actor is involved in)“ */
CREATE INDEX movies_actors_movie_id ON movies_actors (movie_id); 
CREATE INDEX movies_actors_actor_id ON movies_actors (actor_id);
CREATE INDEX movies_genres_cube ON movies USING gist (genre);

# Tag 3, Projekt

select movie_id, title from movies
where levenshtein(lower(title), lower( 'a hard day nght' )) <= 3;

	
SELECT to_tsvector('A Hard Day''s Night'), to_tsquery('english', 'night & day');

	
SELECT name, dmetaphone(name), dmetaphone_alt(name),metaphone(name, 8), soundex(name) from actors;

SELECT * FROM actor	
WHERE metaphone(name,8) % metaphone('Robin Williams',8)
ORDER BY levenshtein(lower('Robin Williams'),lower(name));


# Tag 3, Cubes

SELECT name, cube_ur_coord('(0,7,0,0,0,0,0,0,0,7,0,0,0,0,10,0,0,0)', position) as score
FROM genres g
WHERE cube_ur_coord('(0,7,0,0,0,0,0,0,0,7,0,0,0,0,10,0,0,0)', position) > 0;

SELECT *,
cube_distance(genre, '(0,7,0,0,0,0,0,0,0,7,0,0,0,0,10,0,0,0)') dist
FROM movies 
ORDER BY dist
LIMIT 10;

SELECT title, cube_distance(genre, '(0,7,0,0,0,0,0,0,0,7,0,0,0,0,10,0,0,0)') as dist
FROM movies
WHERE cube_enlarge('(0,7,0,0,0,0,0,0,0,7,0,0,0,0,10,0,0,0)'::cube, 5, 18) @> genre 
ORDER BY dist;


SELECT m.movie_id, m.title
FROM movies m, 
	(
		SELECT genre, title FROM movies WHERE title = 'Mad Max'
	) as s 
WHERE cube_enlarge(s.genre, 5, 18) @> m.genre AND s.title <> m.title
ORDER BY cube_distance(m.genre, s.genre)
LIMIT 10;


select m.title from movies m NATURAL JOIN movies_actors NATURAL JOIN actors a where a.name = 'Bruce Willis';

# Tag 3, Übung 2

/* Tabelle für Kommentare */

CREATE TABLE comments(
	comment_id SERIAL PRIMARY KEY,
	movie_id integer REFERENCES movies NOT NULL,
	comment varchar(250)
);


/*Expand the movies database to track user comments and extract keywords (minus English stopwords).
  Cross-reference these keywords with actors’ last names, and try to find the most talked about
  actors.*/

/* Variante 1: 	Finde Nennungen aller Actor-Nachnamen in den Kommentaren des dazugehörigen Films
								und addiere diese dann über alle Filme, in denen der Actor auftauch. 
   							=> Bestimme die Nachnamen ('Letztes Wort im Autoren-String'?)
								=> Zähle, wie oft sie im tsvector des Kommentars auftauchen
								=> Addiere über alle Filme, in denen ACTOR auftaucht
*/


INSERT  INTO comments (movie_id,comment)
VALUES (
(SELECT movie_id from movies where title = 'Die Hard'),
'Bruce Willays, ey!'
);

CREATE OR REPLACE VIEW movies_with_comments AS
SELECT c.comment_id, m.title, c.comment FROM movies m NATURAL JOIN comments c;

SELECT regexp_replace(m.title, '^.* ', '');

SELECT m.movie_id, to_tsvector(c.comment) from actors a NATURAL JOIN movies_actors NATURAL JOIN movies m NATURAL JOIN comments c;




SELECT to_tsvector(comment) from comments;