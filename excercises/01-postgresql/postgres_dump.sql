--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: cube; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS cube WITH SCHEMA public;


--
-- Name: EXTENSION cube; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION cube IS 'data type for multidimensional cubes';


--
-- Name: dict_xsyn; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS dict_xsyn WITH SCHEMA public;


--
-- Name: EXTENSION dict_xsyn; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dict_xsyn IS 'text search dictionary template for extended synonym processing';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


SET search_path = public, pg_catalog;

--
-- Name: add_event(text, timestamp without time zone, timestamp without time zone, text, character varying, character); Type: FUNCTION; Schema: public; Owner: vagrant
--

CREATE FUNCTION add_event(title text, starts timestamp without time zone, ends timestamp without time zone, venue text, postal character varying, country character) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  did_insert boolean := false;
  found_count integer;
  the_venue_id integer;
BEGIN
  SELECT venue_id INTO the_venue_id
  FROM venues v
  WHERE v.postal_code=postal AND v.country_code=country AND v.name ILIKE venue
  LIMIT 1;
  
  IF the_venue_id IS NULL THEN
    INSERT INTO venues (name, postal_code, country_code)
    VALUES (venue, postal, country)
    RETURNING venue_id INTO the_venue_id;
    
    did_insert := true;
  END IF;
	
  -- Note: not an â€œerrorâ€, as in some programming languages
  RAISE NOTICE 'Venue found %', the_venue_id;

  INSERT INTO events (title, starts, ends, venue_id)
  VALUES (title, starts, ends, the_venue_id);

  RETURN did_insert;
END;
$$;


ALTER FUNCTION public.add_event(title text, starts timestamp without time zone, ends timestamp without time zone, venue text, postal character varying, country character) OWNER TO vagrant;

--
-- Name: cine_rec(text); Type: FUNCTION; Schema: public; Owner: vagrant
--

CREATE FUNCTION cine_rec(input text) RETURNS TABLE(related text)
    LANGUAGE plpgsql
    AS $$
DECLARE
actor_name text;
movie_title text;
BEGIN
SELECT name  INTO actor_name FROM actors WHERE name  LIKE input;
SELECT title  INTO movie_title FROM movies WHERE title LIKE input;
IF actor_name IS NOT NULL THEN
RAISE NOTICE 'Returning other movies for %', actor_name;
RETURN QUERY SELECT m.title 
FROM movies m NATURAL JOIN movies_actors NATURAL JOIN actors a 
WHERE a.name = actor_name
LIMIT 5;
ELSIF movie_title IS NOT NULL THEN
RAISE NOTICE 'Input is movie. TODO: Implement me!';
RETURN QUERY SELECT m.title
FROM movies m, 
(
SELECT genre,title FROM movies WHERE title = movie_title
) as s 
WHERE cube_enlarge(s.genre, 5, 18) @> m.genre AND s.title <> m.title
ORDER BY cube_distance(m.genre, s.genre)
LIMIT 10;
ELSE
RAISE NOTICE 'Input is neither an actor or movie that we know of...';
END IF;  
END;

$$;


ALTER FUNCTION public.cine_rec(input text) OWNER TO vagrant;

--
-- Name: log_event(); Type: FUNCTION; Schema: public; Owner: vagrant
--

CREATE FUNCTION log_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE
BEGIN
INSERT INTO logs (event_id, old_title, old_starts, old_ends) VALUES (OLD.event_id, OLD.title, OLD.starts, OLD.ends); RAISE NOTICE 'Someone just changed event #%', OLD.event_id; RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_event() OWNER TO vagrant;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: actors; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE actors (
    actor_id integer NOT NULL,
    name text
);


ALTER TABLE public.actors OWNER TO vagrant;

--
-- Name: actors_actor_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE actors_actor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.actors_actor_id_seq OWNER TO vagrant;

--
-- Name: actors_actor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE actors_actor_id_seq OWNED BY actors.actor_id;


--
-- Name: cities; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE cities (
    name text NOT NULL,
    postal_code character varying(9) NOT NULL,
    country_code character(2) NOT NULL,
    CONSTRAINT cities_postal_code_check CHECK (((postal_code)::text <> ''::text))
);


ALTER TABLE public.cities OWNER TO vagrant;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE comments (
    comment_id integer NOT NULL,
    movie_id integer NOT NULL,
    comment character varying(250)
);


ALTER TABLE public.comments OWNER TO vagrant;

--
-- Name: comments_comment_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE comments_comment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comments_comment_id_seq OWNER TO vagrant;

--
-- Name: comments_comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE comments_comment_id_seq OWNED BY comments.comment_id;


--
-- Name: countries; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE countries (
    country_code character(2) NOT NULL,
    country_name text
);


ALTER TABLE public.countries OWNER TO vagrant;

--
-- Name: events; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE events (
    event_id integer NOT NULL,
    title text,
    starts timestamp without time zone,
    ends timestamp without time zone,
    venue_id integer,
    colors text[]
);


ALTER TABLE public.events OWNER TO vagrant;

--
-- Name: events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_event_id_seq OWNER TO vagrant;

--
-- Name: events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE events_event_id_seq OWNED BY events.event_id;


--
-- Name: genres; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE genres (
    name text,
    "position" integer
);


ALTER TABLE public.genres OWNER TO vagrant;

--
-- Name: holidays; Type: VIEW; Schema: public; Owner: vagrant
--

CREATE VIEW holidays AS
    SELECT events.event_id AS holiday_id, events.title AS name, events.starts AS date, events.colors FROM events WHERE ((events.title ~~ '%Day%'::text) AND (events.venue_id IS NULL));


ALTER TABLE public.holidays OWNER TO vagrant;

--
-- Name: logs; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE logs (
    event_id integer,
    old_title character varying(255),
    old_starts timestamp without time zone,
    old_ends timestamp without time zone,
    logged_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.logs OWNER TO vagrant;

--
-- Name: movies; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE movies (
    movie_id integer NOT NULL,
    title text,
    genre cube
);


ALTER TABLE public.movies OWNER TO vagrant;

--
-- Name: movies_actors; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE movies_actors (
    movie_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.movies_actors OWNER TO vagrant;

--
-- Name: movies_movie_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE movies_movie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.movies_movie_id_seq OWNER TO vagrant;

--
-- Name: movies_movie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE movies_movie_id_seq OWNED BY movies.movie_id;


--
-- Name: movies_with_comments; Type: VIEW; Schema: public; Owner: vagrant
--

CREATE VIEW movies_with_comments AS
    SELECT c.comment_id, m.title, c.comment FROM (movies m NATURAL JOIN comments c);


ALTER TABLE public.movies_with_comments OWNER TO vagrant;

--
-- Name: venues; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE venues (
    venue_id integer NOT NULL,
    name character varying(255),
    street_adress text,
    type character(7) DEFAULT 'public'::bpchar,
    postal_code character varying(9),
    country_code character(2),
    active boolean DEFAULT true,
    CONSTRAINT venues_type_check CHECK ((type = ANY (ARRAY['public'::bpchar, 'private'::bpchar])))
);


ALTER TABLE public.venues OWNER TO vagrant;

--
-- Name: venues_venue_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE venues_venue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.venues_venue_id_seq OWNER TO vagrant;

--
-- Name: venues_venue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE venues_venue_id_seq OWNED BY venues.venue_id;


--
-- Name: actor_id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY actors ALTER COLUMN actor_id SET DEFAULT nextval('actors_actor_id_seq'::regclass);


--
-- Name: comment_id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY comments ALTER COLUMN comment_id SET DEFAULT nextval('comments_comment_id_seq'::regclass);


--
-- Name: event_id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY events ALTER COLUMN event_id SET DEFAULT nextval('events_event_id_seq'::regclass);


--
-- Name: movie_id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY movies ALTER COLUMN movie_id SET DEFAULT nextval('movies_movie_id_seq'::regclass);


--
-- Name: venue_id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY venues ALTER COLUMN venue_id SET DEFAULT nextval('venues_venue_id_seq'::regclass);


--
-- Data for Name: actors; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY actors (actor_id, name) FROM stdin;
1	50 Cent
2	A Martinez
3	A. Michael Baldwin
4	Aaron Eckhart
5	Aaron Paul
6	Aaron Stanford
7	Abbie Cornish
8	Abby Dalton
9	Abhay Deol
10	Abraham Sofaer
11	Adam Baldwin
12	Adam Beach
13	Adam Hann-Byrd
14	Adam Lavorgna
15	Adam Roarke
16	Adam Sandler
17	Adam Storke
18	Adam Trese
19	Adam West
20	Addison Richards
21	Adele Mara
22	Aden Young
23	Adewale Akinnuoye-Agbaje
24	Adolfo Celi
25	Adolphe Menjou
26	Adrian Dunbar
27	Adrian Pasdar
28	Adrian Zmed
29	Adrien Brody
30	Adrienne Barbeau
31	Adrienne Corri
32	Adrienne King
33	Adrienne Shelly
34	Agatha Hurle
35	Agathe Natanson
36	Agga Olsen
37	Agnes Bruckner
38	Agnes Moorehead
39	Aidan Gould
40	Aidan Quinn
41	Aitana SÃ¡nchez-GijÃ³n
42	Akbar Kurtha
43	Ake Nyman
44	Akiko Wakabayashi
45	Akim Tamiroff
46	Akosua Busia
47	Aksel Hennie
48	Al Freeman Jr.
49	Al Jolson
50	Al Pacino
51	Alain Delon
52	Alan Alda
53	Alan Arkin
54	Alan Badel
55	Alan Bates
56	Alan Baxter
57	Alan Cox
58	Alan Cumming
59	Alan Curtis
60	Alan David
61	Alan Fisler
62	Alan Hale
63	Alan King
64	Alan Ladd
65	Alan Marshall
66	Alan Mowbray
67	Alan Napier
68	Alan Randolph Scott
69	Alan Rickman
70	Alan Ruck
71	Alan Webb
72	Alan Young
73	Alastair Sim
74	Albert Brooks
75	Albert Dekker
76	Albert Finney
77	Albert Hall
78	Alberta Watson
79	Alberto De Mendoza
80	Alberto Morin
81	Aldo GiuffrÃ¨
82	Aldo Ray
83	Alec Baldwin
84	Alec Cawthorne
85	Alec Clunes
86	Alec Guinness
87	Alec McCowen
88	Alex D. Linz
89	Alex Daniels
90	Alex Haw
91	Alex Hyde-White
92	Alex McArthur
93	Alex Scott
94	Alex Vincent
95	Alexa Davalos
96	Alexa Vega
97	Alexander Fehling
98	Alexander Godunov
99	Alexander Goodwin
100	Alexander Knox
101	Alexander Morton
102	Alexandra Holden
103	Alexia Keogh
104	Alexis Arquette
105	Alexis Cruz
106	Alexis Smith
107	Alexis Zegerman
108	Alfred Molina
109	Alfred Ryder
110	Ali MacGraw
111	Alice Cooper
112	Alice Krige
113	Alicia Silverstone
114	Alicia Witt
115	Alida Valli
116	Aline MacMahon
117	Alisan Porter
118	Alison Doody
119	Alison Eastwood
120	Alison Folland
121	Alison Leggatt
122	Alison Routledge
123	Alison Selford
124	Alison Whelan
125	Allan Jones
126	Allan Melvin
127	Allen Covert
128	Allen Danziger
129	Allen Garfield
130	Allen Jenkins
131	Allen Payne
132	Allison Balson
133	Allison Janney
134	Ally Sheedy
135	Ally Walker
136	Alphonsia Emmanuel
137	Alun Armstrong
138	Alyson Hannigan
139	Alyson Reed
140	Amanda Barrie
141	Amanda Bearse
142	Amanda Bynes
143	Amanda Plummer
144	Amanda Wyss
145	Amber Heard
146	Amber Smith
147	Amber Tamblyn
148	Amrish Puri
149	Amy Adams
150	Amy Brenneman
151	Amy Ingersoll
152	Amy Irving
153	Amy Locane
154	Amy Madigan
155	Amy Robinson
156	Amy Steel
157	Amy Veness
158	Amy Yasbeck
159	Anamaria Marinca
160	Anatoli Davydov
161	Anders Baasmo Christiansen
162	Andersen Gabrych
163	Andie MacDowell
164	Andre Braugher
165	Andre Gregory
166	Andrea Eckert
167	Andrea Marcovicci
168	Andrea Occhipinti
169	Andrea Riseborough
170	Andrea Roth
171	Andrew Cruickshank
172	Andrew Divoff
173	Andrew Duggan
174	Andrew Garfield
175	Andrew Knott
176	Andrew Lauer
177	Andrew McCarthy
178	Andrew Prine
179	Andrew Robinson
180	Andrew Sachs
181	Andrew Stevens
182	Andrzej Seweryn
183	AndrÃ© Morell
184	Andy Dick
185	Andy Garcia
186	Andy Griffith
187	Andy J. Forest
188	Andy Romano
189	Aneta Corsaut
190	Angela Bassett
191	Angela Douglas
192	Angela Featherstone
193	Angela Goethals
194	Angela Lansbury
195	Angelina Jolie
196	Angeline Ball
197	Angelo Rossito
198	Angie Brown
199	Angie Dickinson
200	Angie Everhart
201	AnicÃ©e Alvina
202	Anita Briem
203	Anita Ekberg
204	Anjelica Huston
205	Ann Blyth
206	Ann Carter
207	Ann Doran
208	Ann Dvorak
209	Ann Hearn
210	Ann Miller
211	Ann Prentiss
212	Ann Richards
213	Ann Savage
214	Ann Shirley
215	Ann Todd
216	Ann Wedgeworth
217	Ann-Margret
218	Anna Anissimova
219	Anna Chlumsky
220	Anna Friel
221	Anna Karen
222	Anna Karina
223	Anna Massey
224	Anna May Wong
225	Anna Palk
226	Anna Paquin
227	Anna Proclemer
228	Anna-Maria Monticelli
229	Annabella Sciorra
230	Annabeth Gish
231	Anne Archer
232	Anne Bancroft
233	Anne Baxter
234	Anne Brochet
235	Anne Christianson
236	Anne Francis
237	Anne Grey
238	Anne Gwynne
239	Anne Heche
240	Anne Meara
241	Anne Ramsey
242	Anne Revere
243	Anne Suzuki
244	Anne Tenney
245	Anne-Louise Lambert
246	Anne-Marie Kennedy
247	Annette Bening
248	Annette O'Toole
249	Annette O`Toole
250	Annette Woska
251	Annie Corley
252	Annie Golden
253	Annie McEnroe
254	Annie Packert
255	Annie Potts
256	Annie Ross
257	Anny Duperey
258	Anny Ondra
259	Anson Mount
260	Anthony Barrile
261	Anthony Edwards
262	Anthony Fauci
263	Anthony Franciosa
264	Anthony Geary
265	Anthony Heald
266	Anthony Higgins
267	Anthony Hopkins
268	Anthony LaPaglia
269	Anthony Michael Hall
270	Anthony Perkins
271	Anthony Quayle
272	Anthony Quinn
273	Anthony Ross
274	Anthony Simcoe
275	Anthony Zerbe
276	Anton Rodgers
277	Antonio Banderas
278	Antonio Mendoza
279	Antonio Moreno
280	Anya Ormsby
281	Anzac Wallace
282	Apollonia Kotero
283	April Grace
284	Aran Bell
285	Ariane
286	Arielle Kebbel
287	Arleen Whelan
288	Arlene Dahl
289	Arlene Francis
290	Arlo Guthrie
291	Armand Assante
292	Armin Mueller-Stahl
293	Arnold Lucy
294	Arnold Schwarzenegger
295	Arnold Vosloo
296	Arsenio Hall
297	ArsinÃ©e Khanjian
298	Art Evans
299	Art Garfunkel (as Arthur Garfunkel)
300	Art LaFleur
301	Art Metrano
302	Arte Johnson
303	Arthur Askey
304	Arthur Chesney
305	Arthur Hill
306	Arthur Hunnicutt
307	Arthur Kennedy
308	Arthur Lake
309	Arthur O'Connell
310	Artie Lange
311	Arturo de CÃ³rdova
312	Arye Gross
313	Ash Adams
314	Ashley Greene
315	Ashley Judd
316	Ashley Laurence
317	Ashley Olsen
318	Ashley Peldon
319	Aude Landry
320	Audie Murphy
321	Audra Lindley
322	Audra McDonald
323	Audrey Dalton
324	Audrey Hepburn
325	Audrey Meadows
326	Audrey Totter
327	August Diehl
328	August Schellenberg
329	Augustus Philips
330	Aure Atika
331	Austin Nagler
332	Austin O'Brien
333	Austin Pendleton
334	Ava Gardner
335	Avery Brooks
336	Aya Takanashi
337	B.D. Wong
338	Barbara Bach
339	Barbara Baxley
340	Barbara Bel Geddes
341	Barbara Bosson
342	Barbara Carrera
343	Barbara Crampton
344	Barbara Eden
345	Barbara Feldon
346	Barbara Gordon
347	Barbara Hale
348	Barbara Harris
349	Barbara Hershey
350	Barbara Lindsay
351	Barbara O'Neil
352	Barbara Parkins
353	Barbara Payton
354	Barbara Rush
355	Barbara Shelley
356	Barbara Stanwyck
357	Barbara Sukowa
358	Barbara Tyson
359	Barbara Windsor
360	Barbra Streisand
361	Barnard Hughes
362	Barney
363	Barney Clark
364	Barret Oliver
365	Barry Bostwick
366	Barry Brown
367	Barry Corbin
368	Barry Dennen
369	Barry Fitzgerald
370	Barry Foster
371	Barry Gibb
372	Barry Miller
373	Barry Newman
374	Barry Pepper
375	Barry Primus
376	Bart Burns
377	Barton Heyman
378	Basil Rathbone
379	Basil Sydney
380	Basil Wallace
381	Beatrice Kay
382	Beatrice Pearson
383	Beatrice Straight
384	Beau Bridges
385	Bebe Daniels
386	Bebe Neuwirth
387	Bee Duffell
388	Bel DeliÃ¡
389	Bela Lugosi
390	Belinda Bauer
391	Bella Randles
392	Ben Affleck
393	Ben Chaplin
394	Ben Cross
395	Ben Duncan
396	Ben Foster
397	Ben Gazzara
398	Ben Johnson
399	Ben Kingsley
400	Ben Mendelsohn
401	Ben Stiller
402	Benicio Del Toro
403	Benjamin Bratt
404	Benjamin Green
405	Benjamin Hendrickson
406	Bennett Ohta
407	Benno FÃ¼rmann
408	Berj Fazalian
409	Bernadette Peters
410	Bernard Cribbins
411	Bernard Fresson
412	Bernard Hill
413	Bernard Lee
414	Bernard Miles
415	Bernie Casey
416	Bernie Coulson
417	Berry Berenson
418	Berry Kroeger
419	Bert Freed
420	Bert Lahr
421	Bert Palmer
422	Bert Remsen
423	Bertrand Bonvoisin
424	Bess Armstrong
425	Bessie Love
426	Bethel Leslie
427	Betsy Baker
428	Betsy Blair
429	Betsy Brantley
430	Betsy Palmer
431	Bette Davis
432	Bette Midler
433	Betty Anne Rees
434	Betty Buckley
435	Betty Grable
436	Betty White
437	Beulah Bondi
438	Beverley Hope Atkinson
439	Beverly Bonner
440	Beverly D'Angelo
441	Beverly Garland
442	Beverly Lunsford
443	Bibi Andersson
444	Biff Manard
445	Biff McGuire
446	Bill Barretta
447	Bill Brochtrup
448	Bill Byrge
449	Bill Campbell
450	Bill Cobbs
451	Bill Coyne
452	Bill Duck
453	Bill Duke
454	Bill Hayes
455	Bill Hunter
456	Bill Kerr
457	Bill Maher
458	Bill McKinney
459	Bill Mumy
460	Bill Murray
461	Bill Nighy
462	Bill Nunn
463	Bill Paxton
464	Bill Pullman
465	Bill Pulmann
466	Bill Thornbury
467	Billie Dove
468	Billie Whitelaw
469	Billy Bob Thornton
470	Billy Chapin
471	Billy Connolly
472	Billy Crudup
473	Billy Crystal
474	Billy Dee Williams
475	Billy Green Bush
476	Billy Jayne
477	Billy Wirth
478	Billy Zane
479	Bin Li
480	Bin Wu
481	Bing Crosby
482	Blair Brown
483	Blythe Danner
484	Bo Derek
485	Bo Hopkins
486	Bob Balaban
487	Bob Gunton
488	Bob Hastings
489	Bob Holt
490	Bob Hope
491	Bob Hoskins
492	Bob Newhart
493	Bob Zmuda
494	Bobby Darin
495	Bobby Di Cicco
496	Bobby Driscoll
497	Bobby Fite
498	Bolo Yeung
499	Bonnie Bartlett
500	Bonnie Bedelia
501	Bonnie Hunt
502	Booker Bradshaw
503	Boris Karloff
504	Boyd Gaines
505	BoÅ¼ena Dobierzewska
506	Brad Davis
507	Brad Dourif
508	Brad Greenquist
509	Brad Pitt
510	Brad Renfro
511	Bradford Dillman
512	Bradley Gregg
513	Bradley Whitford
514	Brandon De Wilde
515	Brandon Lee
516	Breckin Meyer
517	Brenda Blethyn
518	Brenda De Banzie
519	Brenda Fricker
520	Brenda Marshall
521	Brenda Vaccaro
522	Brendan Fletcher
523	Brendan Fraser
524	Brendan Gleeson
525	Brendan Sexton III
526	Brent Briscoe
527	Brent Hinkley
528	Brent Spiner
529	Brett Halsey
530	Brian Aherne
531	Brian Bennett
532	Brian Blessed
533	Brian Cox
534	Brian Dennehy
535	Brian Donlevy
536	Brian Geraghty
537	Brian Haley
538	Brian Keith
539	Brian Kerwin
540	Brian Narelle
541	Brian O'Halloran
542	Brian Tyler
543	Brian Van Holt
544	Brian Wimmer
545	Brid Brennan
546	Bridget Fonda
547	Bridgette Wilson
548	Brigitte Auber
549	Brigitte Fossey
550	Brigitte Nielsen
551	Brion James
552	Britney Spears
553	Britt Ekland
554	Brittany Murphy
555	Brittany Snow
556	Bronson Pinchot
557	Brooke Adams
558	Brooke Elliott
559	Brooke Shields
560	Bruce Abbott
561	Bruce Bennett
562	Bruce Boxleitner
563	Bruce Cabot
564	Bruce Campbell
565	Bruce Davison
566	Bruce Dern
567	Bruce Gray
568	Bruce Greenwood
569	Bruce Jones
570	Bruce McGill
571	Bruce Spence
572	Bruce Welch
573	Bruce Willis
574	Bruno Kirby
575	Bruno Lawrence
576	Bryan Brown
577	Bryan Cranston
578	Bryan Forbes
579	Bryant Haliday
580	Bubba Smith
581	Buck Henry
582	Bud Cort
583	Bud Tingwell
584	Buddy Ebsen
585	Buddy Hackett
586	Burgess Meredith
587	Burl Ives
588	Burt Kwouk
589	Burt Lancaster
590	Burt Reynolds
591	Burt Young
592	Buster Crabbe
593	Buster Keaton
594	Buzz Kilman
595	Byron Mann
596	C. Aubrey Smith
597	C. Thomas Howell
598	C.W. Mundy
599	Cab Calloway
600	Caerthan Banks
601	Caitlin Clarke
602	Cal Kuniholm
603	Calista Flockhart
604	Callie Thorne
605	Callum Keith Rennie
606	Cameron Bancroft
607	Cameron Bright
608	Cameron Diaz
609	Cameron Mitchell
610	Camilla Belle
611	Camilla Sparv
612	Camille Coduri
613	Campbell Scott
614	Candace Glendenning
615	Candice Bergen
616	Candy Clark
617	Cantinflas
618	Capucine
619	Carey Mulligan
620	Carl Anderson
621	Carl Bradshaw
622	Carl Reiner
623	Carl Weathers
624	Carla Gallo
625	Carla Gugino
626	Carlene Watkins
627	Carlo Giustini
628	Carlos MontalbÃ¡n
629	Carmen Argenziano
630	Carol Kane
631	Carol Lynley
632	Carol van Herwijnen
633	Carole Bouquet
634	Carole Landis
635	Carole Lombard
636	Caroline Ducey
637	Caroline Goodall
638	Caroline Kava
639	Caroline Langrishe
640	Caroline Munro
641	Caroline Rothwell
642	Carolyn Jones
643	Carolyn Mitchell
644	Carrie Fisher
645	Carrie Henn
646	Carrie Snodgress
647	Carrie-Anne Moss
648	Carroll Baker
649	Carroll O'Connor
650	Cary Elwes
651	Cary Grant
652	Cary-Hiroyuki Tagawa
653	Casey Affleck
654	Casey Siemaszko
655	Casper van Dien
656	Cassandra Peterson
657	Cassy Friel
658	Cate Blanchett
659	Catherine An
660	Catherine Breillat
661	Catherine Deneuve
662	Catherine Hicks
663	Catherine Keener
664	Catherine Mary Stewart
665	Catherine McCormack
666	Catherine O'Hara
667	Catherine Schell
668	Catherine Zeta-Jones
669	Cathy Downs
670	Cathy Moriarty
671	Cathy Tyson
672	Catlin Adams
673	Cecil Kellaway
674	Cecil Parker
675	Cecilia Camacho
676	Cecillia Stark
677	Celeste Holm
678	Celia Johnson
679	Celia Lovsky
680	Cesar Romero
681	Cesare Danova
682	Cesare Doneva
683	Chad Everett
684	Chad Lowe
685	Chaim Girafi
686	Chaney Kley
687	Charlene Holt
688	Charles Aznavour
689	Charles Bickford
690	Charles Boyer
691	Charles Bronson
692	Charles Cioffi
693	Charles Coburn
694	Charles Dance
695	Charles Drake
696	Charles Durning
697	Charles Fleischer
698	Charles Gray
699	Charles Grodin
700	Charles Haid
701	Charles Hallahan
702	Charles Halton
703	Charles Hawtrey
704	Charles Herbert
705	Charles Laughton
706	Charles Martin Smith
707	Charles McGraw
708	Charles Middleton
709	Charles Napier
710	Charles Ogle
711	Charles Ruggles
712	Charles S. Dutton
713	Charles Starrett
714	Charles Vanel
715	Charles Waldron
716	Charley Grapewin
717	Charlie Chaplin
718	Charlie Cox
719	Charlie Korsmo
720	Charlie Sheen
721	Charlie Tanimoto
722	Charlize Theron
723	Charlotte Cornwell
724	Charlotte Lewis
725	Charlotte Rampling
726	Charlton Heston
727	Chazz Dominguez
728	Chazz Palminteri
729	Cheech Marin
730	Chelsea Field
731	Cher
732	Cherie Lunghi
733	Cheryl Campbell
734	Cheryl Ladd
735	Cheryl Pollak
736	Chester Morris
737	Chevy Chase
738	Chi McBride
739	Chiara Mastroianni
740	Chico Marx
741	Chief Dan George
742	Chieko Matsubara
743	Chintara Sukapatana
744	Chips Rafferty
745	Chloe Franks
746	Chloe Moretz
747	Chloe Webb
748	ChloÃ« Sevigny
749	Chow Yun Fat
750	Chris Bauer
751	Chris Cooke
752	Chris Cooper
753	Chris Eigeman
754	Chris Elliott
755	Chris Evans
756	Chris Farley
757	Chris Haywood
758	Chris Isaak
759	Chris Kattan
760	Chris Klein
761	Chris Lemmon
762	Chris Noth
763	Chris O'Donnell
764	Chris O'Neill
765	Chris Owen
766	Chris Parker
767	Chris Pedersen
768	Chris Penn
769	Chris Rock
770	Chris Sarandon
771	Chris Stafford
772	Chris Tucker
773	Christa Denton
774	Christian Bale
775	Christian Slater
776	Christina Applegate
777	Christina Brucato
778	Christina Pickles
779	Christina Ricci
780	Christina Vidal
781	Christine Cavanaugh
782	Christine Elise
783	Christine Kaufmann
784	Christine Lahti
785	Christine Noonan
786	Christine Taylor
787	Christophe Malavoy
788	Christopher Atkins
789	Christopher Cary
790	Christopher Castile
791	Christopher Cazenove
792	Christopher Daniel Barnes
793	Christopher Eccleston
794	Christopher George
795	Christopher Jones
796	Christopher Lambert
797	Christopher Lee
798	Christopher Lloyd
799	Christopher McDonald
800	Christopher Mitchum
801	Christopher Penn
802	Christopher Plummer
803	Christopher Reeve
804	Christopher Stone
805	Christopher Walken
806	Chuck Bush
807	Chuck Connors
808	Chuck Norris
809	Chuck Schoville
810	CiarÃ¡n Hinds
811	Cillian Murphy
812	Cindy Morgan
813	Cindy Pickett
814	Cindy Williams
815	Claire Bloom
816	Claire Danes
817	Claire Forlani
818	Claire Trevor
819	Clancy Brown
820	Clare Higgins
821	Clarence Felder
822	Clark Gable
823	Claude Akins
824	Claude Atkins
825	Claude Atkuns
826	Claude Dauphin
827	Claude Earl Jones
828	Claude Gensac
829	Claude Jade
830	Claude Jarman Jr.
831	Claude Rains
832	Claude Rich
833	Claudette Colbert
834	Claudia Barrett
835	Claudia Cardinale
836	Claudia Christian
837	Claudia Drake
838	Claudia Stedelin
839	Claudine Auger
840	Claudine Longet
841	Clayton Rohner
842	Clea DuVall
843	Cleavon Little
844	Clelia Matania
845	Cliff De Young
846	Cliff Gorman
847	Cliff Osmond
848	Cliff Potts
849	Cliff Richard
850	Cliff Robertson
851	Clifton Collins Jr.
852	Clifton James
853	Clifton Webb
854	Clint Eastwood
855	Clint Walker
856	Clive Brook
857	Clive Owen
858	Clive Revill
859	Clive Russell
860	Cloris Leachman
861	Cole Hauser
862	Cole Sprouse
863	Coleen Gray
864	Colin Farrell
865	Colin Firth
866	Colin Friels
867	Colleen Camp
868	Colleen Dewhurst
869	Colleen Rennison
870	Colm Meaney
871	Connie Mason
872	Connie Nielsen
873	Connie Scott
874	Conny Van Dyke
875	Conrad Veidt
876	Constance Collier
877	Constance Cummings
878	Constance Marie
879	Constance Towers
880	Cora Witherspoon
881	Corbin Bernsen
882	Corey Feldman
883	Corey Haim
884	Corin Redgrave
885	Corinne Clery
886	Cornel Wilde
887	Cory Danziger
888	Courteney Cox
889	Courtney B. Vance
890	Courtney Chase
891	Courtney Love
892	Craig Bierko
893	Craig Chester
894	Craig Ferguson
895	Craig Kelly
896	Craig Olejnik
897	Craig Reay
898	Craig Sheffer
899	Craig Smith
900	Craig Stevens
901	Craig T. Nelson
902	Craig Vandenburgh
903	Craig Warnock
904	Craig Wasson
905	Crispin Glover
906	Cristi Harris
907	Cuba Gooding Jr.
908	Curd JÃ¼rgens
909	Cybill Shepherd
910	Cyd Charisse
911	Cylk Cozart
912	Cynthia Myers
913	Cynthia Patrick
914	Cynthia Rhodes
915	Cynthia Stevenson
916	Cyril Cusack
917	Cyril McLagian
918	Cyril O'Reilly
919	CÃ©line Lomez
920	D.B. Sweeney
921	D.J. Cotrona
922	D.W. Moffett
923	Dabney Coleman
924	Daisy Eagan
925	Daisy the Dog
926	Dale Midkiff
927	Dale Robertson
928	Daliah Lavi
929	Dallas Roberts
930	Dame May Whitty
931	Damian Chapa
932	Damon Wayans
933	Damon Wimbley
934	Dan Aykroyd
935	Dan Duryea
936	Dan Hedaya
937	Dan Hicks
938	Dan Monahan
939	Dan Moran
940	Dan O'Herlihy
941	Dan O`Bannon
942	Dan O`Herlihy
943	Dana Andrews
944	Dana Carvey
945	Dana Davis
946	Dana Delany
947	Dana Hill
948	Dana Wheeler-Nicholson
949	Dana Wynter
950	Daniel Baldwin
951	Daniel Benzali
952	Daniel Briquet
953	Daniel BrÃ¼hl
954	Daniel Craig
955	Daniel Day-Lewis
956	Daniel Hugh Kelly
957	Daniel Okrent
958	Daniel Olbrychski
959	Daniel Pollock
960	Daniel Shalikar
961	Daniel Southern
962	Daniel Stern
963	Daniel von Bargen
964	Daniela Bianchi
965	Danielle Panabaker
966	Danielle von Zerneck
967	Danny Aiello
968	Danny De La Paz
969	Danny DeVito
970	Danny Dyer
971	Danny Glover
972	Danny Huston
973	Danny Kaye
974	Danny Lloyd
975	Danny Mann
976	Danny McCarthy
977	Danny Mummert
978	Danny Pintauro
979	Danny Schiller
980	Danny Trejo
981	Dany Robin
982	Daphne Anderson
983	Daphne Zuniga
984	Daria Halprin
985	Daria Nicolodi
986	Darin Heames
987	Darla Hood
988	Darlene Cates
989	Darren Dalton
990	Darren McGavin
991	Darren Robinson
992	Darwyn Carson
993	Daryl Hannah
994	Dave Chappelle
995	Dave Goelz
996	David Alan Grier
997	David Andrews
998	David Arkin
999	David Arnott
1000	David Arquette
1001	David Bennent
1002	David Bowe
1003	David Bowie
1004	David Carradine
1005	David Caruso
1006	David Clennon
1007	David Colin Jr.
1008	David Conrad
1009	David Della Rocco
1010	David Duchovny
1011	David Emge
1012	David Essex
1013	David Farrar
1014	David Frankham
1015	David Gale
1016	David Gallagher
1017	David Gant
1018	David Graf
1019	David Gulpilil
1020	David Hedison
1021	David Hemmings
1022	David Huffman
1023	David Janssen
1024	David Keith
1025	David Kelly
1026	David Kossoff
1027	David Labiosa
1028	David Manners
1029	David Margulies
1030	David Marshall Grant
1031	David McCallum
1032	David McKay
1033	David Michael Williamson
1034	David Miller
1035	David Morse
1036	David Naughton
1037	David Niven
1038	David Proval
1039	David Prowse
1040	David Rappaport
1041	David Rott
1042	David Samson
1043	David Schwimmer
1044	David Soul
1045	David Spade
1046	David Strathairn
1047	David Tennant
1048	David Thewlis
1049	David Tomlinson
1050	David Tress
1051	David Warner
1052	David Wayne
1053	David Wenham
1054	David Wood
1055	Dawn Anderson
1056	Dayle Haddon
1057	DeForest Kelly
1058	Dean Cain
1059	Dean Jagger
1060	Dean Jones
1061	Dean Martin
1062	Dean Stockwell
1063	Debbie Reynolds
1064	Debi Mazar
1065	Deborah Ann Woll
1066	Deborah Harry
1067	Deborah Kara Unger
1068	Deborah Kerr
1069	Deborah Moore
1070	Deborah Rennard
1071	Deborah Richter
1072	Deborah Shelton
1073	Deborah Walley
1074	Deborra-Lee Furness
1075	Debra Deliso
1076	Debra Feuer
1077	Debra Paget
1078	Debra Winger
1079	Dee Wallace-Stone
1080	Deep Roy
1081	Delia Boccardo
1082	Delle Bolton
1083	Delphine Seyrig
1084	Delroy Lindo
1085	Demi Moore
1086	Denholm Elliott
1087	Denis Lawson
1088	Denis Leary
1089	Denis O'Hare
1090	Denise Crosby
1091	Denise Darcel
1092	Denise Richards
1093	Dennis Busch
1094	Dennis Dugan
1095	Dennis Dun
1096	Dennis Farina
1097	Dennis Franz
1098	Dennis Haysbert
1099	Dennis Hoey
1100	Dennis Hopper
1101	Dennis King
1102	Dennis Lotis
1103	Dennis Miller
1104	Dennis Morgan
1105	Dennis O'Keefe
1106	Dennis Price
1107	Dennis Quaid
1108	Dennis Rodman
1109	Dennis StorhÃ¸i
1110	Dennis Weaver
1111	Denver Pyle
1112	Denys Hawthorne
1113	Denzel Washington
1114	Derek Bond
1115	Derek Elphinstone
1116	Derek Jacobi
1117	Derek de Lint
1118	Dermot Mulroney
1119	Derrick De Marney
1120	Des McAleer
1121	Desmond Tester
1122	Dexter Fletcher
1123	Diana Dors
1124	Diana KÃ¶rner
1125	Diana Rigg
1126	Diana Ross
1127	Diane Baker
1128	Diane Clare
1129	Diane Keaton
1130	Diane Kruger
1131	Diane Ladd
1132	Diane Lane
1133	Diane Pershing
1134	Diane Salinger
1135	Diane Varsi
1136	Diane Venora
1137	Dianna Agron
1138	Dianne Wiest
1139	Dick Foran
1140	Dick Haymes
1141	Dick Powell
1142	Dick Rude
1143	Dick Sargent
1144	Dick Shawn
1145	Dick Van Dyke
1146	Dick York
1147	Dick van Dyke
1148	Diedrich Bader
1149	Diego Sieres
1150	Dina Merrill
1151	Dina Meyer
1152	Dirk Bogarde
1153	Diva Gray
1154	Divine
1155	Djiby Soumare
1156	Djimon Hounsou
1157	Do Thi Hai Yen
1158	DobrosÅ‚aw Mater
1159	Dolly Parton
1160	Dolly Read
1161	Dolores Costello
1162	Dolores Dorn
1163	Dolores Gray
1164	Dolores Moran
1165	Dolph Lundgren
1166	Dom DeLuise
1167	Dominic Purcell
1168	Dominique Dunne
1169	Dominique Pinon
1170	Dominique Sanda
1171	Dominique Swain
1172	Don Alder
1173	Don Alvarado
1174	Don Ameche
1175	Don Borisenko
1176	Don Cheadle
1177	Don DeFore
1178	Don Diamond
1179	Don Dillaway
1180	Don Duong
1181	Don Gordon
1182	Don Harvey
1183	Don Johnson
1184	Don McKellar
1185	Don Pedro Colley
1186	Don Rickles
1187	Don Steele
1188	Don Stroud
1189	Don Taylor
1190	Don Thompson
1191	Donal Logue
1192	Donal O'Kelly
1193	Donald Calthrop
1194	Donald Crisp
1195	Donald Curtis
1196	Donald Gibb
1197	Donald Moffat
1198	Donald O'Connor
1199	Donald Pleasence
1200	Donald Sutherland
1201	Donald Wolfit
1202	Donald Woods
1203	Donna Dixon
1204	Donna Reed
1205	Donna Wilkens
1206	Donnie Wahlberg
1207	Donovan Leitch
1208	Dora Bryan
1209	Dorian Harewood
1210	Doris Davenport
1211	Doris Day
1212	Doris Hare
1213	Doris Lloyd
1214	Doro Merande
1215	Dorothy Dandridge
1216	Dorothy Hart
1217	Dorothy Hyson
1218	Dorothy Malone
1219	Dorothy Patrick
1220	Dorothy Provine
1221	Dorothy Tutin
1222	Dorsey Wright
1223	Doug E. Doug
1224	Doug McClure
1225	Doug McKeon
1226	Douglas Fairbanks Jr.
1227	Douglas Fowley
1228	Douglas Spencer
1229	Douglas Wilmer
1230	Dougray Scott
1231	Dre Puhich
1232	Drew Barrymore
1233	Duane Jones
1234	Dudley Moore
1235	Duilio del Prete
1236	Duke Moore
1237	Duncan Regehr
1238	Dustin Hoffman
1239	Dwayne Hickman
1240	Dwayne Johnson
1241	Dwight Frye
1242	Dwight Yoakam
1243	Dyan Cannon
1244	Dyana Ortelli
1245	Dylan Baker
1246	Dylan McDermott
1247	Dylan Walsh
1248	E.G. Marshall
1249	Earl Holliman
1250	Earl Pastko
1251	Earl Rowe
1252	Earle Foxe
1253	Eartha Kitt
1254	Ed Begley
1255	Ed Begley Jr.
1256	Ed Bernard
1257	Ed Flanders
1258	Ed Harris
1259	Ed Lauter
1260	Ed O'Neill
1261	Ed Quinn
1262	Eddie Albert
1263	Eddie Barth
1264	Eddie Firestone
1265	Eddie Griffin
1266	Eddie Marsan
1267	Eddie Mayehoff
1268	Eddie Murphy
1269	Eddie â€ºRochesterâ€¹ Anderson
1270	Edgar Allan Woolf
1271	Edgar Buchanan
1272	Edgar Kennedy
1273	Edie Adams
1274	Edie Falco
1275	Edith Evans
1276	Edith Massey
1277	Edmond O'Brien
1278	Edmond O`Brian
1279	Edmund Breon
1280	Edmund Gwenn
1281	Edmund MacDonald
1282	Edouard Nikitine
1283	Eduard von Winterstein
1284	Eduardo Ciannelli
1285	Edward Albert
1286	Edward Andrews
1287	Edward Arnold
1288	Edward Asner
1289	Edward Burns
1290	Edward Byrnes
1291	Edward Chapman
1292	Edward Everett Horton
1293	Edward Fox
1294	Edward Furlong
1295	Edward G. Robinson
1296	Edward G. Robinson Jr.
1297	Edward Herrmann
1298	Edward James Olmos
1299	Edward Judd
1300	Edward Norton
1301	Edward Power
1302	Edward Rigby
1303	Edward Woodward
1304	Efrem Zimbalist Jr.
1305	Eileen Atkins
1306	Eileen Brennan
1307	Eileen Heckart
1308	Eiros
1309	Ekkehardt Belle
1310	Elaine Hendrix
1311	Elana Eden
1312	Elden Henson
1313	Eleanor Bron
1314	Eleanor Parker
1315	Elena Lyandres
1316	Elga Andersen
1317	Eli Wallach
1318	Elias Koteas
1319	Elijah Wood
1320	Elisabeth Bergner
1321	Elisabeth Shue
1322	Elisha Cuthbert
1323	Elissa Landi
1324	Elizabeth A. Jaeger
1325	Elizabeth Ashley
1326	Elizabeth Banks
1327	Elizabeth Berkley
1328	Elizabeth Berridge
1329	Elizabeth Daily
1330	Elizabeth Hurley
1331	Elizabeth Lawrence
1332	Elizabeth McGovern
1333	Elizabeth Perkins
1334	Elizabeth PeÃ±a
1335	Elizabeth Reaser
1336	Elizabeth Taylor
1337	Elke Sommer
1338	Ella Raines
1339	Elle Macpherson
1340	Ellen Barkin
1341	Ellen Burstyn
1342	Ellen DeGeneres
1343	Ellen Drew
1344	Ellen Greene
1345	Ellen Hamilton Latzen
1346	Ellen Page
1347	Ellen Sandweiss
1348	Ellen Widmann
1349	Ellie Raab
1350	Elliott Gould
1351	Elliott Grey
1352	Elliott Reid
1353	Elpidia Carrillo
1354	Elroy 'Crazylegs' Hirsch
1355	Elsa Lancaster
1356	Elsa Lanchester
1357	Elsa Martinelli
1358	Elton John
1359	Elvis Presley
1360	Embeth Davidtz
1361	Emer Mccourt
1362	Emil Jannings
1363	Emil Marwa
1364	Emile Hirsch
1365	Emilie de Ravin
1366	Emilio Estevez
1367	Emily Ann Lloyd
1368	Emily Blunt
1369	Emily Browning
1370	Emily Lloyd
1371	Emily Shelton
1372	Emily Watson
1373	Emma Caulfield
1374	Emma Danieli
1375	Emma SjÃ¶berg
1376	Emma Thompson
1377	Emmanuelle BÃ©art
1378	Emmanuelle Seigner
1379	Enrique Castillo
1380	Enver Gjokaj
1381	Eric Bogosian
1382	Eric Christmas
1383	Eric Idle
1384	Eric Porter
1385	Eric Roberts
1386	Eric Schweig
1387	Eric Stoltz
1388	Eric Thal
1389	Erich von Stroheim
1390	Erik Rhodes
1391	Erika Eleniak
1392	Erika Gabaldon
1393	Erinn Bartlett
1394	Erland Josephson
1395	Erna Haffner
1396	Ernest Borgnine
1397	Ernest Thesiger
1398	Ernest Torrence
1399	Ernie Dingo
1400	Ernie Hudson
1401	Ernie Kovacs
1402	Ernst-Hugo JÃ¤regÃ¥rd
1403	Errol Flynn
1404	Eru Potaka-Dewes
1405	Esai Morales
1406	Esha Deol
1407	Esmond Knight
1408	Essie Davis
1409	Essy Persson
1410	Estella Warren
1411	Estelle Getty
1412	Estelle Parsons
1413	Estelle Taylor
1414	Esther Williams
1415	Eszter Balint
1416	Ethan Embry
1417	Ethan Hawke
1418	Ethan Phillips
1419	Ethan Randall
1420	Ethel Waters
1421	Eugene Brell
1422	Eugene Levy
1423	Eugene Pallette
1424	Eugenie Besserer
1425	Eunice Gayson
1426	Eva Bartok
1427	Eva Green
1428	Eva Igo
1429	Eva Longoria Parker
1430	Eva Marie Saint
1431	Eva Mendes
1432	Evan C. Kim
1433	Eve Arden
1434	Eve Gordon
1435	Evelyn Del Rio
1436	Evelyn Keyes
1437	Everett McGill
1438	Everett Sloane
1439	Ewan McGregor
1440	Ewen Bremner
1441	F. Murray Abraham
1442	Fabian Forte
1443	Fabiana Udenio
1444	Fabio Testi
1445	Fairuza Balk
1446	Faith Domergue
1447	Famke Janssen
1448	Fardeen Khan
1449	Farley Granger
1450	Farrah Fawcett
1451	Fay Bainter
1452	Fay Compton
1453	Fay Wray
1454	Faye Dunaway
1455	Felicia Farr
1456	Felipe Pazos
1457	Felix Bressart
1458	Fernando Rey
1459	Finlay Currie
1460	Finn Carter
1461	Fintan Halpenny
1462	Fiona Hutchison
1463	Fiona Lewis
1464	Fiona Shaw
1465	Fionnula Flanagan
1466	Fisher Stevens
1467	Flea
1468	Flora Robson
1469	Forest Whitaker
1470	Forrest Tucker
1471	Fran Drescher
1472	Franca Bettoia
1473	Frances Bay
1474	Frances Conroy
1475	Frances Fisher
1476	Frances McDormand
1477	Frances O'Connor
1478	Frances Oâ€™Connor
1479	Frances Sternhagen
1480	Francesca Annis
1481	Francesca Brown
1482	Francis Capra
1483	Francis Matthews
1484	Francisco P. Cardoza
1485	Franco Interlenghi
1486	Francois Barre-Sinnousi
1487	Frank Adu
1488	Frank C. Turner
1489	Frank Finlay
1490	Frank Gallacher
1491	Frank Langella
1492	Frank Lovejoy
1493	Frank Maxwell
1494	Frank McHugh
1495	Frank McRae
1496	Frank Morgan
1497	Frank Oz
1498	Frank Puglia
1499	Frank Reicher
1500	Frank Shannon
1501	Frank Silvera
1502	Frank Sinatra
1503	Frank Vincent
1504	Frank Whaley
1505	Frankie Avalon
1506	Frankie Thorn
1507	Franklyn Seales
1508	FranÃ§ois BerlÃ©and
1509	FranÃ§ois Truffaut
1510	FranÃ§oise DorlÃ©ac
1511	FranÃ§oise Rosay
1512	Fred Astaire
1513	Fred Clark
1514	Fred Gwynne
1515	Fred MacMurray
1516	Fred Savage
1517	Fred Stone
1518	Fred Ward
1519	Freddie Jones
1520	Freddie Prinze Jr.
1521	Freddy RodrÃ­guez
1522	Frederic Forrest
1523	Frederick Coffin
1524	Frederick Combs
1525	Frederick Forrest
1526	Frederick Piper
1527	Frederick Stafford
1528	Fredric March
1529	Fritz Weaver
1530	FrÃ©dÃ©ric Diefenthal
1531	FrÃ©dÃ©rique Bel
1532	Fulton Mackay
1533	Fyvush Finkel
1534	Gabriel Byrne
1535	Gabriel Casseus
1536	Gabriel Macht
1537	Gabriele Ferzetti
1538	Gabrielle Anwar
1539	Gabrielle Carteris
1540	Gabrielle Fitzpatrick
1541	Gabrielle Rose
1542	Gaby Hoffmann
1543	Gail O'Grady
1544	Gail Russell
1545	Gailard Sartain
1546	Gale Hansen
1547	Gale Sondergaard
1548	Garret Dillahunt
1549	Gary Bakewell
1550	Gary Busey
1551	Gary Cole
1552	Gary Cooper
1553	Gary Daniels
1554	Gary Farmer
1555	Gary Lahti
1556	Gary Littlejohn
1557	Gary Lockwood
1558	Gary Merrill
1559	Gary Oldman
1560	Gary Sinise
1561	Gawn Grainger
1562	Gaye Brown
1563	Gayle Hunnicutt
1564	Gaylen Ross
1565	Geena Davis
1566	Gemma Phoenix
1567	Gena Rowlands
1568	Gene Barry
1569	Gene Davis
1570	Gene Dynarski
1571	Gene Evans
1572	Gene Hackman
1573	Gene Kelly
1574	Gene Lockhart
1575	Gene Simmons
1576	Gene Tierney
1577	Gene Wilder
1578	GeneviÃ¨ve Bujold
1579	GeneviÃ¨ve Page
1580	Geoffrey Lewis
1581	Geoffrey Pierson
1582	Geoffrey Rush
1583	Geoffrey Toone
1584	George 'Buck' Flower
1585	George 'Red' Schwartz
1586	George Brent
1587	George C. Scott
1588	George Chakiris
1589	George Clooney
1590	George Coe
1591	George Cole
1592	George Dzundza
1593	George Gaynes
1594	George Grizzard
1595	George Hamilton
1596	George Harrison
1597	George Hines
1598	George Kennedy
1599	George Lazenby
1600	George Loros
1601	George Macready
1602	George Maharis
1603	George Moss
1604	George Murdock
1605	George Murphy
1606	George Nader
1607	George Newbern
1608	George Peppard
1609	George Rose
1610	George Sanders
1611	George Segal
1612	George Takei
1613	George Wendt
1614	George Wilson
1615	Georges Adet
1616	Georges Beller
1617	Georges DescriÃ¨res
1618	Georges GuÃ©tary
1619	Georgina Cates
1620	Ger Ryan
1621	Gerald Mohr
1622	Gerald R. Molen
1623	Geraldine Brooks
1624	Geraldine Chaplin
1625	Geraldine Fitzgerald
1626	Geraldine Page
1627	Geraldine Smith
1628	Gerda Nicolson
1629	Gerrit Graham
1630	Gert FrÃ¶be
1631	Gert Van den Bergh
1632	Gesine Cukrowski
1633	Gia Carides
1634	Giacomo Rossi-Stuart
1635	Giancarlo Esposito
1636	Giancarlo Giannini
1637	Gianna Maria Canale
1638	Gibson Gowland
1639	Gig Young
1640	Gigi Perreau
1641	Gila Golan
1642	Gilbert Roland
1643	Gilles SÃ©gal
1644	Gillian Anderson
1645	Gina Gershon
1646	Gina Lollobrigida
1647	Gina Mantegna
1648	Ginger Rogers
1649	Giovanni Ribisi
1650	Gisele Lindley
1651	Giuseppe Andrews
1652	Gladys George
1653	Glen Berry
1654	Glen Cavender
1655	Glenda Farrell
1656	Glenda Jackson
1657	Glenn Anders
1658	Glenn Close
1659	Glenn Ford
1660	Glenn Miller
1661	Glenn Plummer
1662	Glenn Quinn
1663	Glenne Headly
1664	Gloria Hendry
1665	Gloria Stuart
1666	Gloria Swanson
1667	Gloria Talbott
1668	Glynis Johns
1669	Godfrey Tearle
1670	Gokor Chivichyan
1671	Goldie Hawn
1672	Googie Withers
1673	Gordon Jackson
1674	Gordon Scott
1675	Gordon Warnecke
1676	Gore Vidal
1677	Grace Jones
1678	Grace Kelly
1679	Graem McGavin
1680	Graham Chapman
1681	Graham Greene
1682	Grant Cramer
1683	Grant Piro
1684	Grant Sutherland
1685	Greg Butler
1686	Greg Germann
1687	Greg Kinnear
1688	Greg Wrangler
1689	Gregg Edelman
1690	Gregg Henry
1691	Gregory Hines
1692	Gregory Jones
1693	Gregory Peck
1694	Gregory Smith
1695	Gregory Sporleder
1696	Gregory Walcott
1697	Greta Garbo
1698	Greta Lind
1699	Greta Scacchi
1700	Gretchen Corbett
1701	Gretchen Mol
1702	Griff Barnett
1703	Griffin Dunne
1704	Groucho Marx
1705	Grover Dale
1706	Guillaume Canet
1707	Guillermo DÃ­az
1708	Guy Davis
1709	Guy Madison
1710	Guy Pearce
1711	Guy Rolfe
1712	Guy Stockwell
1713	Gwen McGee
1714	Gwen Welles
1715	Gwyneth Paltrow
1716	Gyurme Tethong
1717	GÃ©raldine Pailhas
1718	GÃ©rard Barray
1719	GÃ©rard Depardieu
1720	GÃ¼nther Haack
1721	H.B. Halicki
1722	Hailee Steinfeld
1723	Haing S. Ngor
1724	Haji
1725	Hal Holbrook
1726	Haley Joel Osment
1727	Halle Berry
1728	Ham Larsen
1729	Hana Maria Pravda
1730	Hank Azaria
1731	Hank B. Marvin
1732	Hanna Schygulla
1733	Hannah Taylor-Gordon
1734	Hannes Jaenicke
1735	Hanno PÃ¶schl
1736	Hans Conried
1737	Hans Man in 't Veld
1738	Hans Strydom
1739	HansjÃ¶rg Felmy
1740	Hardy KrÃ¼ger
1741	Hardy KrÃ¼ger Jr.
1742	Hark Bohm
1743	Harlan Warde
1744	Harland Williams
1745	Harley Jane Kozak
1746	Harold Gould
1747	Harold J. Stone
1748	Harold Perrineau
1749	Harold Ramis
1750	Harold Warrender
1751	Harpo Marx
1752	Harriet Lenabe
1753	Harrison Ford
1754	Harrison Page
1755	Harry Andrews
1756	Harry Belafonte
1757	Harry Bellaver
1758	Harry Connick Jr.
1759	Harry Crosby
1760	Harry Dean Stanton
1761	Harry Eden
1762	Harry Ellerbe
1763	Harry Guardino
1764	Harry H. Corbett
1765	Harry Hadden-Paton
1766	Harry Hamlin
1767	Harry Liedtke
1768	Harry Morgan
1769	Hart Bochner
1770	Hartley Power
1771	Harve Presnell
1772	Harvey Fierstein
1773	Harvey Keitel
1774	Harvey Korman
1775	Hattie Jacques
1776	Haviland Morris
1777	Haya Harareet
1778	Hayden Rorke
1779	Hayley Mills
1780	Hazel Court
1781	Heath Ledger
1782	Heather Angel
1783	Heather Donahue
1784	Heather Graham
1785	Heather Langenkamp
1786	Heather Locklear
1787	Heather Matarazzo
1788	Heather Mitchell
1789	Heather O'Rourke
1790	Hector Elizondo
1791	Hedy Lamarr
1792	Heidi Kling
1793	Heidi von Palleske
1794	Heike Makatsch
1795	Helen Boston
1796	Helen Chandler
1797	Helen Flint
1798	Helen Hayes
1799	Helen Hunt
1800	Helen Mirren
1801	Helen Morse
1802	Helen Shaver
1803	Helen Slater
1804	Helen Vinson
1805	Helena BergstrÃ¶m
1806	Helena Bonham Carter
1807	Helena Carter
1808	Helena Kallianiotes
1809	Helmut Griem
1810	Henry Beckman
1811	Henry Czerny
1812	Henry Edwards
1813	Henry Fonda
1814	Henry Gibson
1815	Henry Hull
1816	Henry Jones
1817	Henry Rollins
1818	Henry Silva
1819	Henry Thomas
1820	Henry Travers
1821	Henry Winkler
1822	Herb Edelman
1823	Herbert Lom
1824	Herbert Marshall
1825	Herschel Bernardi
1826	HervÃ© Villechaize
1827	Hetta Charnley
1828	Hetty Bower
1829	Heydon Prowse
1830	Hideo Sakaki
1831	Hidetoshi Nishijima
1832	Hilary Mason
1833	Hilary Swank
1834	Hildegard Knef
1835	Hildegarde Neil
1836	Hobart Bosworth
1837	Holly Hunter
1838	Holly Marie Combs
1839	Hollye Holmes
1840	Honor Blackman
1841	Hope Davis
1842	Hope Lange
1843	Horst Buchholz
1844	Horst Janson
1845	Horst Schulze
1846	Howard Da Silva
1847	Howard Keel
1848	Howard Lloyd-Lewis
1849	Howard Stern
1850	Hoyt Axton
1851	Hugh B. Holub
1852	Hugh Beaumont
1853	Hugh Dillon
1854	Hugh Edwards
1855	Hugh Fraser
1856	Hugh Grant
1857	Hugh Griffith
1858	Hugh Keays-Byrne
1859	Hugh Laurie
1860	Hugh Marlowe
1861	Hugh O'Brian
1862	Hugh Sinclair
1863	Hughie Restorick
1864	Hugo Weaving
1865	Hume Cronyn
1866	Humphrey Bogart
1867	Hunter Carson
1868	Hurd Hatfield
1869	Hyeon-jun Shin
1870	Hylda Baker
1871	Hywell Bennett
1872	HÃ©lÃ¨ne Vincent
1873	Iain Glen
1874	Iain Quarrier
1875	Ian Abercrombie
1876	Ian Bannen
1877	Ian Charleson
1878	Ian Hart
1879	Ian Hendry
1880	Ian Holm
1881	Ian Hunter
1882	Ian McDiarmid
1883	Ian Richardson
1884	Ice Cube
1885	Ice-T
1886	Igor Petrenko
1887	Ihsa Koppikar
1888	Ike Eisenmann
1889	Ilan Mitchell-Smith
1890	Illeana Douglas
1891	Ilona Elkin
1892	Ilona Massey
1893	Iman
1894	Imogen Claire
1895	Ina Balin
1896	Inga Swenson
1897	Inge Landgut
1898	Inger Stevens
1899	Ingrid Bergman
1900	Ione Skye
1901	Irene Bedard
1902	Irene Cara
1903	Irene Champlin
1904	Irene Dunne
1905	Irene Kane
1906	Irene Miracle
1907	Irene Worth
1908	Iris Adrian
1909	Iris Churn
1910	Irving Metzman
1911	Isabel Glasser
1912	Isabell Jewell
1913	Isabella Rossellini
1914	Isabelle Adjani
1915	Isabelle De Valvert
1916	Isabelle Huppert
1917	Isaiah Washington
1918	Isela Vega
1919	Ivan Bonar
1920	Ivan Rassimov
1921	Ivana Milicevic
1922	Izabella Scorupco
1923	J. Carrol Naish
1924	J. Trevor Edmond
1925	J.D. Cannon
1926	J.E. Freeman
1927	J.L. Reate
1928	J.T. Walsh
1929	Jacinda Barrett
1930	Jack Benny
1931	Jack Black
1932	Jack Carson
1933	Jack Cassidy
1934	Jack Elam
1935	Jack Hawkins
1936	Jack Kehoe
1937	Jack Klugman
1938	Jack Kruschen
1939	Jack Lambert
1940	Jack Lemmon
1941	Jack Lord
1942	Jack MacGowran
1943	Jack McClelland
1944	Jack Mullaney
1945	Jack Nance
1946	Jack Nicholson
1947	Jack Oakie
1948	Jack Palance
1949	Jack Thibeau
1950	Jack Thompson
1951	Jack Warden
1952	Jack Warner
1953	Jack Webb
1954	Jack Weston
1955	Jackie Chan
1956	Jackie Coogan
1957	Jackie Cooper
1958	Jackie Gleason
1959	Jackie Guerra
1960	Jackie Lyn Dufton
1961	Jackie Sawiris
1962	Jackson Hurst
1963	Jacqueline Bisset
1964	Jacqueline McKenzie
1965	Jacqueline Obradors
1966	Jacqueline Pearce
1967	Jacqueline Sassard
1968	Jacqueline Tong
1969	Jacquelyn Hyde
1970	Jacques Roux
1971	Jacques Weber
1972	Jada Pinkett Smith
1973	Jaime King
1974	Jake Blundell
1975	Jake Busey
1976	Jake Gyllenhaal
1977	Jakob Cedergren
1978	James Arness
1979	James Aubrey
1980	James Badge Dale
1981	James Belushi
1982	James Bolam
1983	James Booth
1984	James Broderick
1985	James Brolin
1986	James Brown
1987	James Caan
1988	James Cagney
1989	James Caitlin
1990	James Carpenter
1991	James Coburn
1992	James Coco
1993	James Craig
1994	James Cromwell
1995	James Dean
1996	James Donald
1997	James Doohan
1998	James Duval
1999	James Earl Jones
2000	James Edwards
2001	James Fillmore
2002	James Fleet
2003	James Fox
2004	James Franciscus
2005	James Gammon
2006	James Gandolfini
2007	James Garner
2008	James Gleason
2009	James Hampton
2010	James Hong
2011	James Keach
2012	James Larkin
2013	James LeGros
2014	James Madio
2015	James Mason
2016	James McAvoy
2017	James McIntyre
2018	James Olson
2019	James Purefoy
2020	James Rebhorn
2021	James Remar
2022	James Robertson Justice
2023	James Russo
2024	James Sikking
2025	James Simmons
2026	James Spader
2027	James Stacy
2028	James Stewart
2029	James Villiers
2030	James Whitmore
2031	James Woods
2032	Jameson Parker
2033	Jamey Sheridan
2034	Jami Gertz
2035	Jamie Bell
2036	Jamie Foreman
2037	Jamie Foxx
2038	Jamie Gillis
2039	Jamie Lee Curtis
2040	Jamie RenÃ©e Smith
2041	Jamie Smith
2042	Jamyang Jamtsho Wangchuk
2043	Jan Rubes
2044	Jan Stuart Schwartz
2045	Jan-Michael Vincent
2046	Jana Taylor
2047	Jane Adams
2048	Jane Alexander
2049	Jane Asher
2050	Jane Birkin
2051	Jane Curtin
2052	Jane Darwell
2053	Jane Fonda
2054	Jane Galloway Heitz
2055	Jane Greer
2056	Jane Horrocks
2057	Jane Krakowski
2058	Jane Merrow
2059	Jane Mortifee
2060	Jane Randolph
2061	Jane Rose
2062	Jane Russell
2063	Jane Seymour
2064	Jane Wyman
2065	Janeane Garofalo
2066	Janet Bartley
2067	Janet Jones
2068	Janet Landgard
2069	Janet Leigh
2070	Janet Margolin
2071	Janet Munro
2072	Janet Suzman
2073	Janette Scott
2074	Janice Logan
2075	Janina Sachau
2076	Janine Turner
2077	Janusz PawÅ‚ak
2078	Jared Harris
2079	Jared Leto
2080	Jared Padalecki
2081	Jarlath Conroy
2082	Jarmila Novotna
2083	Jasen Fisher
2084	Jason Alexander
2085	Jason Beghe
2086	Jason Biggs
2087	Jason Durr
2088	Jason Gedrick
2089	Jason Isaacs
2090	Jason James Richter
2091	Jason Lee
2092	Jason Lively
2093	Jason London
2094	Jason Mewes
2095	Jason Miller
2096	Jason Patric
2097	Jason Priestley
2098	Jason Robards
2099	Jason Schwartzman
2100	Jason Scott Lee
2101	Jason Statham
2102	Jay C. Flippen
2103	Jay Mohr
2104	Jay O. Sanders
2105	Jay Patterson
2106	Jay Thomas
2107	Jayne Mansfield
2108	Jean Adair
2109	Jean Anderson
2110	Jean Arthur
2111	Jean Brooks
2112	Jean Carson
2113	Jean Hagen
2114	Jean Lenauer
2115	Jean Louisa Kelly
2116	Jean Marsh
2117	Jean Peters
2118	Jean Reno
2119	Jean Rogers
2120	Jean Seberg
2121	Jean Simmons
2122	Jean Taylor Smith
2123	Jean Wallace
2124	Jean Yanne
2125	Jean-Claude Van Damme
2126	Jean-FranÃ§ois Balmer
2127	Jean-Hugues Anglade
2128	Jean-Marc Barr
2129	Jean-Pierre Cassel
2130	Jean-Pierre LÃ©aud
2131	Jeanne Mauborgne
2132	Jeanne Moreau
2133	Jeanne Tripplehorn
2134	Jeannie Elias
2135	Jeff Anderson
2136	Jeff Bridges
2137	Jeff Cadiente
2138	Jeff Chandler
2139	Jeff Chase
2140	Jeff Cohen
2141	Jeff Conaway
2142	Jeff Daniels
2143	Jeff Fahey
2144	Jeff Goldblum
2145	Jeff Morrow
2146	Jeffrey Allen
2147	Jeffrey Combs
2148	Jeffrey Falcon
2149	Jeffrey Force
2150	Jeffrey Hunter
2151	Jeffrey Jones
2152	Jeffrey Tambor
2153	Jeffrey Wright
2154	Jena Malone
2155	Jenna Elfman
2156	Jennie Linden
2157	Jennifer Aniston
2158	Jennifer Baxter
2159	Jennifer Beals
2160	Jennifer Billingsley
2161	Jennifer Clay
2162	Jennifer Connelly
2163	Jennifer Coolidge
2164	Jennifer Dale
2165	Jennifer Daniel
2166	Jennifer Delora
2167	Jennifer Ehle
2168	Jennifer Esposito
2169	Jennifer Garner
2170	Jennifer Grey
2171	Jennifer Jason Leigh
2172	Jennifer Jones
2173	Jennifer Lopez
2174	Jennifer Love Hewitt
2175	Jennifer O'Neill
2176	Jennifer Rubin
2177	Jennifer Salt
2178	Jennifer Saunders
2179	Jennifer Tilly
2180	Jennifer Warren
2181	Jenny Agutter
2182	Jenny Levine
2183	Jenny Lewis
2184	Jenny Runacre
2185	Jenny Wright
2186	Jensen Ackles
2187	Jeremy Davies
2188	Jeremy Irons
2189	Jeremy Kemp
2190	Jeremy Lloyd
2191	Jeremy London
2192	Jeremy Northam
2193	Jeremy Piven
2194	Jeremy Sisto
2195	Jeremy Slate
2196	Jeremy Theobald
2197	Jeroen KrabbÃ©
2198	Jerome Eden
2199	Jerry Adler
2200	Jerry Butler
2201	Jerry Daugirda
2202	Jerry Kemp
2203	Jerry Lacy
2204	Jerry Levine
2205	Jerry Lewis
2206	Jerry Mayer
2207	Jerry Nelson
2208	Jerry O'Connell
2209	Jerry Orbach
2210	Jerry Reed
2211	Jerry Stiller
2212	Jesse Borrego
2213	Jesse Bradford
2214	Jesse James
2215	Jesse Metcalfe
2216	Jesse Vint
2217	Jesse White
2218	Jessica Bowman
2219	Jessica Campbell
2220	Jessica Harper
2221	Jessica Lange
2222	Jessica Stroup
2223	Jessica Tandy
2224	Jessie Matthews
2225	Jessie Royce Landis
2226	Jharana Das
2227	Jill Clayburgh
2228	Jill Haworth
2229	Jill Ireland
2230	Jill St. John
2231	Jim Armenti
2232	Jim Backus
2233	Jim Breuer
2234	Jim Broadbent
2235	Jim Brown
2236	Jim Carrey
2237	Jim Carter
2238	Jim Dale
2239	Jim Farley
2240	Jim Henson
2241	Jim Hutton
2242	Jim McKrell
2243	Jim R. Coleman
2244	Jim Varney
2245	Jim Watkins
2246	Jimi Mistry
2247	Jimmi Harkishin
2248	Jimmy Cliff
2249	Jimmy Nail
2250	Jimmy Somerville
2251	Jo Morrow
2252	Jo Van Fleet
2253	Jo-Ann Robinson
2254	JoBeth Williams
2255	Joachim Fuchsberger
2256	Joan Allen
2257	Joan Bennett
2258	Joan Blondell
2259	Joan Chen
2260	Joan Collins
2261	Joan Crawford
2262	Joan Cusack
2263	Joan Fontaine
2264	Joan Freeman
2265	Joan Greenwood
2266	Joan Hackett
2267	Joan Hapkett
2268	Joan Jett
2269	Joan Lorring
2270	Joan O'Brien
2271	Joan Plowright
2272	Joan Severance
2273	Joan Sims
2274	Joan Taylor
2275	Joan Van Ark
2276	Joan Weldon
2277	Joanasie Salamonie
2278	Joanna Cassidy
2279	Joanna Gleason
2280	Joanna Pacula
2281	Joanna Pettet
2282	Joanne Dru
2283	Joanne Samuel
2284	Joanne Whalley
2285	Joannelle Nadine Romero
2286	Joaquim de Almeida
2287	Joaquin Phoenix
2288	Jocelyn Lane
2289	Jock Mahoney
2290	Jodie Foster
2291	Joe Anderson
2292	Joe Aubel
2293	Joe Benoit
2294	Joe Breen
2295	Joe Dallesandro
2296	Joe Don Baker
2297	Joe E. Brown
2298	Joe Eales
2299	Joe Grifasi
2300	Joe Mantegna
2301	Joe Morton
2302	Joe Pantoliano
2303	Joe Pesci
2304	Joe Robinson
2305	Joe Strummer
2306	Joel Brooks
2307	Joel Grey
2308	Joel McCrea
2309	Joel Moore
2310	Joel Murray
2311	Joely Richardson
2312	Joey Bishop
2313	Joey Cramer
2314	Joey Heatherton
2315	Joey Lauren Adams
2316	Joey Ramone
2317	Johan Rabaeus
2318	Johanna Day
2319	Johanna Lixey
2320	John Adames
2321	John Agar
2322	John Alderton
2323	John Allen Nelson
2324	John Amos
2325	John Ashton
2326	John Barrymore
2327	John Beck
2328	John Belushi
2329	John Boylan
2330	John Bromfield
2331	John Buckwalter
2332	John C. McGinley
2333	John C. Reilly
2334	John Cameron Mitchell
2335	John Candy
2336	John Carradine
2337	John Carroll Lynch
2338	John Cassavetes
2339	John Cassisi
2340	John Castle
2341	John Cazale
2342	John Cleese
2343	John Colicos
2344	John Collin
2345	John Cullum
2346	John Cusack
2347	John Dall
2348	John David Carson
2349	John Diel
2350	John Doe
2351	John Fiedler
2352	John Finnegan
2353	John Forsythe
2354	John Fraser
2355	John Friedrich
2356	John Furey
2357	John Garfield
2358	John Gavin
2359	John Getz
2360	John Gielgud
2361	John Glover
2362	John Goodman
2363	John Gregson
2364	John Hallam
2365	John Hannah
2366	John Harkins
2367	John Heard
2368	John Hillerman
2369	John Hodiak
2370	John Houseman
2371	John Howard
2372	John Hubbard
2373	John Hurt
2374	John Huston
2375	John Ireland
2376	John Justin
2377	John Kani
2378	John Kapelos
2379	John Kerr
2380	John Larroquette
2381	John Lawrence
2382	John Lazar
2383	John Le Mesurier
2384	John Leguizamo
2385	John Lennon
2386	John Leyton
2387	John Limnidis
2388	John Lithgow
2389	John Loder
2390	John Lone
2391	John Longden
2392	John Louie
2393	John Lund
2394	John Lurie
2395	John Lynch
2396	John Mahoney
2397	John Malkovich
2398	John Marley
2399	John Matthews
2400	John McEnery
2401	John McGiver
2402	John McGuire
2403	John McIntire
2404	John McMartin
2405	John Meillon
2406	John Mills
2407	John Morris
2408	John Moulder-Brown
2409	John Mylong
2410	John Nolan
2411	John Omirah Miluwi
2412	John Osborne
2413	John P. Ryan
2414	John Pankow
2415	John Payne
2416	John Phillip Law
2417	John Pyper Ferguson
2418	John Randolph Jones
2419	John Ratzenberger
2420	John Rhys-Davies
2421	John Richardson
2422	John Ridgely
2423	John Ritter
2424	John Roselius
2425	John Russell
2426	John Savage
2427	John Saxon
2428	John Simm
2429	John Smith
2430	John Spencer
2431	John Steiner
2432	John Stockwell
2433	John Stuart
2434	John Sutton
2435	John Terry
2436	John Travolta
2437	John Turturro
2438	John Vernon
2439	John Warwick
2440	John Wayne
2441	John Wildman
2442	John Williams
2443	John Witherspoon
2444	John Wood
2445	John Woodvine
2446	John Wray
2447	John Zaremba
2448	Johnathon Schaech
2449	Johnny Depp
2450	Johnny Galecki
2451	Johnny Knoxville
2452	Johnny Ramone
2453	Jon Cryer
2454	Jon Cypher
2455	Jon Favreau
2456	Jon Finch
2457	Jon Hall
2458	Jon Heder
2459	Jon Lovitz
2460	Jon Polito
2461	Jon Stewart
2462	Jon Tenney
2463	Jon Voight
2464	Jonathan Bowater
2465	Jonathan Brandis
2466	Jonathan Firth
2467	Jonathan Frakes
2468	Jonathan Hale
2469	Jonathan Haze
2470	Jonathan Hyde
2471	Jonathan Jackson
2472	Jonathan Ke Quan
2473	Jonathan Penner
2474	Jonathan Pryce
2475	Jonathan Rhys Meyers
2476	Jonathan Sagall
2477	Jonathan Scott-Taylor
2478	Jonathan Silverman
2479	Jonathan Winters
2480	Jonny Lee Miller
2481	Jordan Warkol
2482	Jordana Brewster
2483	Jorge Rivero
2484	Josef Sommer
2485	Joseph A. Carpenter
2486	Joseph Ashton
2487	Joseph Bologna
2488	Joseph Cali
2489	Joseph Calleia
2490	Joseph Campanella
2491	Joseph Chan
2492	Joseph Cotten
2493	Joseph Cotton
2494	Joseph Fiennes
2495	Joseph Gordon-Levitt
2496	Joseph Latimore
2497	Joseph Mascolo
2498	Joseph Mazzello
2499	Joseph Nash
2500	Joseph Pilato
2501	Joseph Schildkraut
2502	Joseph Scoren
2503	Joseph Wiseman
2504	Josephine Hull
2505	Josh Albee
2506	Josh Brolin
2507	Josh Charles
2508	Josh Duhamel
2509	Josh Hartnett
2510	Josh Hutcherson
2511	Josh Lucas
2512	Josh Mosby
2513	Josh Pais
2514	Josh Stewart
2515	Joshua Leonard
2516	Joshua Rudoy
2517	Josiane StolÃ©ru
2518	Joss Ackland
2519	JosÃ© Ferrer
2520	JosÃ© Lewgoy
2521	JosÃ© Wilker
2522	Joy Ann Page
2523	Joy Boushel
2524	Joyce Carey
2525	Joyce Van Patten
2526	Juan FernÃ¡ndez
2527	Juano Hernandez
2528	Judd Hirsch
2529	Judd Nelson
2530	Jude Law
2531	Judge Reinhold
2532	Judi Bowker
2533	Judi Dench
2534	Judi Meredith
2535	Judi West
2536	Judith Anderson
2537	Judith Donner
2538	Judith Hoag
2539	Judith Ivey
2540	Judith O'Dea
2541	Judith Ransdell
2542	Judson Pratt
2543	Judy Davis
2544	Judy Garland
2545	Judy Pace
2546	Judy Parfitt
2547	Julia Louis-Dreyfus
2548	Julia McNeal
2549	Julia Meade
2550	Julia Ormond
2551	Julia Roberts
2552	Julia Stiles
2553	Julian Arahanga
2554	Julian Fellowes
2555	Julian Glover
2556	Julian Mateos
2557	Julian Sands
2558	Julianne Moore
2559	Julianne Nicholson
2560	Julie Adams
2561	Julie Andrews
2562	Julie Bowen
2563	Julie Brown
2564	Julie Carmen
2565	Julie Christie
2566	Julie Cox
2567	Julie Delpy
2568	Julie Hagerty
2569	Julie Harris
2570	Julie Hughes
2571	Julie Kavner
2572	Julie London
2573	Julie Walters
2574	Julie Warner
2575	Julie-Marie Parmentier
2576	Juliet Stevenson
2577	Juliette Binoche
2578	Juliette Lewis
2579	Juliette Mills
2580	Jun Kunimura
2581	June Allyson
2582	June Carter Cash
2583	June Duprez
2584	June Havoc
2585	June Marlowe
2586	June Ritchie
2587	June Tripp
2588	Justin Braine
2589	Justin Charles Pierce
2590	Justin Gray
2591	Justin Henry
2592	Justin McGuire
2593	JÃ¶rg SchÃ¼ttauf
2594	JÃ¼rgen Prochnow
2595	Kad Merad
2596	Kadour Belkhodja
2597	Kalina Jedrusik
2598	Kareem Abdul-Jabbar
2599	Karen Allen
2600	Karen Balkin
2601	Karen Black
2602	Karen Dotrice
2603	Karen Fergusson
2604	Karen Lynn Gorney
2605	Karen Morley
2606	Karin Dor
2607	Karina Lombard
2608	Karl Fieseler
2609	Karl Hardman
2610	Karl Malden
2611	Karl Urban
2612	Karl-Michael Vogler
2613	Karlheinz BÃ¶hm
2614	Karyn Parsons
2615	Kasi Lemmons
2616	Kassie DePaiva
2617	Kate Beahan
2618	Kate Beckinsale
2619	Kate Bosworth
2620	Kate Burton
2621	Kate Capshaw
2622	Kate Hardie
2623	Kate Hudson
2624	Kate Levering
2625	Kate Maberly
2626	Kate McNeil
2627	Kate Nelligan
2628	Kate Reid
2629	Kate Winslet
2630	Kate del Castillo
2631	Katharine Hepburn
2632	Katharine Houghton
2633	Katharine Ross
2634	Katherine Heigl
2635	Katherine Helmond
2636	Katherine Squire
2637	Kathleen Beller
2638	Kathleen Harrison
2639	Kathleen Quinlan
2640	Kathleen Turner
2641	Kathryn Beaumont
2642	Kathryn Erbe
2643	Kathryn Grayson
2644	Kathryn Harrold
2645	Kathryn Marlowe
2646	Kathy Baker
2647	Kathy Bates
2648	Kathy Burke
2649	Kathy Jamieson
2650	Kathy Lester
2651	Kathy Long
2652	Kathy Najimy
2653	Katie Cassidy
2654	Katie Holmes
2655	Katie Johnson
2656	Katie Sagona
2657	Katja RupÃ©
2658	Katrin Cartlidge
2659	Kay Francis
2660	Kay Johnson
2661	Kay Kendall
2662	Kay Medford
2663	Kay Thompson
2664	Keanu Reeves
2665	Keeley Hawes
2666	Keenan Wynn
2667	Keenen Ivory Wayans
2668	Keir Dullea
2669	Keira Knightley
2670	Keith Carradine
2671	Keith Coogan
2672	Keith David
2673	Keith Gordon
2674	Keith McKeon
2675	Keith Michell
2676	Keith Stuart Thayer
2677	Kel Mitchell
2678	Kelli Maroney
2679	Kelly Bishop
2680	Kelly LeBrock
2681	Kelly Lynch
2682	Kelly McGillis
2683	Kelly Preston
2684	Kelly Reilly
2685	Kelly Rowan
2686	Kelsey Grammer
2687	Ken Berry
2688	Ken Carter
2689	Ken Cheeseman
2690	Ken Foree
2691	Ken Gampu
2692	Ken Leung
2693	Ken Marshall
2694	Ken Olandt
2695	Ken Sagoes
2696	Ken Shapiro
2697	Ken Siu
2698	Ken Stott
2699	Ken Takahura
2700	Ken Takakura
2701	Ken Wahl
2702	Kenneth Branagh
2703	Kenneth Cole
2704	Kenneth Colley
2705	Kenneth Cranham
2706	Kenneth Khambula
2707	Kenneth Mars
2708	Kenneth McMillan
2709	Kenneth More
2710	Kenneth Nelson
2711	Kenneth Tobey
2712	Kenneth Tsang
2713	Kenneth Welsh
2714	Kenneth Williams
2715	Kenny Baker
2716	Kent Smith
2717	Kerry Fox
2718	Kestie Morassi
2719	Kevin Anderson
2720	Kevin Bacon
2721	Kevin Bishop
2722	Kevin Chevalia
2723	Kevin Conroy
2724	Kevin Costner
2725	Kevin Dillon
2726	Kevin J. O'Connor
2727	Kevin Jamal Woods
2728	Kevin Kline
2729	Kevin McCarthy
2730	Kevin McKidd
2731	Kevin McNally
2732	Kevin Miles
2733	Kevin Nealon
2734	Kevin O'Connor
2735	Kevin Peter Hall
2736	Kevin Pollack
2737	Kevin Pollak
2738	Kevin Smith
2739	Kevin Spacey
2740	Kevin Tighe
2741	Kevin Van Hentenryck
2742	Kevin Zegers
2743	Kevork Malikyan
2744	Kevyn Major Howard
2745	Keye Luke
2746	Khandi Alexander
2747	Kiefer Sutherland
2748	Kieran Culkin
2749	Kim Basinger
2750	Kim Bass
2751	Kim Cattrall
2752	Kim De Angelo
2753	Kim Greist
2754	Kim Hunter
2755	Kim Miyori
2756	Kim Novak
2757	Kim Parker
2758	Kim Richards
2759	Kim Stanley
2760	Kim Vithana
2761	Kimberly Elise
2762	Kimberly Lambert
2763	Kimberly Stringer
2764	Kimberly Williams-Paisley
2765	King Donovan
2766	Kip McArdle
2767	Kipp Hamilton
2768	Kirk Acevedo
2769	Kirk Douglas
2770	Kirsten Baker
2771	Kirsten Dunst
2772	Kirsten Sheridan
2773	Kirstie Alley
2774	Kirsty Child
2775	Kitty Carlisle
2776	Kitty Winn
2777	Klaus Maria Brandauer
2778	Kolia Litscher
2779	Koyuki
2780	Kris Kristofferson
2781	Kristen Bell
2782	Kristen Cloke
2783	Kristen Goelz
2784	Kristen Stewart
2785	Kristen Wilson
2786	Kristin Davis
2787	Kristin Scott Thomas
2788	Kristina Kennedy
2789	Kristina Wayborn
2790	Kristine DeBell
2791	Kristine Sutherland
2792	Kristy McNichol
2793	Kristy Swanson
2794	Kurt Katch
2795	Kurt Raab
2796	Kurt Russell
2797	Kurtwood Smith
2798	Kyle MacLachlan
2799	Kyle Secor
2800	Kyle T. Heffner
2801	Kynaston Reeves
2802	Kyra Sedgwick
2803	L.Q. Jones
2804	LL Cool J
2805	Lacey Chabert
2806	Lady Rowlands
2807	Laird Cregar
2808	Lana Clarkson
2809	Lana Turner
2810	Lana Wood
2811	Lance Fuller
2812	Lance Guest
2813	Lance Henriksen
2814	Lane Smith
2815	Lara Flynn Boyle
2816	Larenz Tate
2817	Larisa Oleynik
2818	Larry B. Scott
2819	Larry Drake
2820	Larry Gates
2821	Larry Hagman
2822	Larry Simms
2823	Lars Brygmann
2824	Laszlo Szabo
2825	Laura Dean
2826	Laura Dern
2827	Laura Harris
2828	Laura Linney
2829	Laura Ramsey
2830	Laura San Giacomo
2831	Lauren Bacall
2832	Lauren Graham
2833	Lauren Holly
2834	Lauren Hutton
2835	Laurence Fishburne
2836	Laurence Harvey
2837	Laurence Luckinbill
2838	Laurence Naismith
2839	Laurence Olivier
2840	Laurene Landon
2841	Laurie Bartram
2842	Laurie Metcalf
2843	Lawrence Dane
2844	Lawrence Tierney
2845	LeVar Burton
2846	Lea Thompson
2847	Lee Bowman
2848	Lee Cormie
2849	Lee Curreri
2850	Lee Evans
2851	Lee Grant
2852	Lee Horsley
2853	Lee J. Cobb
2854	Lee Majors
2855	Lee Marvin
2856	Lee Remick
2857	Lee Van Cleef
2858	Leelee Sobieski
2859	Leib Lensky
2860	Leif Erickson
2861	Leigh Lawson
2862	Leigh Taylor-Young
2863	Leila Gastil
2864	Leila Hyams
2865	Lela Rochon
2866	Leland Orser
2867	Leleti Khumalo
2868	Lena Farugia
2869	Lena Horne
2870	Lena Olin
2871	Lenny Baker
2872	Lenny von Dohlen
2873	Lenore Kasdorf
2874	Leo Dolan
2875	Leo Fitzpatrick
2876	Leo Fuchs
2877	Leo G. Carroll
2878	Leo Genn
2879	Leo Gordon
2880	Leo McKern
2881	Leo Rossi
2882	Leon Errol
2883	Leon M. Lion
2884	Leon Rippy
2885	Leon Robinson
2886	Leonard Henry
2887	Leonard Nimoy
2888	Leonard Rossiter
2889	Leonard Termo
2890	Leonard Whiting
2891	Leonardo Cimino
2892	Leonardo DiCaprio
2893	Leonardo Sbaraglia
2894	Leonor Watling
2895	Leopoldine Konstantin
2896	Leora Dana
2897	Les Tremayne
2898	Lesley Ann Warren
2899	Lesley-Anne Down
2900	Leslie Ash
2901	Leslie Banks
2902	Leslie Bradley
2903	Leslie Caron
2904	Leslie Hope
2905	Leslie Mann
2906	Leslie Nielsen
2907	Leslie Phillips
2908	Leslie Stefanson
2909	Lew Ayres
2910	Lewis Howlett
2911	Lewis Stone
2912	Lex Barker
2913	Lexi Randall
2914	Liam Cunningham
2915	Liam Neeson
2916	Liana Liberato
2917	Lidea Ruth
2918	Liesel Matthews
2919	Liev Schreiber
2920	Lihle Mvelase
2921	Lila Kedrova
2922	Lili Damita
2923	Lili St Cyr
2924	Lili Taylor
2925	Lilia Skala
2926	Lilli Palmer
2927	Lillian Gish
2928	Lillo Brancato
2929	Lily Tomlin
2930	Lin Shaye
2931	Lincoln Kilpatrick
2932	Linda Bassett
2933	Linda Blair
2934	Linda Darnell
2935	Linda Fiorentino
2936	Linda Hamilton
2937	Linda Haynes
2938	Linda Henry
2939	Linda Hunt
2940	Linda Kozlowski
2941	Linda Manz
2942	Linda Miller
2943	Linda Purl
2944	Linden Ashby
2945	Lindsay Crouse
2946	Lindsay Duncan
2947	Lindsay Lohan
2948	Lindsay Wagner
2949	Lindsey McKeon
2950	Ling Bai
2951	Lino Ventura
2952	Lionel Abelanski
2953	Lionel Atwill
2954	Lionel Barrymore
2955	Lionel Jeffries
2956	Lionel Stander
2957	Lisa Ann Walter
2958	Lisa Banes
2959	Lisa Blount
2960	Lisa Bonet
2961	Lisa Eichhorn
2962	Lisa Eilbacher
2963	Lisa Gay Hamilton
2964	Lisa Harrow
2965	Lisa Joliffe-Andoh
2966	Lisa Kudrow
2967	Lisa Pelikan
2968	Lisa Smit
2969	Lisanne Falk
2970	Liselotte Pulver
2971	Lita Milan
2972	Little Richard
2973	Liv Tyler
2974	Liv Ullmann
2975	Liz Smith
2976	Liza Minnelli
2977	Lizabeth Scott
2978	Lloyd Bochner
2979	Lloyd Bridges
2980	Lloyd Nolan
2981	Logan Lerman
2982	Lois Chiles
2983	Lois Smith
2984	Lolita Chammah
2985	Lolita Davidovich
2986	Lon Chaney
2987	Lon Chaney Jr.
2988	Lonette McKee
2989	Loren Dean
2990	Loren Lester
2991	Loretta Swit
2992	Lori Cardille
2993	Lori Nelson
2994	Lori Petty
2995	Lori Singer
2996	Lorna Luft
2997	Lorraine Bracco
2998	Lorraine Gary
2999	Lorraine Pilkington
3000	Loryn Locklin
3001	Lotte Lenya
3002	Lotte Verbeek
3003	Lou Costello
3004	Lou Diamond Phillips
3005	Lou Eppolito
3006	Lou Gilbert
3007	Lou Hancock
3008	Lou Jacobi
3009	Lou Reed
3010	Lou Taylor Pucci
3011	Louis Armstrong
3012	Louis Calhern
3013	Louis Gossett jr.
3014	Louis Hofmann
3015	Louis Jourdan
3016	Louis Merrill
3017	Louis Sheldon Williams
3018	Louis Tripp
3019	Louis Waldon
3020	Louis Wolheim
3021	Louis de FunÃ¨s
3022	Louise Fletcher
3023	Louise Goodall
3024	Louise Lasser
3025	Louise Latham
3026	Louise Salter
3027	Luc Montagnier
3028	Luciana Paluzzi
3029	Lucie Mannheim
3030	Lucille Bremer
3031	Lucinda Jenney
3032	Lucinda Jones
3033	Lucy Gutteridge
3034	Lucy Russell
3035	Luis GuzmÃ¡n
3036	Lukas Haas
3037	Luke Aikman
3038	Luke Arnold
3039	Luke Askew
3040	Luke Goss
3041	Luke Halpin
3042	Luke Wilson
3043	Lyle Bettger
3044	Lyle Lovett
3045	Lynda Day George
3046	Lynn Carlin
3047	Lynn Cohen
3048	Lynn Redgrave
3049	Lynn-Holly Johnson
3050	Lynne Frederick
3051	Lyoyd Hughes
3052	Lysette Anthony
3053	LÃ©a Massari
3054	M. Emmet Walsh
3055	M.C. Gainey
3056	Mabel King
3057	Mac Davis
3058	Macaulay Culkin
3059	Macdonald Carey
3060	Madeleine Carroll
3061	Madeleine Stowe
3062	Madeline Kahn
3063	Madison Eginton
3064	Madolyn Smith Osborne
3065	Madonna
3066	Mads Mikkelsen
3067	Mady Christians
3068	Mae West
3069	Mae Whitman
3070	Magdalena Mielcarz
3071	Maggie McOmie
3072	Maggie Q
3073	Maggie Smith
3074	Mahshweta Roy
3075	Mai Zetterling
3076	Mako
3077	Malachi Pearson
3078	Malcolm Keen
3079	Malcolm McDowell
3080	Malcom Dixon
3081	Malik Yoba
3082	Malin Akerman
3083	Mamaengaroa Kerr-Bell
3084	Mandy Patinkin
3085	Manuel FÃ¡bregas
3086	Mara Corday
3087	Mara Wilson
3088	Marc McClure
3089	Marc de Jonge
3090	Marcel Hillaire
3091	Marcel Iures
3092	Marcel Journet
3093	Marcia Gay Harden
3094	Marcia Henderson
3095	Marcia McBroom
3096	Marcia Strassman
3097	Marcus Gilbert
3098	Mare Winningham
3099	Marg Helgenberger
3100	Margaret Avery
3101	Margaret Blye
3102	Margaret Brooks
3103	Margaret Cho
3104	Margaret Colin
3105	Margaret Langrick
3106	Margaret Lindsay
3107	Margaret Lockwood
3108	Margaret Loveys
3109	Margaret O'Brien
3110	Margaret Rutherford
3111	Margaret Sheridan
3112	Margaret Sullavan
3113	Margaret Tallichet
3114	Margaret Whitton
3115	Margi Clarke
3116	Margia Dean
3117	Margo
3118	Margo Woode
3119	Margot Kidder
3120	Maria Bello
3121	Maria Conchita Alonso
3122	Maria Doyle Kennedy
3123	Maria Lundqvist
3124	Maria Mauban
3125	Maria Montez
3126	Maria Perschy
3127	Maria Pitillo
3128	Maria Richwine
3129	Maria Schneider
3130	Maria Simon
3131	Marian Seldes
3132	Marian Spencer
3133	Marianna Hill
3134	Marianne Koch
3135	Marianne SÃ¤gebrecht
3136	Marie Versini
3137	Marie Windsor
3138	Marie-Christine Barrault
3139	Mariel Hemingway
3140	Mariette Hartley
3141	Marilu Henner
3142	Marilyn Burns
3143	Marilyn Chris
3144	Marilyn Eastman
3145	Marilyn Ghigliotti
3146	Marilyn Monroe
3147	Mario Machado
3148	Marion Busia
3149	Marion Cotillard
3150	Marion Davies
3151	Marion Mack
3152	Marisa Berenson
3153	Marisa Mell
3154	Marisa Pavan
3155	Marisa Tomei
3156	Marius Goring
3157	Marius Weyers
3158	MariÃ¡n Aguilera
3159	Marjoe Gortner
3160	Marjorie Ann Mutchie
3161	Marjorie Taylor
3162	Mark Addy
3163	Mark Damon
3164	Mark Frechette
3165	Mark Hamill
3166	Mark Harmon
3167	Mark Herrier
3168	Mark Holton
3169	Mark Joy
3170	Mark Lee
3171	Mark Lester
3172	Mark McKinney
3173	Mark Morales
3174	Mark Neely
3175	Mark Rylance
3176	Mark Stevens
3177	Mark Wahlberg
3178	Mark Wingett
3179	Marki Bey
3180	Marla English
3181	Marla Gibbs
3182	Marla Landi
3183	Marlee Matlin
3184	Marlene Dietrich
3185	Marlon Brando
3186	Marlon Wayans
3187	Marsha Hunt
3188	Marsha Mason
3189	Marshall Bell
3190	Marshall Thompson
3191	Martha Hyer
3192	Martha O'Driscoll
3193	Martha Vickers
3194	Marthe Keller
3195	Martin Balsam
3196	Martin Clunes
3197	Martin Donovan
3198	Martin Gabel
3199	Martin Kove
3200	Martin Landau
3201	Martin Lawrence
3202	Martin Lev
3203	Martin Milner
3204	Martin Shaw
3205	Martin Sheen
3206	Martin Short
3207	Martin Stephens
3208	Martin Walsh
3209	Martita Hunt
3210	Marty Feldman
3211	Mary Astor
3212	Mary Ault
3213	Mary Badham
3214	Mary Beth Hughes
3215	Mary Beth Hurt
3216	Mary Crosby
3217	Mary Elizabeth Mastrantonio
3218	Mary Elizabeth Winstead
3219	Mary Fickett
3220	Mary Fuller
3221	Mary Gail Artz
3222	Mary Gregory
3223	Mary Kay Place
3224	Mary McCormack
3225	Mary McDonnell
3226	Mary Meade
3227	Mary Murphy
3228	Mary Nell Santacroce
3229	Mary Philbin
3230	Mary Steenburgen
3231	Mary Stuart Masterson
3232	Mary Tyler Moore
3233	Mary Ure
3234	Mary Woronov
3235	Mary-Kate Olsen
3236	Mary-Louise Parker
3237	Maryam Zaree
3238	Maryam d'Abo
3239	Masatoshi Nagase
3240	Mason Gamble
3241	Mathew Valencia
3242	Mathilda May
3243	Matt Clark
3244	Matt Craven
3245	Matt Damon
3246	Matt Dillon
3247	Matt Frewer
3248	Matt Long
3249	Matt McCoy
3250	Matthew Broderick
3251	Matthew Garber
3252	Matthew Laurance
3253	Matthew Lillard
3254	Matthew McConaughey
3255	Matthew Modine
3256	Matthew Perry
3257	Matthew Rhys
3258	Matthew Sunderland
3259	Maud Adams
3260	Maura Tierney
3261	Maureen Connell
3262	Maureen O'Hara
3263	Maureen O'Sullivan
3264	Maureen O`Sullivan
3265	Maureen Oâ€™Hara
3266	Maureen Stapleton
3267	Maureen Teefy
3268	Maurice Chevalier
3269	Maurice Denham
3270	Maurice Gibb
3271	Maurice RoÃ«ves
3272	Maury Chaykin
3273	Max Julien
3274	Max Perlich
3275	Max Wall
3276	Max von Sydow
3277	Maxi NÃ¼chtern
3278	Maximilian BrÃ¼ckner
3279	Maximilian Schell
3280	Maxine Audley
3281	Maxwell Caulfield
3282	May McAvoy
3283	May Robson
3284	Maya Zapata
3285	Meat Loaf
3286	Meera Syal
3287	Meg Foster
3288	Meg Ryan
3289	Meg Tilly
3290	Megan Ward
3291	Mel Brooks
3292	Mel Ferrer
3293	Mel Gibson
3294	Mel Gorham
3295	Mel Harris
3296	Melanie Griffith
3297	Melanie Lynskey
3298	Melendy Britt
3299	Melina Mercouri
3300	Melinda Dillon
3301	Melinda McGraw
3302	Melissa Behr
3303	Melissa George
3304	Melissa Sue Anderson
3305	Melody Anderson
3306	Melvyn Douglas
3307	Mercedes Ruehl
3308	Meredith Baxter
3309	Merle Kennedy
3310	Merle Oberon
3311	Merrie Lynn Ross
3312	Mervyn Johns
3313	Meryl Streep
3314	Mia Farrow
3315	Mia Kirshner
3316	Mia Sara
3317	Michael A. Goorjian
3318	Michael Aherne
3319	Michael Anderson, jr.
3320	Michael Ansara
3321	Michael Bates
3322	Michael Berryman
3323	Michael Biehn
3324	Michael Boatman
3325	Michael Bodnar
3326	Michael Burns
3327	Michael C. Williams
3328	Michael Caine
3329	Michael Callan
3330	Michael Caton
3331	Michael Chekhov
3332	Michael Chiklis
3333	Michael Clark
3334	Michael Clarke Duncan
3335	Michael Constantine
3336	Michael Craig
3337	Michael Crawford
3338	Michael D. Roberts
3339	Michael Dolan
3340	Michael Douglas
3341	Michael Dudikoff
3342	Michael Fassbender
3343	Michael Fox
3344	Michael Gambon
3345	Michael Goodliffe
3346	Michael Gough
3347	Michael Gwynn
3348	Michael Haley
3349	Michael Ironside
3350	Michael J. Fox
3351	Michael J. Pollard
3352	Michael Jackson
3353	Michael Jai White
3354	Michael Jayston
3355	Michael Jeter
3356	Michael Keaton
3357	Michael Kitchen
3358	Michael KÃ¶nig
3359	Michael Landes
3360	Michael Legge
3361	Michael Lerner
3362	Michael Lonsdale
3363	Michael Madsen
3364	Michael Maloney
3365	Michael McKean
3366	Michael Moriarty
3367	Michael Murphy
3368	Michael Nouri
3369	Michael O'Keefe
3370	Michael Ontkean
3371	Michael OÂ´Keefe
3372	Michael P. Moran
3373	Michael Palin
3374	Michael Parks
3375	Michael ParÃ©
3376	Michael Pate
3377	Michael Patrick Carter
3378	Michael Rapaport
3379	Michael Redgrave
3380	Michael Reilly Burke
3381	Michael Rennie
3382	Michael Richards
3383	Michael Ripper
3384	Michael Robbins
3385	Michael Rooker
3386	Michael Rosenbaum
3387	Michael Sarne
3388	Michael Sarrazin
3389	Michael Schoeffling
3390	Michael Stefani
3391	Michael Strong
3392	Michael Thys
3393	Michael V. Gazzo
3394	Michael Vartan
3395	Michael Villella
3396	Michael Wilding
3397	Michael Wincott
3398	Michael Winslow
3399	Michael Wright
3400	Michael York
3401	Michael Zelniker
3402	Michaela Beck
3403	Michaela McManus
3404	Michel Auclair
3405	Michel Blanc
3406	Michel Piccoli
3407	Michel Subor
3408	Michelan Sisti
3409	Michele Dotrice
3410	Michele Lamar Richards
3411	Michele Lee
3412	Michelle Michaels
3413	Michelle Monaghan
3414	Michelle Pfeiffer
3415	Michelle Phillips
3416	Michelle RodrÃ­guez
3417	Michelle Trachtenberg
3418	Michelle Williams
3419	Michelle Yeoh
3420	MichÃ¨le Girardon
3421	MichÃ¨le Laroque
3422	Mick Cain
3423	Mick Dillon
3424	Mick Jagger
3425	Mickey Rooney
3426	Mickey Rourke
3427	Mie Hama
3428	MieczysÅ‚aw Marosek
3429	Miguel Ferrer
3430	Miho Kanno
3431	Mike Anscombe
3432	Mike Connors
3433	Mike Figgis
3434	Mike Henry
3435	Mike McGlone
3436	Mike Minett
3437	Mike Myers
3438	Mike Starr
3439	Mike Vitar
3440	Mikhail Boyarsky
3441	Mikhail Mamaev
3442	Miko Hughes
3443	Mildred Clinton
3444	Mildred Dunnock
3445	Mildred Natwick
3446	Miles Malleson
3447	Miles Mander
3448	Mili Avital
3449	Milla Jovovich
3450	Millie Perkins
3451	Milton Berle
3452	Mimi Rogers
3453	Ming-Na Wen
3454	Mira Sorvino
3455	Miranda Richardson
3456	Miriam Hopkins
3457	Miriam Isherwood
3458	Miriam Margolyes
3459	Mischa Barton
3460	Mitch Pileggi
3461	Mitch Ryan
3462	Mitchell Whitfield
3463	Moira Kelly
3464	Moira Shearer
3465	Molly Ringwald
3466	Molly Shannon
3467	Mona Freeman
3468	Mona McKinnon
3469	Mona Washbourne
3470	Monica Bellucci
3471	Monica Potter
3472	Monica Vitti
3473	Monika Kelly
3474	Montgomery Clift
3475	Morag McNee
3476	Morey Amsterdam
3477	Morgan Freeman
3478	Morgan Jones
3479	Morgan Woodward
3480	Morris Ankrum
3481	Morris Chestnut
3482	Morris Day
3483	Mort Shuman
3484	Moses Gunn
3485	Muriel Pavlow
3486	Murray Hamilton
3487	Murray Head
3488	Murvyn Vye
3489	Mykelti Williamson
3490	MylÃ¨ne Demongeot
3491	Myrna Fahey
3492	Myrna Loy
3493	MÃ¤dchen Amick
3494	N!xau
3495	N'Bushe Wright
3496	Nan Grey
3497	Nance O'Neil
3498	Nancy Allen
3499	Nancy Fish
3500	Nancy Gates
3501	Nancy Kwan
3502	Nancy Kyes
3503	Nancy Olson
3504	Nancy Parsons
3505	Nancy Sinatra
3506	Nancy Travis
3507	Nastassja Kinski
3508	Nat Pendleton
3509	Natalia Borisova
3510	Natalie Bate
3511	Natalie Portman
3512	Natalie Trundy
3513	Natalie Wood
3514	Natascha McElhone
3515	Natasha Lyonne
3516	Natasha Richardson
3517	Natasha Wightman
3518	Natassia Malthe
3519	Nathan Bexton
3520	Nathan Fillion
3521	Nathan Lane
3522	Nathaniel Parker
3523	Natividad Abascal
3524	Naura Hayden
3525	Naveen Andrews
3526	Neal McDonough
3527	Ned Beatty
3528	Nehemiah Persoff
3529	Neil Dickson
3530	Neil Hamilton
3531	Neil Patrick Harris
3532	Nero Campbell
3533	Nesdon Booth
3534	Nestor Paiva
3535	Neva Patterson
3536	Neve Campbell
3537	Neville Brand
3538	Nguyen Ngoc Hiep
3539	Ni Ten
3540	Nia Long
3541	Nicholas Ball
3542	Nicholas Clay
3543	Nicholas Farrell
3544	Nicholas Pryor
3545	Nicholas Rowe
3546	Nicholle Tom
3547	Nick Apollo Forte
3548	Nick Brimble
3549	Nick Cassavetes
3550	Nick Cravat
3551	Nick Mancuso
3552	Nick Nolte
3553	Nick Reding
3554	Nick Stabile
3555	Nicky Katt
3556	Nicol Williamson
3557	Nicola Pagett
3558	Nicolai Cleve Broch
3559	Nicolas Bro
3560	Nicolas Cage
3561	Nicolas Coster
3562	Nicolas Wright
3563	Nicole Beharie
3564	Nicole Kidman
3565	Nicole Maurey
3566	Nicoletta Braschi
3567	Nicollette Sheridan
3568	Nigel Bruce
3569	Nigel Havers
3570	Nigel Hawthorne
3571	Nigel Patrick
3572	Nigel Terry
3573	Nikolaj Coster-Waldau
3574	Niles McMaster
3575	Nina von Pallandt
3576	Nipsey Russell
3577	Noah Emmerich
3578	Noah Hathaway
3579	Noel Coward
3580	Noel Francis
3581	Noel Willman
3582	Noley Thornton
3583	Nomadlozi Kubheka
3584	Norah Baring
3585	Norm MacDonald
3586	Norma Shearer
3587	Norman Alden
3588	Norman Bartold
3589	Norman Fell
3590	Norman Kerry
3591	Norman Lumsden
3592	Norman Reedus
3593	Nova Pilbeam
3594	NoÃ©mie Lvovsky
3595	O.P. Heggie
3596	Obba BabatundÃ©
3597	Olga Baclanova
3598	Olga Georges-Picot
3599	Olga Karlatos
3600	Olin Howland
3601	Oliver Hardy
3602	Oliver Platt
3603	Oliver Pratt
3604	Oliver Reed
3605	Oliver Robins
3606	Oliver Tobias
3607	Olivia Barash
3608	Olivia Hussey
3609	Olivia Newton-John
3610	Olivia Williams
3611	Olivia d'Abo
3612	Olivia de Havilland
3613	Olympia Dukakis
3614	Om Puri
3615	Omar Epps
3616	Omar Sharif
3617	Omri Katz
3618	Ona Fletcher
3619	Onslow Stevens
3620	Oprah Winfrey
3621	Orlando Jones
3622	Orson Bean
3623	Orson Welles
3624	Oscar Levant
3625	Oskar Homolka
3626	Oskar Werner
3627	Ossie Davis
3628	Otis Young
3629	Otto Kruger
3630	Otto Preminger
3631	Otto Wernicke
3632	Owen Moore
3633	Owen Wilson
3634	Oyanka Cabezas
3635	P.J. Soles
3636	Paige Rowland
3637	Pam Grier
3638	Pamela Brown
3639	Pamela Duncan
3640	Pamela Franklin
3641	Pamela Reed
3642	Pamela Tiffin
3643	Pamela Toll
3644	Paris Hilton
3645	Parker Posey
3646	Parker Stevenson
3647	Pascale BussiÃ¨res
3648	Pat Hingle
3649	Pat Morita
3650	Pat O'Brien
3651	Pat Sheehan
3652	Pat Thomson
3653	Patric Knowles
3654	Patrice Martinez
3655	Patricia Arquette
3656	Patricia Charbonneau
3657	Patricia Clarkson
3658	Patricia Jessel
3659	Patricia Morison
3660	Patricia Neal
3661	Patricia Quinn
3662	Patricia Roc
3663	Patricia Wettig
3664	Patrick Allen
3665	Patrick Bauchau
3666	Patrick Bergin
3667	Patrick Budal
3668	Patrick Cargill
3669	Patrick Field
3670	Patrick Horgan
3671	Patrick J. Adams
3672	Patrick Macnee
3673	Patrick Magee
3674	Patrick McGoohan
3675	Patrick Renna
3676	Patrick Stewart
3677	Patrick Swayze
3678	Patrick Tierney
3679	Patrick Van Horn
3680	Patrick Wilson
3681	Patrick Wymark
3682	Patsy Kensit
3683	Patti D'Arbanville
3684	Patti Love
3685	Patti LuPone
3686	Patty Duke
3687	Paul A. Partain
3688	Paul Benedict
3689	Paul Bettany
3690	Paul Birch
3691	Paul Blackthome
3692	Paul Burke
3693	Paul Cross
3694	Paul Dooley
3695	Paul Douglas
3696	Paul Dubov
3697	Paul Fix
3698	Paul Freeman
3699	Paul Giamatti
3700	Paul Guers
3701	Paul Hecht
3702	Paul Henreid
3703	Paul Hogan
3704	Paul Hubschmid
3705	Paul Kermack
3706	Paul Koslo
3707	Paul L. Smith
3708	Paul Linke
3709	Paul Lukas
3710	Paul Mantee
3711	Paul Massie
3712	Paul McCartney
3713	Paul McCrane
3714	Paul Mercurio
3715	Paul Meurisse
3716	Paul Muni
3717	Paul Newman
3718	Paul Richards
3719	Paul Robeson
3720	Paul Rudd
3721	Paul Sanchez
3722	Paul Schulze
3723	Paul Scofield
3724	Paul Sorvino
3725	Paul Stewart
3726	Paul Trinka
3727	Paul Walker
3728	Paul Winfield
3729	Paula E. Sheppard
3730	Paula Marshall
3731	Paula Prentiss
3732	Paula Raymond
3733	Paulette Goddard
3734	Pauly Shore
3735	Pearl Bailey
3736	Pee Wee Herman
3737	Peggy Ashcroft
3738	Peggy Cummins
3739	Peggy Dow
3740	Peggy Wood
3741	Penelope Allen
3742	Penelope Ann Miller
3743	Penelope Wilton
3744	Penn Badgley
3745	Penny Leatherbarrow
3746	Penny Singleton
3747	Penolope Wilton
3748	PenÃ©lope Cruz
3749	Percy Herbert
3750	Percy Marmont
3751	Perrette Pradier
3752	Perry King
3753	Perry Lopez
3754	Persis Khambatta
3755	Pete O'Herne
3756	Pete Postlethwaite
3757	Pete Seeger
3758	Pete Smith
3759	Peter Berg
3760	Peter Birrell
3761	Peter Bogdanovich
3762	Peter Boyle
3763	Peter Breck
3764	Peter Bull
3765	Peter Caffrey
3766	Peter Carsten
3767	Peter Coyote
3768	Peter Cushing
3769	Peter Davison
3770	Peter Dinklage
3771	Peter Dobson
3772	Peter Dvorsky
3773	Peter Facinelli
3774	Peter Falk
3775	Peter Finch
3776	Peter Firth
3777	Peter Fonda
3778	Peter Frampton
3779	Peter Friedman
3780	Peter Gallagher
3781	Peter Graves
3782	Peter Greene
3783	Peter Jeffrey
3784	Peter Lawford
3785	Peter Lind Hayes
3786	Peter Lorre
3787	Peter MacNicol
3788	Peter McDonald
3789	Peter McEnery
3790	Peter Mullan
3791	Peter Murray-Hill
3792	Peter O'Farrell
3793	Peter O'Toole
3794	Peter Riegert
3795	Peter Sarsgaard
3796	Peter Sellers
3797	Peter Stormare
3798	Peter Ustinov
3799	Peter Vaughan
3800	Peter Weller
3801	Peter Wyngarde
3802	Phil Brown
3803	Phil Daniels
3804	Phil Hartman
3805	Phil Spector
3806	Philip Bosco
3807	Philip Davis
3808	Philip Dorn
3809	Philip Seymour Hoffman
3810	Philippe ClÃ©venot
3811	Philippe Leroy
3812	Philippe LÃ©otard
3813	Philippe Noiret
3814	Phillip Alford
3815	Phillip Reed
3816	Phoebe Augustine
3817	Phoebe Brand
3818	Phoebe Cates
3819	Phylicia Rashad
3820	Phyllis Diller
3821	Pia Tjelta
3822	Pier Angeli
3823	Pierce Brosnan
3824	Pierre Brice
3825	Piper Laurie
3826	Piper Perabo
3827	Pola Negri
3828	Polly Bergen
3829	Polly Walker
3830	Porter Hall
3831	Powers Boothe
3832	Prashant Nanda
3833	Prince
3834	Priscilla Lane
3835	Prunella Gee
3836	Prunella Scales
3837	Queen Latifah
3838	Quentin Crisp
3839	Quentin Tarantino
3840	R. Lee Ermey
3841	R.D. Call
3842	R.G. Armstrong
3843	Rachael Crawford
3844	Rachael Leigh Cook
3845	Rachel Friend
3846	Rachel Griffiths
3847	Rachel Hayward
3848	Rachel McAdams
3849	Rachel Roberts
3850	Rachel Thomas
3851	Rachel Ticotin
3852	Rachel True
3853	Rachel Ward
3854	Rachel Weisz
3855	Rade Å erbedÅ¾ija
3856	Radha Mitchell
3857	Rae Dawn Chong
3858	Raf Vallone
3859	Ralph Bellamy
3860	Ralph Fiennes
3861	Ralph Macchio
3862	Ralph Meeker
3863	Ralph Richardson
3864	Ralph Waite
3865	Randall Batinkoff
3866	Randee Heller
3867	Randolph Scott
3868	Randy Brooks
3869	Randy Quaid
3870	Raoul Bhaneja
3871	Raquel Torres
3872	Raquel Welch
3873	Ras Daniel Hartman
3874	Raul Julia
3875	Rawle D. Lewis
3876	Ray Allen
3877	Ray Barrett
3878	Ray Bolger
3879	Ray Liotta
3880	Ray McAnally
3881	Ray Milland
3882	Ray Walston
3883	Ray Winstone
3884	Ray Wise
3885	Raymond Burr
3886	Raymond J. Barry
3887	Raymond J. Berry
3888	Raymond Massey
3889	Reba McEntire
3890	Rebecca Callard
3891	Rebecca De Mornay
3892	Rebecca Gayheart
3893	Rebecca Wood
3894	Red Buttons
3895	Redd Foxx
3896	Reese Witherspoon
3897	Reeve Carney
3898	Reg Varney
3899	Reggie Bannister
3900	Reggie Lee
3901	Regina King
3902	Reginald Denny
3903	Reginald Gardiner
3904	Reginald Owen
3905	Reginald VelJohnson
3906	Rena Owen
3907	Renate Kanthack
3908	Rene Auberjonois
3909	Rene Russo
3910	Reni Santoni
3911	Renji Ishibashi
3912	Renno Russo
3913	RenÃ©e Zellweger
3914	Rex Harrison
3915	Rex Reason
3916	Rhea Perlman
3917	Rhonda Fleming
3918	Rhys Ifans
3919	Ricardo Montalban
3920	Richard 'Skeets' Gallagher
3921	Richard A. Harris
3922	Richard Anconina
3923	Richard Arlen
3924	Richard Attenborough
3925	Richard B. Shull
3926	Richard Backus
3927	Richard Basehart
3928	Richard Benjamin
3929	Richard Beymer
3930	Richard Boes
3931	Richard Bohringer
3932	Richard Bradford
3933	Richard Briars
3934	Richard Briers
3935	Richard Bull
3936	Richard Burton
3937	Richard Carlson
3938	Richard Chamberlain
3939	Richard Conte
3940	Richard Cox
3941	Richard Crenna
3942	Richard Crenne
3943	Richard Davalos
3944	Richard DeManincor
3945	Richard Deacon
3946	Richard Denning
3947	Richard Devon
3948	Richard Dix
3949	Richard Donat
3950	Richard Dreyfuss
3951	Richard Dust
3952	Richard E. Grant
3953	Richard Edson
3954	Richard Egan
3955	Richard Elfyn
3956	Richard Farnsworth
3957	Richard Gaines
3958	Richard Garland
3959	Richard Gere
3960	Richard Griffiths
3961	Richard Harris
3962	Richard Hatch
3963	Richard Hunt
3964	Richard Jaeckel
3965	Richard Jenkins
3966	Richard Johnson
3967	Richard Jordan
3968	Richard Kiel
3969	Richard Lane
3970	Richard Lewis
3971	Richard Libertini
3972	Richard Marcus
3973	Richard Masur
3974	Richard McCabe
3975	Richard Moir
3976	Richard Murdoch
3977	Richard Ney
3978	Richard O'Brien
3979	Richard Pryor
3980	Richard Rober
3981	Richard Roundtree
3982	Richard Roxburgh
3983	Richard S. Castellano
3984	Richard Schiff
3985	Richard T. Jones
3986	Richard Todd
3987	Richard Tyson
3988	Richard Ward
3989	Richard Warwick
3990	Richard Wattis
3991	Richard Widmark
3992	Richard Wilson
3993	Richard Wyler
3994	Rick Aviles
3995	Rick Kunzi
3996	Rick Moranis
3997	Rick Rossovich
3998	Rick Scully
3999	Ricki Lake
4000	Ricky Nelson
4001	Ricky Tomlinson
4002	Rico Alaniz
4003	Rik Mayall
4004	Ringo Starr
4005	Rip Torn
4006	Rita Hayworth
4007	Rita Johnson
4008	Rita Tushingham
4009	Rita Wilson
4010	River Phoenix
4011	Rob Lowe
4012	Rob Morrow
4013	Rob Reiner
4014	Rob Schneider
4015	Robbie Coltrane
4016	Robert Arevalo
4017	Robert Arkins
4018	Robert Armstrong
4019	Robert Ayres
4020	Robert Bailey
4021	Robert Beltran
4022	Robert Blake
4023	Robert Brown
4024	Robert Carlyle
4025	Robert Carradine
4026	Robert Conrad
4027	Robert Cornthwaite
4028	Robert Cummings
4029	Robert De Niro
4030	Robert Deman
4031	Robert DoQui
4032	Robert Donat
4033	Robert Douglas
4034	Robert Downey Jr.
4035	Robert Duvall
4036	Robert Englund
4037	Robert Flemyng
4038	Robert Forster
4039	Robert Foxworth
4040	Robert Fuller
4041	Robert Guillaume
4042	Robert Hays
4043	Robert Hutton
4044	Robert Jayne
4045	Robert John Burke
4046	Robert Keith
4047	Robert Knott
4048	Robert Lansing
4049	Robert Logan
4050	Robert Loggia
4051	Robert MacNaughton
4052	Robert Mitchum
4053	Robert Montgomery
4054	Robert Morley
4055	Robert Morris
4056	Robert Newton
4057	Robert Oliveri
4058	Robert Pastorelli
4059	Robert Patrick
4060	Robert Pattinson
4061	Robert Powell
4062	Robert Preston
4063	Robert Prosky
4064	Robert Quarry
4065	Robert Redford
4066	Robert Ridgely
4067	Robert Ryan
4068	Robert Sansom
4069	Robert Sean Leonard
4070	Robert Shaw
4071	Robert Stack
4072	Robert Stephens
4073	Robert Strauss
4074	Robert Taylor
4075	Robert Townsend
4076	Robert Urich
4077	Robert Urquhart
4078	Robert Vaughn
4079	Robert Wagner
4080	Robert Walker
4081	Robert Webber
4082	Robert Young
4083	Roberta Maxwell
4084	Roberto Benigni
4085	Roberts Blossom
4086	Robin Bartlett
4087	Robin Burrows
4088	Robin Gibb
4089	Robin Givens
4090	Robin Shou
4091	Robin Stille
4092	Robin Tunney
4093	Robin Williams
4094	Robin Wright Penn
4095	Rocco Siffredi
4096	Rochelle Davis
4097	Rock Hudson
4098	Rocky Carroll
4099	Rod Mullinar
4100	Rod Steiger
4101	Rod Taylor
4102	Roddy McDowall
4103	Roddy Piper
4104	Rodney A. Grant
4105	Rodney Dangerfield
4106	Rodney Eastman
4107	Rodney Mullen
4108	Rodolfo De Alexandre
4109	Roger Daltrey
4110	Roger E. Mosley
4111	Roger Hanin
4112	Roger Livesey
4113	Roger Moore
4114	Roger Rees
4115	Rohini Hattangadi
4116	Roma Maffia
4117	Roman PolaÅ„ski
4118	Romany Malco
4119	Romolo Valli
4120	Romy Schneider
4121	Ron Eldard
4122	Ron Howard
4123	Ron Livingston
4124	Ron Moody
4125	Ron Perlman
4126	Ron Randell
4127	Ron Rich
4128	Ron Rifkin
4129	Ron Silver
4130	Ronald Adam
4131	Ronald Allen
4132	Ronald Colman
4133	Ronald Lacey
4134	Ronald Leigh-Hunt
4135	Ronald Lewis
4136	Ronee Blakley
4137	Ronny Cox
4138	Rory Calhoun
4139	Rory Cochrane
4140	Rosalind Cash
4141	Rosalind Russell
4142	Rosanna Arquette
4143	Rosanna DeSoto
4144	Rosario Dawson
4145	Roscoe Ates
4146	Roscoe Karns
4147	Roscoe Lee Browne
4148	Rose Byrne
4149	Rose Hacker
4150	Rose Marie
4151	Rose McGowan
4152	Rose Stradner
4153	Roseanne Barr
4154	Rosemary Clooney
4155	Rosemary DeCamp
4156	Rosemary Forsyth
4157	Rosemary Leach
4158	Rosemary Murphy
4159	Roshan Seth
4160	Rosie O'Donnell
4161	Rosie Perez
4162	Ross Malinger
4163	Rossano Brazzi
4164	Rowan Atkinson
4165	Roxanne Hart
4166	Roy Butler
4167	Roy Chiao
4168	Roy Crewsdon
4169	Roy Dotrice
4170	Roy Dupuis
4171	Roy Orbison
4172	Roy Scheider
4173	Ruby Dee
4174	Ruby Keeler
4175	RubÃ©n Blades
4176	Rufus Sewell
4177	Rupert Everett
4178	Rupert Graves
4179	Russ Tamblyn
4180	Russell Brand
4181	Russell Crowe
4182	Russell Johnson
4183	Russell Means
4184	Russell Wong
4185	Rusty Schwimmer
4186	Rutger Hauer
4187	Ruth Chatterton
4188	Ruth Gemmell
4189	Ruth Gordon
4190	Ruth Hussey
4191	Ruth Marshall
4192	Ruth Nelson
4193	Ruth Roman
4194	Ruth Warrick
4195	Ruth White
4196	Ryan Gosling
4197	Ryan O'Neal
4198	Ryan O`Neal
4199	Ryan Phillippe
4200	Ryan Reynolds
4201	Ryann Davey
4202	Ryo Kase
4203	Ryuichi Sakamoto
4204	S. Z. Sakall
4205	Sabrina Scharf
4206	Sabu
4207	Saeed Jaffrey
4208	Saffron Burrows
4209	Sagamore StÃ©venin
4210	Sage Stallone
4211	Sal Lopez
4212	Sal Mineo
4213	Sally Ann Howes
4214	Sally Field
4215	Sally Forest
4216	Sally Forrest
4217	Sally Fraser
4218	Sally Hawkins
4219	Sally Kellerman
4220	Sally Kirkland
4221	Salma Hayek
4222	Sam Elliott
4223	Sam J. Jones
4224	Sam Jaffe
4225	Sam Neill
4226	Sam Riley
4227	Sam Robards
4228	Sam Rockwell
4229	Sam Shepard
4230	Sam Wanamaker
4231	Sam Waterston
4232	Sam Worthington
4233	Samantha Eggar
4234	Samantha Lavigne
4235	Samantha Mathis
4236	Sami Frey
4237	Sammi Kraft
4238	Sammy Davis Jr.
4239	Samson Jorah
4240	Samuel E. Wright
4241	Samuel L. Jackson
4242	Samuel Page
4243	Samuel Roukin
4244	Samuel S. Hinds
4245	Samuel West
4246	Samy Naceri
4247	Sanaa Lathan
4248	Sandahl Bergman
4249	Sandor Eles
4250	Sandra Bernhard
4251	Sandra Bullock
4252	Sandra Dee
4253	Sandra Prinsloo
4254	Sandrine Holt
4255	Sandy Baron
4256	Sandy Dennis
4257	Sanford Mitchell
4258	Sara Allgood
4259	Sara Gilbert
4260	Sara Kestelmann
4261	Sara Shane
4262	Sarah Berry
4263	Sarah Henderson
4264	Sarah Jessica Parker
4265	Sarah Michelle Gellar
4266	Sarah Miles
4267	Sarah Patterson
4268	Sarah Peirse
4269	Sarah Polley
4270	Sarah Rowland Doroff
4271	Sarel Bok
4272	Sarita Khajuria
4273	Sasha Jenson
4274	Saskia Reeves
4275	Satish Kaushik
4276	Saul Rabnek (doppelt)
4277	Saul Rubinek
4278	Saul Stein
4279	Saundra Santiago
4280	Scarlett Johansson
4281	Scatman Crothers
4282	Scott Baio
4283	Scott Brady
4284	Scott Caan
4285	Scott Glenn
4286	Scott Grimes
4287	Scott H. Reiniger
4288	Scott Porter
4289	Scott Wolf
4290	Sean Astin
4291	Sean Barry-Weske
4292	Sean Bean
4293	Sean Bury
4294	Sean Chapman
4295	Sean Combs
4296	Sean Connery
4297	Sean Kenney
4298	Sean Nelson
4299	Sean Patrick Flanery
4300	Sean Penn
4301	Sean Young
4302	Season Hubley
4303	Sebastian Becker
4304	Sebastian Cabot
4305	Sela Ward
4306	Selena Royle
4307	Selma Blair
4308	Senta Berger
4309	Serena Grandi
4310	Sessue Hayakawa
4311	Seth Green
4312	Seth Meyers
4313	Seymour Cassel
4314	Sgt. Ben Peterson
4315	Shalom Harlow
4316	Shane
4317	Shane Briant
4318	Shannen Doherty
4319	Shannon Tweed
4320	Shaquille O'Neal
4321	Shari Hall
4322	Sharon Acker
4323	Sharon Farrell
4324	Sharon Gless
4325	Sharon Stone
4326	Sharon Tate
4327	Sharon Taylor
4328	Sharron Corley
4329	Shaun Parkes
4330	Shaun Sipos
4331	Shawn Carson
4332	Shawn Hatosy
4333	Shay Astar
4334	Sheila Kelley
4335	Sheila Rosenthal
4336	Sheila Sim
4337	Sheila Tousey
4338	Sheldon Peters Wolfchild
4339	Shelley Duvall
4340	Shelley Long
4341	Shelley Winters
4342	Shepperd Strudwick
4343	Sheree J. Wilson
4344	Sherilyn Fenn
4345	Sheryl Lee
4346	Sheryl Lee Ralph
4347	Shirley Anne Field
4348	Shirley Eaton
4349	Shirley Henderson
4350	Shirley MacLaine
4351	Shirley Stelfox
4352	Shirley Stoler
4353	Shirley Temple
4354	Sid Caesar
4355	Sidney Blackmer
4356	Sidney Fox
4357	Sidney James
4358	Sidney Poitier
4359	Sidney Toler
4360	Siegfried Rauch
4361	Sienna Miller
4362	Sig Ruman
4363	Sigourney Weaver
4364	Simon Billig
4365	Simon Callow
4366	Simon Ferry
4367	Simon Lack
4368	Simon MacCorkindale
4369	Simon McBurney
4370	Simon O'Connor
4371	Simon Russell Beale
4372	Simon Ward
4373	Simone Griffeth
4374	Simone Signoret
4375	Simone Simon
4376	Sinbad
4377	Siobhan Fallon
4378	Siobhan McKenna
4379	Sir Cedrick Hardwicke
4380	Sir Ian McKellen
4381	Sissy Spacek
4382	SiÃ¢n Phillips
4383	Skeet Ulrich
4384	Skip Homeier
4385	Skye Aubrey
4386	Slim Pickens
4387	Sondra Locke
4388	Sonia Braga
4389	Sonia Todd
4390	Sonja Henie
4391	Sonja Smits
4392	Sonny Landham
4393	Sonny Tufts
4394	Soon-Tek Oh
4395	Sophia Bush
4396	Sophia Loren
4397	Sophie Lee
4398	Sophie Marceau
4399	Sophie Ward
4400	Spalding Gray
4401	Spencer Breslin
4402	Spencer Tracy
4403	Spike Jonze
4404	Spike Lee
4405	Spiros FocÃ¡s
4406	Sriram Panda
4407	Stacey Dash
4408	Stacey Pickren
4409	Stacey Travis
4410	Staci Keanan
4411	Stacy Edwards
4412	Stacy Keach
4413	Stacy Peralta
4414	Stan Gottlieb
4415	Stan Haze
4416	Stan Laurel
4417	Stan Shaw
4418	Stanley Baker
4419	Stanley Holloway
4420	Stanley Maxted
4421	Stanley Swerdlow
4422	Stanley Tucci
4423	Starletta DuPois
4424	Stathis Giallelis
4425	Stefanie Powers
4426	Stella Stevens
4427	Stellan SkarsgÃ¥rd
4428	Stephane Gauger
4429	Stephanie Faracy
4430	Stephanie McVay
4431	Stephanie Sawyer
4432	Stephen Archibald
4433	Stephen Baldwin
4434	Stephen Boyd
4435	Stephen Collins
4436	Stephen Curry
4437	Stephen Dillane
4438	Stephen Dorff
4439	Stephen Fry
4440	Stephen Lack
4441	Stephen Lang
4442	Stephen MacKenna
4443	Stephen Macht
4444	Stephen Mendillo
4445	Stephen Peace
4446	Stephen Rea
4447	Stephen Root
4448	Stephen Tobolowsky
4449	Stephen Tompkinson
4450	Stephen Young
4451	Sterling Hayden
4452	Steve Bisley
4453	Steve Brodie
4454	Steve Buscemi
4455	Steve Carell
4456	Steve Cochran
4457	Steve Davis
4458	Steve Forrest
4459	Steve Guttenberg
4460	Steve Holland
4461	Steve Huison
4462	Steve James
4463	Steve Lawrence
4464	Steve Marachuk
4465	Steve Martin
4466	Steve McQueen
4467	Steve Railsback
4468	Steve Sandor
4469	Steve Whitmire
4470	Steve Zahn
4471	Steven Bauer
4472	Steven Berkoff
4473	Steven Marlo
4474	Steven Pasquale
4475	Steven Seagal
4476	Steven Waddington
4477	Steven Warner
4478	Steven Weber
4479	Steven Williams
4480	Stewart Granger
4481	Stockard Channing
4482	Stringer Davis
4483	Strother Martin
4484	Stuart Townsend
4485	Stuart Whitman
4486	Stuart Wilson
4487	StÃ©phanie Michelini
4488	Sue Casey
4489	Sue Lyon
4490	Sugar Ray Leonard
4491	Susan Cabot
4492	Susan Clark
4493	Susan Damante
4494	Susan Denberg
4495	Susan Fleetwood
4496	Susan George
4497	Susan Harrison
4498	Susan Hart
4499	Susan Hayward
4500	Susan Hogan
4501	Susan Kellerman
4502	Susan Lynch
4503	Susan Sarandon
4504	Susan Sennett
4505	Susan Strasberg
4506	Susan Swift
4507	Susan Tyrrell
4508	Susan Ursitti
4509	Susannah York
4510	Susanne Benton
4511	Susanne Lothar
4512	Susie Ann Watkins
4513	Susie Porter
4514	Suzanna Leigh
4515	Suzanne Flon
4516	Suzanne Pleshette
4517	Suzanne Snyder
4518	Suzy Amis
4519	Swoosie Kurtz
4520	Sy Richardson
4521	Sydney Greenstreet
4522	Sylva Koscina
4523	Sylvester Stallone
4524	Sylvia Kristel
4525	Sylvia Kuumba Williams
4526	Sylvia Miles
4527	Sylvia Sidney
4528	Sylvia Syms
4529	SÃ´ Yamamura
4530	T.K. Carter
4531	T.P. McKenna
4532	Tab Hunter
4533	Tabitha Lupien
4534	Tai Thai
4535	Tak Sakaguchi
4536	Takeshi Kitano
4537	Talia Shire
4538	Tallulah Bankhead
4539	Talya Gordon
4540	Tamara Dobson
4541	Tami Stronach
4542	Tammy Lauren
4543	Tammy McIntosh
4544	Tandi Wright
4545	Tannishtha Chatterjee
4546	Tantoo Cardinal
4547	Tanya Fenmore
4548	Tanya Roberts
4549	Tara Fitzgerald
4550	Tara Morice
4551	Tara Reid
4552	Tara Subkoff
4553	Taryn Manning
4554	Tasmin West
4555	Tate Donovan
4556	Tatsuya Mihashi
4557	Tatum O'Neal
4558	Tawny Kitaen
4559	Taye Diggs
4560	Taylor Lautner
4561	TchÃ©ky Karyo
4562	Ted Danson
4563	Ted Knight
4564	Ted Levine
4565	Ted Neeley
4566	Ted Ross
4567	Ted Sorel
4568	Telly Savalas
4569	Temuera Morrison
4570	Tencho Gyalpo
4571	Tenzin Thuthob Tsarong
4572	Terence Bayler
4573	Terence Knox
4574	Terence Morgan
4575	Terence Stamp
4576	Terence Stramp
4577	Teresa Wright
4578	Teri Garr
4579	Teri Hatcher
4580	Terrence Howard
4581	Terrence Mann
4582	Terri Susan Smith
4583	Terry Alexander
4584	Terry Camilleri
4585	Terry Kinney
4586	Terry Kiser
4587	Terry Potter
4588	Terry-Thomas
4589	Thalmus Rasulala
4590	Thandie Newton
4591	Thelma Ritter
4592	Thelma Todd
4593	Theo Maassen
4594	Theodore Bikel
4595	Theresa Russell
4596	Thomas Coley
4597	Thomas G. Waites
4598	Thomas Gibson
4599	Thomas Gomez
4600	Thomas Haden Church
4601	Thomas Ian Griffith
4602	Thomas Ian Nicholas
4603	Thomas Jane
4604	Thomas Mitchell
4605	Thomas Tierney
4606	Thora Birch
4607	Thora Hird
4608	Thorley Walters
4609	Tia Carrere
4610	Tiffany Gail Robinson
4611	Til Schweiger
4612	Tilda Swinton
4613	Tim Allen
4614	Tim Bagley
4615	Tim Conway
4616	Tim Curry
4617	Tim Daly
4618	Tim Gail
4619	Tim Henry
4620	Tim Herbert
4621	Tim Holt
4622	Tim Matheson
4623	Tim McIntire
4624	Tim Meadows
4625	Tim Robbins
4626	Tim Roth
4627	Tim Rozon
4628	Tim Thomerson
4629	Timothy Bottoms
4630	Timothy Busfield
4631	Timothy Carhart
4632	Timothy Dalton
4633	Timothy Hutton
4634	Timothy Olyphant
4635	Timothy Spall
4636	Timothy Van Patten
4637	Tina Aumont
4638	Tina Holmes
4639	Tina Louise
4640	Tina Majorino
4641	Tina Turner
4642	Tippi Hedren
4643	Tisa Farrow
4644	Tobey Maguire
4645	Toby Robins
4646	Tod Slaughter
4647	Todd Graff
4648	Tom Arnold
4649	Tom Atkins
4650	Tom Baker
4651	Tom Berenger
4652	Tom Bosley
4653	Tom Burlinson
4654	Tom Butler
4655	Tom Chapin
4656	Tom Charlfa
4657	Tom Conti
4658	Tom Courtenay
4659	Tom Cruise
4660	Tom Drake
4661	Tom Everett Scott
4662	Tom Ewell
4663	Tom Felton
4664	Tom Gaman
4665	Tom Guiry
4666	Tom Hanks
4667	Tom Helmore
4668	Tom Hiddleston
4669	Tom Hulce
4670	Tom Irwin
4671	Tom Keene
4672	Tom McCamus
4673	Tom Naylor
4674	Tom Neal
4675	Tom Petty
4676	Tom Poston
4677	Tom Savini
4678	Tom Selleck
4679	Tom Sizemore
4680	Tom Skerritt
4681	Tom Stern
4682	Tom Tryon
4683	Tom Waits
4684	Tom Welling
4685	Tom Wilkinson
4686	Tom Wright
4687	Tommy 'Tiny' Lister
4688	Tommy Bone
4689	Tommy Chong
4690	Tommy Flanagan
4691	Tommy Lee Jones
4692	Tommy Rall
4693	Tommy Rettig
4694	Tommy Strasz
4695	Tone Loc
4696	Toni Collette
4697	Toni Kalem
4698	Tony Barry
4699	Tony Becker
4700	Tony Curtis
4701	Tony Doyle
4702	Tony Goldwyn
4703	Tony Hawk
4704	Tony Lo Bianco
4705	Tony Martin
4706	Tony Mascia
4707	Tony Randall
4708	Tony Roberts
4709	Tony Shalhoub
4710	Tony Todd
4711	Topol
4712	Torin Thatcher
4713	ToshirÃ´ Mifune
4714	Touriya Haoud
4715	Tracey Ullman
4716	Tracey Walter
4717	Tran Manh Cuong
4718	Travis Tedford
4719	Treat Williams
4720	Trevor Howard
4721	Trevor Steedman
4722	Trey Wilson
4723	Tricia O'Neil
4724	Tricia Vessey
4725	Trini Alvarado
4726	Trish Van Devere
4727	TristÃ¡n Ulloa
4728	Troy Donahue
4729	Trudy Marshall
4730	Truman Capote
4731	Tsewang Migyur Khangsar
4732	Tuesday Knight
4733	Tuesday Weld
4734	Tung Thanh Tran
4735	Tupac Shakur
4736	Tura Satana
4737	Tusse Silberg
4738	Ty Hardin
4739	Tyne Daly
4740	Tyra Ferrell
4741	Tyrin Turner
4742	Tyrone Power
4743	Tzi Ma
4744	TÃ©a Leoni
4745	Udo Kier
4746	Ulrich MÃ¼he
4747	Ulrich Noethen
4748	Uma Thurman
4749	Una Merkel
4750	Upendra Limaye
4751	Ursula Andress
4752	Ursula Weiss
4753	Val Kilmer
4754	Valentina Cortese
4755	Valeri Nikolayev
4756	Valeria Golino
4757	Valerie Buhagiar
4758	Valerie Cruz
4759	Valerie Gearon
4760	Valerie Hobson
4761	Valerie Perrine
4762	ValÃ©rie Benguigui
4763	ValÃ©rie Kaprisky
4764	Van Heflin
4765	Van Johnson
4766	Vanda Godsell
4767	Vanessa Angel
4768	Vanessa L. Williams
4769	Vanessa Lee Chester
4770	Vanessa Redgrave
4771	Vanity
4772	Veerendra Saxena
4773	Vera Ellen
4774	Vera Farmiga
4775	Vera Miles
4776	Verna Bloom
4777	Verna Felton
4778	Vernon Downing
4779	Vernon Wells
4780	Veronica Carlson
4781	Veronica Cartwright
4782	Veronica Hart
4783	Veronica Lake
4784	Vic Damone
4785	Vicki Frederick
4786	Vicki Lewis
4787	Vicky Tiu
4788	Victor Argo
4789	Victor Buono
4790	Victor Jory
4791	Victor Lundin
4792	Victor Mature
4793	Victor McLaglen
4794	Victor Slezak
4795	Victor Spinetti
4796	Victor Wong
4797	Victoria Davis
4798	Victoria Jackson
4799	Victoria Longley
4800	Victoria Medlin
4801	Victoria Tennant
4802	Vidal Peterson
4803	Viggo Mortensen
4804	Vin Diesel
4805	Vince Edwards
4806	Vince Vaughn
4807	Vincent D'Onofrio
4808	Vincent Gardenia
4809	Vincent Klyn
4810	Vincent Perez
4811	Vincent Price
4812	Vincent Spano
4813	Vincent Van Patten
4814	Vinessa Shaw
4815	Ving Rhames
4816	Viola Davis
4817	Vira Montes
4818	Virginia Bruce
4819	Virginia Grey
4820	Virginia Madsen
4821	Virginia Mayo
4822	Virginia Walker
4823	Virna Lisi
4824	Vittorio De Sica
4825	Vittorio Gassman
4826	Vivean Gray
4827	Vivian Pickles
4828	Vivica A. Fox
4829	Vivien Leigh
4830	Vivien Merchant
4831	Vladimir Kulich
4832	Vladimir Radian
4833	Vladimir Sokoloff
4834	Vladimir Vdovichenkov
4835	Vonetta McGee
4836	VÃ©ra Clouzot
4837	W.C. Fields
4838	Wade Dominguez
4839	Walker Jones
4840	Wallace Beery
4841	Wallace Ford
4842	Wallace Shawn
4843	Walter Barnes
4844	Walter Brennan
4845	Walter Connolly
4846	Walter Fitzgerald
4847	Walter Hampden
4848	Walter Huston
4849	Walter Matthau
4850	Walter Pidgeon
4851	Ward Bond
4852	Ward Costello
4853	Warner Baxter
4854	Warner Oland
4855	Warren Ball
4856	Warren Beatty
4857	Warren Clarke
4858	Warren Oates
4859	Warren Stevens
4860	Warwick Davis
4861	Weird Al Yankovic
4862	Wendel Meldrum
4863	Wendell Corey
4864	Wendell Pierce
4865	Wendy Allnutt
4866	Wendy Crewson
4867	Wendy Gazelle
4868	Wendy Hiller
4869	Wendy Makkena
4870	Wes Bentley
4871	Wesley Addy
4872	Wesley Snipes
4873	Whitney Houston
4874	Whoopi Goldberg
4875	Wil Wheaton
4876	Wiley Wiggins
4877	Wilford Brimley
4878	Wilfred Lucas
4879	Wilfred Pickles
4880	Wilfrid Hyde-White
4881	Will Arnett
4882	Will Ferrell
4883	Will Geer
4884	Will Hutchins
4885	Will Patton
4886	Will Sampson
4887	Will Smith
4888	Willem Dafoe
4889	William Atherton
4890	William Baldwin
4891	William Bendix
4892	William Carroll
4893	William Conrad
4894	William Daniels
4895	William Demarest
4896	William Devane
4897	William Dulaney
4898	William E. Arnold Jr.
4899	William Elliott
4900	William Fichtner
4901	William Finley
4902	William Forsythe
4903	William H. Macy
4904	William Harrigan
4905	William Hartnell
4906	William Hickey
4907	William Holden
4908	William Hootkins
4909	William Hopper
4910	William Hurt
4911	William Katt
4912	William Kerwin
4913	William Lundigan
4914	William McNamara
4915	William Mervyn
4916	William Morgan Sheppard
4917	William O'Leary
4918	William Petersen
4919	William Powell
4920	William Prince
4921	William Ragsdale
4922	William Redfield
4923	William Reynolds
4924	William Richert
4925	William Roerick
4926	William Russ
4927	William Sadler
4928	William Sanderson
4929	William Shatner
4930	William Smith
4931	William Snape
4932	William Swan
4933	William Takaku
4934	William Vail
4935	William Windom
4936	Willie Nelson
4937	Willow Smith
4938	Wilson Cruz
4939	Wilt Chamberlain
4940	Wings Hauser
4941	Winona Ryder
4942	Wojciech Pszoniak
4943	Wolfgang Bodison
4944	Wolfgang Preiss
4945	Wolfman Jack
4946	Woodrow Parfrey
4947	Woody Allen
4948	Woody Harrelson
4949	Woody Strode
4950	Wyatt Knight
4951	Xander Berkeley
4952	Yale Wexler
4953	Yamil Borges
4954	Yancy Butler
4955	Yaphet Kotto
4956	Yasmine Belmadi
4957	Ye Liu
4958	Yoko Tani
4959	Yorgo Voyagis
4960	Youki Kudoh
4961	Yul Brunner
4962	Yul Brynner
4963	Yun-ah Song
4964	Yves Afonso
4965	Yves Beneyton
4966	Yves Lavigne
4967	Yvette Mimieux
4968	Yvette Nipar
4969	Yvonne Craig
4970	Yvonne De Carlo
4971	Yvonne Elliman
4972	Yvonne Furneaux
4973	Yvonne Zima
4974	Zach Galifianakis
4975	Zach Galligan
4976	Zachary David Cope
4977	Zachary Ittimangnaq
4978	Zachary Knighton
4979	Zachary Mabry
4980	Zachary Scott
4981	Zack Norman
4982	Zakes Mokae
4983	Zeppo Marx
4984	Zoe Saldana
4985	Zohra Lampert
4986	Zooey Deschanel
\.


--
-- Name: actors_actor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('actors_actor_id_seq', 1, false);


--
-- Data for Name: cities; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY cities (name, postal_code, country_code) FROM stdin;
Portland	97205	us
Berlin	12157	de
Dortmund	44339	de
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY comments (comment_id, movie_id, comment) FROM stdin;
1	65	Endlessly imitated, The Terminator made the reputation of cowriter/director James Cameron\n - who would go on to make 1997's titanic Titanic -and solidified the stardom of Arnold\nSchwarzenegger.
2	65	Iats a preitty guuad Moofie. I akted mysoilf
3	171	Sterben Muddafucker!!!
4	171	Bruce Willays, ey!
\.


--
-- Name: comments_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('comments_comment_id_seq', 4, true);


--
-- Data for Name: countries; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY countries (country_code, country_name) FROM stdin;
us	United States
mx	Mexico
au	Australia
gb	United Kingdom
de	Germany
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY events (event_id, title, starts, ends, venue_id, colors) FROM stdin;
2	April Fools Day	2012-04-01 00:00:00	2012-04-01 23:59:59	\N	\N
3	Christmas Day	2012-12-25 00:00:00	2012-12-25 23:59:59	\N	\N
1	LARP Club	2012-02-15 17:30:00	2012-02-15 19:30:00	2	\N
4	Moby	2014-03-12 21:00:00	2014-03-12 23:00:00	1	\N
5	Wedding	2014-02-26 21:00:00	2014-02-26 23:00:00	2	\N
6	Dinner with Mom	2014-03-26 18:00:00	2014-03-26 20:30:00	4	\N
7	Valentine's Day	2014-02-14 00:00:00	2014-02-14 23:59:00	\N	\N
8	House Party	2012-05-03 23:00:00	2012-05-04 01:00:00	5	\N
\.


--
-- Name: events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('events_event_id_seq', 8, true);


--
-- Data for Name: genres; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY genres (name, "position") FROM stdin;
Action	1
Adventure	2
Animation	3
Comedy	4
Crime	5
Disaster	6
Documentary	7
Drama	8
Eastern	9
Fantasy	10
History	11
Horror	12
Musical	13
Romance	14
SciFi	15
Sport	16
Thriller	17
Western	18
\.


--
-- Data for Name: logs; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY logs (event_id, old_title, old_starts, old_ends, logged_at) FROM stdin;
8	House Party	2012-05-03 23:00:00	2012-05-04 02:00:00	2014-02-04 22:38:58.691075
\.


--
-- Data for Name: movies; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY movies (movie_id, title, genre) FROM stdin;
1	Star Wars	(0, 7, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 10, 0, 0, 0)
2	Forrest Gump	(0, 0, 0, 5, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
3	American Beauty	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
4	Citizen Kane	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
5	The Dark	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
6	The Fifth Element	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
7	Apocalypse Now	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
8	Unforgiven	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
9	Twelve Monkeys	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 7, 0, 7, 0)
10	Absolute Power	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
11	Brazil	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0)
12	American History X	(0, 0, 0, 0, 5, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
13	Mars Attacks!	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0)
14	Before Sunrise	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
15	Blade Runner	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0)
16	Raiders of the Lost Ark	(7, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
17	Indiana Jones and the Temple of Doom	(7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
18	Dirty Dancing	(0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0)
19	Indiana Jones and the Last Crusade	(10, 10, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
20	Beverly Hills Cop	(7, 0, 0, 7, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
21	Anatomy of a Murder	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
22	Armageddon	(5, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
23	Beverly Hills Cop II	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
24	Tron	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
25	Gladiator	(5, 0, 0, 0, 0, 0, 0, 10, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0)
26	Taxi Driver	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
27	Back to the Future	(0, 5, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
28	Predator	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 7, 0, 0, 7, 0, 0, 0)
29	Scarface	(5, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
30	Pretty Woman	(0, 0, 0, 10, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
31	The Big Lebowski	(0, 0, 0, 10, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
32	The Untouchables	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
33	Freaks	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
34	Groundhog Day	(0, 0, 0, 7, 0, 0, 0, 5, 0, 10, 0, 0, 0, 0, 5, 0, 0, 0)
35	Dracula	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
36	All Quiet on the Western Front	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
37	Breaking The Waves	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
38	48 Hrs.	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
39	Star Trek - The Motion Picture	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
40	Star Trek II - The Wrath of Khan	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
41	Star Trek III - The Search for Spock	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
42	Ocean's Eleven	(0, 0, 0, 7, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
43	Edward Scissorhands	(0, 0, 0, 0, 0, 0, 0, 10, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0)
44	Breakfast at Tiffany's	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
45	Back to the Future Part II	(0, 10, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0)
46	Star Trek IV - The Voyage Home	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
47	Predator 2	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
48	Star Trek V - The Final Frontier	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
49	Star Trek VI - The Undiscovered Country	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
50	The Fisher King	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
51	Blown Away	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
52	The Wizard	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
53	Jackie Brown	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
54	A Clockwork Orange	(0, 0, 0, 10, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
55	Star Trek - Generations	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
56	Trouble in Paradise	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
57	Braveheart	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
58	To Be or Not To Be	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
59	Star Trek - First Contact	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0)
60	Star Trek - Insurrection	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
61	Mean Streets	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
62	Dead Poets Society	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
63	Arsenic and Old Lace	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
64	North by Northwest	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
65	The Terminator	(5, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 12, 0, 10, 0)
66	East of Eden	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
67	Rebel Without a Cause	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
68	Rebecca	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
69	Boys Don't Cry	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
70	The Outsiders	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
71	Rumble Fish	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
72	The Wanderers	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
73	Stand By Me	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
74	Muriel's Wedding	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
75	The Godfather	(0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
76	Some Like It Hot	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
77	The Godfather Part II	(0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
78	Natural Born Killers	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
79	The Godfather Part III	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
80	King Kong	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
81	The Killing	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
82	Pocketful of Miracles	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
83	The War of the Roses	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
84	Ghost	(0, 0, 0, 7, 0, 0, 0, 7, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0)
85	Live and Let Die	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
86	Oliver Twist	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
87	The 39 Steps	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
88	Cat on a Hot Tin Roof	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
89	Lili Marleen	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
90	Batman	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
91	The Silence of the Lambs	(0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 7, 0)
92	Fargo	(0, 0, 0, 5, 7, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
93	The Shawshank Redemption	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
94	Amadeus	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0)
95	Terminator 2: Judgment Day	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 7, 0)
96	Strange Days	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
97	The Apartment	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
98	Bull Durham	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
99	High Noon	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
100	Casablanca	(0, 0, 0, 0, 10, 0, 0, 10, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
101	Barton Fink	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
102	Desert Hearts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
103	Meet Joe Black	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
104	Rio Bravo	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
105	Notorious	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0)
106	Beverly Hills Cop III	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
107	Once Upon a Time in America	(0, 0, 0, 0, 10, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
108	Faster Pussycat! Kill! Kill!	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
109	True Romance	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
110	Jurassic Park	(0, 7, 0, 0, 0, 7, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0)
111	The Lost World: Jurassic Park	(7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
112	Magnolia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
113	Once Upon A Time In The West	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10)
114	Night on Earth	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
115	Harold and Maude	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
116	Eyes Wide Shut	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
117	Alien	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 10, 0, 0, 0)
118	Batman Returns	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
119	A Nightmare on Elm Street	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
120	Raising Arizona	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
121	Miller's Crossing	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
122	Rain Man	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
123	To Catch a Thief	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
124	Who's Afraid of Virginia Woolf?	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
125	French Kiss	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
126	Things to Do in Denver When You're Dead	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
127	Basic Instinct	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
128	Driving Miss Daisy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
129	The Straight Story	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
130	The English Patient	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
131	Batman Forever	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
132	Schindler's List	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
133	Vertigo	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
134	The Good, The Bad, and the Ugly	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7)
135	One, Two, Three	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
136	Mary Poppins	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
137	Leaving Las Vegas	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
138	William Shakespeare's Romeo + Juliet	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
139	Klute	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
140	My Own Private Idaho	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
141	Stranger Than Paradise	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
142	Bonnie and Clyde	(0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
143	Drugstore Cowboy	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
144	Wild at Heart	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
145	The African Queen	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
146	Good Will Hunting	(0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
147	Being John Malkovich	(0, 0, 0, 7, 0, 0, 0, 5, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0)
148	The Green Mile	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
149	Reservoir Dogs	(0, 0, 0, 7, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
150	Fail-Safe	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0)
151	Marnie	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
152	Killing Zoe	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
153	Notting Hill	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
154	One Flew Over The Cuckoo's Nest	(0, 0, 0, 7, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
155	Promised Land	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
156	Dial M For Murder	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
157	Ed Wood	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
158	Casino	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
159	The Blues Brothers	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0)
160	Ladyhawke	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
161	Once Were Warriors	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
162	Flashdance	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
163	Psycho	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
164	Blackmail	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
165	There's Something About Mary	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
166	The Horse Whisperer	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
167	Basquiat	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
168	Fight Club	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
169	The Poseidon Adventure	(0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
170	Secret Beyond the Door	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
171	Die Hard	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
172	Starship Troopers	(12, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 7, 0, 0, 0)
173	The Mummy	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
174	Shadow of a Doubt	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
175	Rear Window	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
176	Apollo 13	(0, 0, 0, 0, 0, 10, 0, 10, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
177	Romance	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
178	The Birds	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
179	Frenzy	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
180	The Man Who Knew Too Much	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
181	The Wild Bunch	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
182	To Die For	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
183	Jaws	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
184	Jaws 2	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
185	Dances with Wolves	(0, 7, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10)
186	Wag The Dog	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
187	The Conversation	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
188	To kill a Mockingbird	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
189	The Grapes of Wrath	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
190	Titanic	(0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
191	Sunset Blvd.	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
192	Full Metal Jacket	(7, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
193	E.T. The Extra-Terrestrial	(0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
194	Independence Day	(5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
195	The Matrix	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
196	Out of Africa	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
197	Men In Black	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
198	Poltergeist	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
199	Wild Things	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
200	The Bodyguard	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0)
201	Ghostbusters	(0, 0, 0, 7, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 7, 0, 0, 0)
202	Grease	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
203	The Ninth Gate	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 10, 0)
204	A Fish Called Wanda	(0, 0, 0, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
205	Easy Rider	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
206	The Killing Fields	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
207	Trainspotting	(0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
208	The Usual Suspects	(0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
209	The Wizard of Oz	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0)
210	Stalag 17	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
211	Angel Heart	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
212	THX 1138	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
213	Lost Highway	(0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
214	When Harry Met Sally	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
215	Butch Cassidy and the Sundance Kid	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
216	Dr. No	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
217	Boyz N The Hood	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
218	M.A.S.H.	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
219	On the Waterfront	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
220	Paris, Texas	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
221	From Russia with Love	(10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
222	Goldfinger	(12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
223	Thunderball	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
224	Twister	(5, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
225	Ben-Hur	(0, 7, 0, 0, 0, 0, 0, 10, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0)
226	You Only Live Twice	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
227	On Her Majesty's Secret Service	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
228	Out of the Past	(0, 0, 0, 0, 5, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
229	Aliens	(10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 10, 0, 5, 0)
230	Pulp Fiction	(0, 0, 0, 12, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
231	Diamonds Are Forever	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
232	The Man with the Golden Gun	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
233	Contact	(0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
234	Dead Man Walking	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
235	The Bridges Of Madison County	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
236	The Spy Who Loved Me	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
237	The Shining	(0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 12, 0, 0, 0, 0, 10, 0)
238	Short Cuts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
239	Manhattan	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
240	Moonraker	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
241	For Your Eyes Only	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
242	Octopussy	(7, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
243	A Streetcar Named Desire	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
244	Annie Hall	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
245	A Hard Day's Night	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
246	All About Eve	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
247	A View to a Kill	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
248	The Living Daylights	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
249	GoldenEye	(7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
250	Four Weddings And A Funeral	(0, 0, 0, 7, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
251	The Piano	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
252	Tomorrow Never Dies	(10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
253	True Lies	(7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
254	Time Bandits	(0, 5, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
255	The Truman Show	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
256	The Rocky Horror Picture Show	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 5, 0, 0, 0)
257	The Muse	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
258	The World Is Not Enough	(7, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
259	Casino Royale	(12, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
260	Falling Down	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
261	The Firm	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
262	The Graduate	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
263	A Night at the Opera	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
264	Blade	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 12, 0, 0, 0, 0, 10, 0)
265	Witness for the Prosecution	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
266	Never Say Never Again	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
267	Top Gun	(10, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
268	The Sixth Sense	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 5, 0, 0, 0, 0, 7, 0)
269	The Last Emperor	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
270	Murder, She Said	(0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
271	Murder at the Gallop	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
272	Faces	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
273	Face/Off	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
274	From Dusk Till Dawn	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0)
275	Murder Most Foul	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
276	Murder Ahoy!	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
277	Gentlemen Prefer Blondes	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
278	Monty Python and the Holy Grail	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
279	The Evil Dead	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
280	Evil Dead II	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0)
281	Army of Darkness	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
282	Goodfellas	(0, 0, 0, 0, 7, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
283	Gone with the Wind	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
284	Home Alone	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
285	Home Alone 2 - Lost in New York	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
286	Gattaca	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
287	Gandhi	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
288	Mrs. Doubtfire	(0, 0, 0, 7, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
289	The Fog	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
290	Platoon	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
291	Blue Velvet	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
292	The Omen	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
293	City Of Angels	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
294	Cruel Intentions	(0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0)
295	Good Morning, Vietnam	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
296	Lolita	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
297	Roman Holiday	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
298	Rosemary's Baby	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
299	Se7en	(0, 0, 0, 0, 7, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 7, 0)
300	Silent Running	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
301	Airplane!	(0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
302	An American Werewolf In London	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
303	Austin Powers: International Man Of Mystery	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
304	Austin Powers: The Spy Who Shagged Me	(7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
305	Sleepers	(0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
306	JFK	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
307	Judgment at Nuremberg	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
308	Moulin Rouge!	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
309	Playing by Heart	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
310	The Bridge on the River Kwai	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
311	Diabolique	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
312	The Day the Earth Stood Still	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
313	Chinatown	(0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
314	Forbidden Planet	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
315	This Island Earth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
316	M	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
317	Videodrome	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
318	Duel	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
319	Close Encounters of the Third Kind	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
320	Dune	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
321	Strangers on a Train	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
322	The X Files	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
323	Willow	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
324	Dragonslayer	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
325	Krull	(0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 7, 0, 0, 0)
326	Brief Encounter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
327	The Mask	(0, 0, 0, 5, 5, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
328	Who Framed Roger Rabbit	(0, 0, 5, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
329	Saving Private Ryan	(7, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
330	Sleepless in Seattle	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
331	Dangerous Liaisons	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
332	WarGames	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
333	Total Recall	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 5, 0)
334	Toy Story	(0, 5, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
335	Toy Story 2	(0, 5, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
336	Cool Runnings	(0, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
337	The Running Man	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
338	Finding Neverland	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
339	Sliver	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
340	Planet of the Apes	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
341	Dolls	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
342	Singin' in the Rain	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
343	The Color Purple	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
344	A Man for All Seasons	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
345	Shanghai Express	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
346	Hook	(0, 7, 0, 7, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0)
347	A Few Good Men	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
348	Crash	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
349	The Cincinnati Kid	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
350	The Best Years of Our Lives	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
351	The Flintstones	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
352	All the President's Men	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
353	Birdman of Alcatraz	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
354	Bringing Up Baby	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
355	Cool Hand Luke	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
356	Meet Me in St. Louis	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
357	The Big Sleep	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
358	The Bank Dick	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
359	The Thomas Crown Affair	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
360	The Great Dictator	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
361	Bullitt	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
362	Blind Date	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
363	Dead Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
364	Dawn of the Dead	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0)
365	Do the Right Thing	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
366	Galaxy Quest	(0, 5, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0)
367	Gremlins	(5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
368	Gremlins 2: The New Batch	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
369	Godzilla	(5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
370	Donâ€™t Look Now	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
371	The Pink Panther	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
372	The Jazz Singer	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
373	The Lady Vanishes	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
374	Lethal Weapon	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
375	Lethal Weapon 2	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
376	Lethal Weapon 3	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
377	Lethal Weapon 4	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
378	Letter from an Unknown Woman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
379	Lawrence of Arabia	(0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0)
380	Halloween	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
381	Heat	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
382	Kindergarten Cop	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
383	Mission: Impossible	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
384	Spaceballs	(0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0)
385	The General	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
386	The Maltese Falcon	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
387	The Phantom of the Opera	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
388	The Magnificent Ambersons	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
389	The Magnificent Seven	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
390	Spartacus	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
391	Dog Day Afternoon	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
392	Paths of Glory	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
393	Sweet Smell of Success	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
394	Seven Years in Tibet	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
395	The Ox-Bow Incident	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
396	The Philadelphia Story	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
397	The Manchurian Candidate	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
398	The Man Who Would Be King	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
399	Dirty Harry	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
400	The Front Page	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
401	The China Syndrome	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
402	The Mortal Storm	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
403	The Hustler	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
404	The Man Who Fell To Earth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
405	Sleuth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
406	Straw Dogs	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
407	Double Indemnity	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
408	Heavenly Creatures	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
409	Sommersby	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
410	The French Connection	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
411	Blowup	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
412	Breathless	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
413	Arlington Road	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
414	Point Break	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
415	The Thirteenth Floor	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
416	The Thing	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
417	The Third Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
418	Escape from New York	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
419	The Miracle Worker	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
420	The Talented Mr. Ripley	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
421	The Remains of the Day	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
422	Lonely Hearts	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
423	Sunshine	(0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 7, 0, 5, 0)
424	Bean	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
425	The Hi-Lo Country	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
426	Rocky	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
427	Rocky II	(10, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
428	First Blood	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
429	Rambo III	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
430	Rocky III	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
431	Rocky IV	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
432	Rocky V	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
433	Houseboat	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
434	Gleaming the Cube	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
435	Out of Sight	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
436	Duel at Diablo	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
437	City Slickers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
438	Cutthroat Island	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
439	Dark Star	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
440	The Rapture	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0)
441	Sex, Lies, and Videotape	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
442	M. Butterfly	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
443	Anna and the King	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
444	The Virgin Suicides	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
445	Touch of Evil	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
446	Laws of Gravity	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
447	Get Carter	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
448	1492: Conquest of Paradise	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
449	Teenage Mutant Ninja Turtles	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
450	Office Space	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
451	The Lost Boys	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
452	Flatliners	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
453	Parenthood	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
454	Down By Law	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
455	Die Hard with a Vengeance	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
456	Raging Bull	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
457	Rope	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
458	It's a Wonderful Life	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
459	What's Eating Gilbert Grape	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
460	Primal Fear	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
461	A Shot in the Dark	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
462	Cape Fear	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
463	A Bronx Tale	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
464	When Saturday Comes	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
465	Fever Pitch	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
466	Still Crazy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
467	Trading Places	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
468	Brubaker	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
469	The People vs. Larry Flynt	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
470	Mississippi Burning	(0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
471	Fried Green Tomatoes	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
472	Free Willy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
473	The Island	(12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0)
474	Bedazzled	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
475	Speed	(7, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
476	Forces of Nature	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
477	The Net	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
478	Last Tango in Paris	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
479	The Vanishing	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
480	A Time to Kill	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
481	The Dirty Dozen	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
482	State of Grace	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
483	The Hunt for Red October	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
484	Comanche Station	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
485	Will Penny	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
486	Escape from the Planet of the Apes	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
487	Little Buddha	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
488	Re-animator	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
489	Misery	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
490	Con Air	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
491	Battle for the Planet of the Apes	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
492	Copycat	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
493	Giant	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
494	Fahrenheit 451	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
495	The Cider House Rules	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
496	All the King's Men	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
497	The Front	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
498	West Side Story	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
499	Bird on a wire	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
500	The Prisoner of Zenda	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
501	Michael Collins	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
502	City of Hope	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
503	American Madness	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
504	Canadian Bacon	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
505	Barbarella	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0)
506	Footloose	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
507	The Gazebo	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
508	Heaven with a Gun	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
509	Angel	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
510	Velvet Goldmine	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
511	Viva Zapata !	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
512	Nowhere	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
513	A Chorus Line	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
514	Dogma	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
515	Murder My Sweet	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
516	Farewell My Lovely	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
517	Entrapment	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
518	Marlowe	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
519	The Long Goodbye	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
520	Nine Hours to Rama	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
521	Man on the Moon	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
522	Ninotchka	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
523	Fear and Loathing in Las Vegas	(0, 0, 0, 10, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
524	Guess who's coming to dinner	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
525	Red Dawn	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
526	The Men	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
527	Malcolm X	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
528	The Karate Kid	(0, 0, 0, 0, 0, 0, 0, 7, 7, 0, 0, 0, 0, 0, 0, 5, 0, 0)
529	Marie Antoinette	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
530	The Fortune Cookie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
531	Children of a Lesser God	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
532	Star Wars: Episode V - The Empire Strikes Back	(0, 7, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 2, 10, 0, 0, 0)
533	Star Wars: Episode I - The Phantom Menace	(7, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 10, 0, 0, 0)
534	Salvador	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
535	Inherit The Wind	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
536	Don Juan DeMarco	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
537	The 13th Warrior	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0)
538	Crime of Passion	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
539	Sweet November	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
540	Twin Peaks: Fire Walk With Me	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
541	Shakespeare in Love	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
542	River of No Return	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
543	Bonjour tristesse	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
544	Angel Face	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
545	Laura	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
546	Porgy and Bess	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
547	Exodus	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
548	Bunny Lake Is Missing	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
549	Nell	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
550	eXistenZ	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0)
551	The Elephant Man	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
552	Swept from the Sea	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
553	A Perfect Murder	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
554	Fools Rush In	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
555	Jezebel	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
556	Stage Fright	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
557	The Most Dangerous Game	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
558	Sister Act	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
559	Bell, Book and Candle	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
560	Lorenzo's Oil	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
561	Hard Target	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
562	Jack & Sarah	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
563	Say Anything	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
564	Infinity	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
565	Moonstruck	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
566	Savior	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
567	The Real McCoy	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
568	Mr. Holland's Opus	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
569	Addicted to Love	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
570	While you were Sleeping	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
571	Shattered	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
572	Flirting with Disaster	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
573	Prizzi's Honor	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
574	Nick of Time	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
575	The Getaway	(7, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
576	Romeo is Bleeding	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0)
577	Wish You Were Here	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0)
578	Roustabout	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
579	Viva Las Vegas	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
580	Raw Deal	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
581	American Pie	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
582	Hot Enough for June	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
583	L.A. Story	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
584	The Breakfast Club	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
585	Rush Hour	(5, 0, 0, 7, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0)
586	Payback	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
587	Light of Day	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
588	L.A. Confidential	(0, 0, 0, 0, 12, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
589	Days of Thunder	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
590	The Time Machine	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
591	Cleopatra Jones and the Casino of Gold	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
592	Cop Land	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
593	Carla's Song	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
594	The Cotton Club	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0)
595	The Driver	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
596	Lost in Space	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
597	Voyage to the Bottom of the Sea	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
598	Fantastic Voyage	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
599	Breakdown	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
600	Stargate	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
601	Heartbreak Hotel	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
602	Attack of the Killer Tomatoes!	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
603	Big Trouble	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
604	Lassie Come Home	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
605	Earth, Girls are Easy	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0)
606	Nightwatch	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
607	Christine	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
608	Malice	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
609	Chasing Amy	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
610	Music Box	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
611	Stardust	(0, 7, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0)
612	The General's Daughter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
613	Bicentennial Man	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
614	Big	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
615	Jakob the Liar	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
616	Jacob's Ladder	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0, 0, 5, 0)
617	Clerks	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
618	Mallrats	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
619	Kafka	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
620	Avalon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
621	Executive Decision	(5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
622	Married to the Mob	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
623	Sneakers	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
624	Field of Dreams	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
625	Taxi	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
626	Holy Matrimony	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
627	Saving Grace	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
628	Westworld	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 5)
629	Topaz	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
630	The Greatest Story Ever Told	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
631	The Country Girl	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
632	The Spider Woman	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
633	Harley Davidson and the Marlboro Man	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
634	The Princess Bride	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
635	Our Mother's House	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
636	Madame Bovary	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
637	The Diary of Anne Frank	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
638	Born on the Fourth of July	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
639	Short Circuit	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
640	Maid to Order	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
641	Only the Lonely	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
642	Mr. Destiny	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
643	Prelude to a Kiss	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
644	InnerSpace	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
645	Uncle Buck	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
646	The Great Outdoors	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
647	Splash	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
648	Armed and Dangerous	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
649	An Officer and a Gentleman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
650	Mr. Jones	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
651	The Specialist	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
652	Deconstructing Harry	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
653	Heathers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
654	The Game	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
655	In the Mouth of Madness	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
656	Pleasantville	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
657	Airplane II: The Sequel	(0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
658	Dark City	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
659	The Blair Witch Project	(0, 0, 0, 0, 0, 0, 0, 10, 0, 12, 0, 12, 0, 0, 0, 0, 12, 0)
660	Sleepy Hollow	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 7, 0, 0, 0, 0, 7, 0)
661	The Bounty	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
662	The Texas Chainsaw Massacre	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
663	Memoirs of an Invisible Man	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
664	Irma la Douce	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
665	Nemesis	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
666	Naked Lunch	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
667	The Borrowers	(0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
668	Viaggio in Italia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
669	The Abyss	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
670	Addams Family Values	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
671	The Adventures of Priscilla, Queen of the Desert	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
672	The Lodger	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
673	Secret Agent	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
674	Young and Innocent	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
675	American Gigolo	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
676	An American in Paris	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
677	Clifford	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
678	Reality Bites	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
679	Oscar	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
680	Breaking Glass	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
681	An Angel at My Table	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
682	Angel Baby	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
683	The Apostle	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
684	Around the World in Eighty Days	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
685	As Good as It Gets	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
686	The Astronaut's Wife	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
687	The Addams Family	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
688	Backdraft	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
689	The First Wives Club	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
690	The Three Musketeers	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
691	Michael	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
692	Frankenstein	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
693	20.000 Leagues under the Sea	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
694	Hairspray	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
695	Ghostbusters II	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
696	The Lost World	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 4, 0, 0, 0)
697	Pacific Heights	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
698	Masquerade	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
699	Zabriskie Point	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
700	How to Steal a Million	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
701	The NeverEnding Story	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
702	Dr. Jekyll and Mr. Hyde	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
703	10:30 P.M. Summer	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
704	The Cardinal	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
705	Good Neighbor Sam	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
706	The Man Between	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
707	Abbott and Costello meet Dr. Jekyll and Mr. Hyde	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
708	The Two Faces of Dr. Jekyll	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
709	Island of Lost Souls	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
710	Gods and Monsters	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
711	Young Frankenstein	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
712	Ace Ventura: Pet Detective	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
713	Doctor Dolittle	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
714	Eye of the Devil	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
715	Don't Make Waves	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
716	The Fearless Vampire Killers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
717	The Wrecking Crew	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
718	Valley of the Dolls	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
719	42nd Street	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
720	Duck Soup	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
721	Frankenstein Unbound	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
722	The Ghost of Frankenstein	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0)
723	Frankenstein must be Destroyed	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
724	Frankenstein meets the Wolf Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
725	Son of Frankenstein	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
726	It Happened One Night	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
727	The Curse of Frankenstein	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
728	Top Hat	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
729	The Goddess	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
730	Mr. Smith Goes to Washington	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
731	Wuthering Heights	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
732	His Girl Friday	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
733	The Lady Eve	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
734	My Darling Clementine	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
735	Red River	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
736	The Treasure of the Sierra Madre	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
737	SÃ©ance on a Wet Afternoon	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
738	I Love You to Death	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
739	House of Frankenstein	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0)
740	Frankenstein Created Woman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
741	The Quiet Man	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
742	Shane	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
743	A Star Is Born	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
744	The Searchers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
745	Midnight Cowboy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
746	Nashville	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
747	The Revenge of Frankenstein	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
748	Bad Company	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
749	Badlands	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
750	Barry Lyndon	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
751	Mildred Pierce	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
752	Far from the Madding Crowd	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
753	The Face of Fu Manchu	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
754	The Train	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0)
755	The Mask of Fu Manchu	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
756	Under Siege 2: Dark Territory	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
757	Legionnaire	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
758	Working Girl	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
759	Frances	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
760	The Thin Man	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
761	Fame	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
762	Reflections in a Golden Eye	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
763	Mahogany	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
764	Girl, Interrupted	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
765	Underground	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
766	Emma	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
767	Calling Dr. Gillespie	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
768	The Millionairess	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
769	It Happened Tomorrow	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
770	One Million Years B.C.	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
771	One Million B.C.	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
772	Dr. Cyclops	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
773	Ransom	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
774	Things to Come	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
775	Flash Gordon	(5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
776	Heat Wave	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
777	What's New, Pussycat	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
778	54	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
779	The Desert Hawk	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
780	Royal Wedding	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
781	An Eye for an Eye	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
782	The Lady from Shanghai	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
783	Gilda	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
784	Frankie and Johnny	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
785	Rain	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
786	Blondie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
787	Blondie bring's up Baby	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
788	Blondie Takes a Vacation	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
789	Blondie meets the Boss	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
790	Sweeney Todd: The Demon Barber of Fleet Street	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0)
791	Blondie has Servant Trouble	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
792	Blondie on a Budget	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
793	Blondie Plays Cupid	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
794	Blondie in Society	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
795	Blondie goes Latin	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
796	Blondie Goes to College	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
797	Footlight Glamour	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
798	It's a Great Life	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
799	Critters	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
800	Beetle Juice	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
801	The Prize	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
802	My Girl	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
803	Black Rain	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
804	Blondie of the Follies	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
805	Blondie Johnson	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
806	Cold Comfort	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
807	Three Seasons	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
808	Paul and Michelle	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
809	Friends	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
810	Over the Edge	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
811	Spellbound	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
812	Under Capricorn	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
813	Murder on the Orient Express	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
814	Mad Love	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
815	Death on the Nile	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
816	Evil under the Sun	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
817	The Man in the Iron Mask	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
818	Scream	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
819	Scream 2	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
820	Pretty Poison	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
821	Appointment with Death	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
822	Bordertown	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
823	Triple Cross	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
824	Dallas Doll	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
825	Shall We Dance?	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
826	The Brave One	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
827	G.I. Jane	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
828	Candy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
829	Svengali	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
830	Decision Before Dawn	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
831	Diplomatic Courier	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
832	Legends of the Fall	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
833	The Devil's Own	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
834	Indecent Proposal	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
835	Les Miserables	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
836	Friday the 13th	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
837	Elizabeth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
838	The Count of Monte-Cristo	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
839	Flesh	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
840	Sense and Sensibility	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
841	Mermaids	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
842	Enigma	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
843	The Trap	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
844	Best Seller	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
845	Bolero	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
846	A Tale of Two Cities	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
847	The Assassination of Trotsky	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
848	Daisy Miller	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
849	At Long Last Love	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
850	Body Snatchers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
851	Cul-de-sac	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
852	Obsession	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
853	Runaway Bride	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
854	Son of Sinbad	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
855	Charade	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
856	Good Morning Miss Dove	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
857	Ghost Dog: The Way of the Samurai	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
858	Never So Few	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
859	Kismet	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
860	Final Analysis	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
861	The Jackal	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
862	Guys and Dolls	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
863	Genghis Khan	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0)
864	Ten Little Indians	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
865	Love Has Many Faces	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
866	And Then There Were None	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
867	Billion Dollar Brain	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
868	Where the Spies are	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
869	The Day of the Jackal	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
870	The Man Who Haunted Himself	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
871	A Boy and His Dog	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
872	Zardoz	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
873	Dead Bang	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
874	Cry Terror!	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
875	Edge of Seventeen	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
876	The World, the Flesh and the Devil	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
877	Hang â€™em High	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
878	House of Cards	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
879	Madigan	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
880	The Buccaneer	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
881	Firecreek	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
882	The Last Frontier	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
883	Send Me No Flowers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
884	Man on Fire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
885	10 Things I Hate About You	(0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
886	Pillow Talk	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
887	Drop Zone	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
888	Mimic	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
889	White Lightning	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
890	The Longest Yard	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
891	Semi-Tough	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
892	Hustle	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
893	5 Card Stud	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
894	Boogie Nights	(0, 0, 0, 7, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
895	Wonderland	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
896	Woman of Straw	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
897	Lifeguard	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
898	Prospero's Books	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
899	No Way Out	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0)
900	Topkapi	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
901	Deadlier Than the Male	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
902	Carry on Spying	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
903	Carry on Screaming	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
904	Don't Lose Your Head	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
905	Carry on Doctor	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
906	Carry on Cowboy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
907	Carry on Cleo	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
908	The Sugarland Express	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
909	The Day of the Locust	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
910	Hannah And Her Sisters	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
911	The In-Laws	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
912	3:10 to Yuma	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
913	Travels with my Aunt	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
914	Three of Hearts	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
915	Stay Hungry	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
916	Two Moon Junction	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
917	Dancing at Lughnasa	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
918	Apartment Zero	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
919	Billy Budd	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
920	The Hunting Party	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
921	Juarez	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
922	The Boxer	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
923	Carried Away	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
924	Bad Blood	(5, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0, 5, 0)
925	What About Bob ?	(5, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0, 5, 0)
926	Shock	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
927	The Fugitive	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
928	The Ladykillers	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
929	Finders Keepers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
930	RoboCop	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
931	RoboCop 2	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
932	Alice's Restaurant	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
933	Six-Pack	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
934	Trancers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
935	Elvira, Mistress of the Dark	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
936	Pee-wee's Big Adventure	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
937	The Blue Lagoon	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
938	Hoosiers	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
939	Land Raiders	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
940	Beyond the Valley of the Dolls	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 5, 0, 0, 5, 0)
941	Two for the Road	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
942	Tom Jones	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
943	Torn Curtain	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
944	The Sentinel	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
945	Christmas Vacation	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
946	Alive	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
947	Family Plot	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
948	Blue in the Face	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
949	Brain Dead	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
950	A Bridge Too Far	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
951	The Ice Storm	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
952	Tom Horn	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
953	The Towering Inferno	(0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
954	Le Mans	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
955	Nevada Smith	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
956	The Hunter	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
957	The Sand Pebbles	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
958	Papillon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
959	The Great Escape	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
960	Junior Bonner	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
961	The Reivers	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
962	Written on the Wind	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
963	The Woman in Red	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
964	Romeo and Juliet	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
965	The Alphabet Murders	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
966	The Mirror Crack'd	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
967	Murder by Death	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
968	Six Days Seven Nights	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
969	The Witches of Eastwick	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0)
970	Kiss of Death	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
971	Carlito's Way	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
972	Revenge of the Pink Panther	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
973	Bram Stoker's Dracula	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
974	Cat People	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0)
975	Sister Act 2: Back in the Habit	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
976	Junior	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
977	Mousehunt	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
978	Blue Thunder	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
979	The Chamber	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
980	SLC Punk!	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
981	Three Kings	(5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
982	Practical Magic	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
983	Other People`s Money	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
984	The Jerk	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
985	Guarding Tess	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
986	From Noon Till Three	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
987	Life	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
988	North to Alaska	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
989	Hondo	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
990	The Wonderful Country	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
991	Sabrina	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
992	The Peacemaker	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
993	The Unforgiven	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
994	El Dorado	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
995	Treasure Island	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
996	UFOria	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
997	The Ten Commandments	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
998	Homeward Bound: The Incredible Journey	(0, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
999	Two-Minute Warning	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1000	The Gate	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
1001	Yesterday	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1002	What's Up, Doc?	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1003	Outbreak	(0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1004	The 40 Year Old Virgin	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1005	The White Dawn	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1006	Welcome to Woop Woop	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1007	Harlow	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1008	The Angry Red Planet	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1009	Whoever Slew Auntie Roo?	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 7, 0)
1010	Big Trouble in Little China	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1011	Rising Sun	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1012	The Wilby Conspiracy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1013	The Wild Geese	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1014	American Heart	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1015	Jack	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1016	Venom	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1017	Airport '77	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1018	Nothing to lose	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1019	One Fine Day	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1020	Running Scared	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1021	Carrie	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1022	Robinson Crusoe on Mars	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1023	Julia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1024	Sahara	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1025	Sleeping with the Enemy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1026	The Cook, The Thief, His Wife & Her Lover	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1027	The Harder They Come	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1028	Cocktail	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1029	Fun with Dick and Jane	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1030	Shine	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1031	The Proposition	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1032	I Hired a Contract Killer	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1033	In the Name of the Father	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1034	Penelope	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1035	Robin Hood: Men in Tights	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1036	Mouth to Mouth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1037	Highlander	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1038	Highlander II: The Quickening	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1039	Get Shorty	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1040	Breakheart Pass	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
1041	A Life Less Ordinary	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1042	Desperado	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1043	Alien Resurrection	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1044	This Boy's Life	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1045	Cleopatra	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1046	My Name Is Joe	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1047	Desperately Seeking Susan	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1048	Ronin	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1049	Midnight in the Garden of Good and Evil	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1050	The Quiet American	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1051	Alice	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1052	8MM	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1053	A Midsummer Night's Sex Comedy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1054	Gorky Park	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1055	Howards End	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1056	The Taking of Pelham One, Two, Three	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1057	They Live	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1058	An Affair to Remember	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1059	Cast Away	(0, 10, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1060	Robin Hood: Prince Of Thieves	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1061	The Boondock Saints	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1062	Â¡Three Amigos!	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1063	When night is falling	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1064	The Gods Must Be Crazy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1065	The Hitcher	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1066	Day of the Dead	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 5, 0, 0, 0)
1067	Event Horizon	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1068	Pump up the Volume	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1069	Murder in the First	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1070	Bugsy Malone	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1071	Angels and Insects	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1072	Torch Song Trilogy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1073	Dumb & Dumber	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1074	Highway 61	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1075	National Lampoon's Animal House	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1076	Wild Wild West	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5)
1077	Borderline	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1078	Weekend at Bernie's	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1079	Devil in a Blue Dress	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1080	Superman II	(5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1081	Little Voice	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1082	Dangerous Beauty	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1083	Dick Tracy	(0, 0, 0, 5, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1084	Prom Night	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1085	Bringing Out The Dead	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1086	Deep Impact	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1087	Snake Eyes	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1088	Sam Whiskey	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1089	Cast a Giant Shadow	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1090	The Thin Red Line	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1091	Albino Alligator	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1092	It Happened at the World's Fair	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1093	Top Secret!	(5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1094	Evita	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1095	Timecop	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1096	Conspiracy Theory	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1097	Mercury Rising	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1098	Casper	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1099	Dragonheart	(0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1100	Jumanji	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1101	Under Siege	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1102	Alfie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1103	The Shadow	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1104	The Blob	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1105	Prince of Darkness	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
1106	Steel	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1107	The Karate Kid, Part II	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
1108	Metro	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1109	Wayne's World	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1110	Wayne's World 2	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1111	My Best Friend's Wedding	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1112	Pale Rider	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1113	Pet Sematary	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1114	Deep Blue Sea	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1115	Crimson Tide	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1116	Twilight	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
1117	The Out-of-Towners	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1118	Lord of Illusions	(0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0)
1119	The War of the Worlds	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0)
1120	Assault on Precinct 13	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1121	Disclosure	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1122	Milk Money	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1123	The River Wild	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1124	Harry and the Hendersons	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1125	The Sure Thing	(0, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1126	Hellraiser	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1127	The Insider	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1128	Midnight Run	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1129	For Love or Money	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1130	The Importance of Being Earnest	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1131	Big Daddy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1132	Slither	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1133	Grease 2	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1134	The Heartbreak Kid	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1135	Trapped	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1136	Serpico	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1137	10	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1138	Only You	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1139	Just Cause	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1140	Love Story	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1141	Europa	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1142	The Brady Bunch Movie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1143	The Man	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1144	Tarantula	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 5, 0)
1145	Dying Young	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1146	Spies Like US	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1147	Harlem Nights	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1148	Young Guns II	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5)
1149	The American President	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1150	Home for the Holidays	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1151	To Wong Foo, Thanks for Everything, Julie Newmar	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1152	Sudden Death	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1153	The Four Feathers	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1154	Mary Reilly	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1155	Medicine Man	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1156	Sgt. Bilko	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1157	Down Periscope	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1158	Screamers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1159	Broken Arrow	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1160	Hot Shots! Part Deux	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1161	Now and Then	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1162	Poison Ivy	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1163	Eraser	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1164	Virtuosity	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1165	The Good Son	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1166	The Faculty	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1167	The Sting	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1168	Freejack	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1169	Jingle All the Way	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1170	Witness	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1171	Beautiful Girls	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1172	The Longest Day	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1173	Hudson Hawk	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1174	Phenomenon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1175	Orlando	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1176	Bound	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1177	The Island of Dr. Moreau	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0)
1178	Smilla's Sense of Snow	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1179	Mortal Kombat	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1180	Romancing the Stone	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1181	The Nutty Professor	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1182	Clear and Present Danger	(7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
1183	Last Man Standing	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1184	The Goonies	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1185	The Mask of Zorro	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1186	Kids	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1187	Risky Business	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1188	Species	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1189	Universal Soldier	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1190	Cliffhanger	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1191	Honey, I Shrunk the Kids	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1192	Mad Max Beyond Thunderdome	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1193	Maverick	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1194	Anaconda	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1195	The Last of the Mohicans	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1196	Tremors	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1197	Donnie Brasco	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1198	Scaramouche	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1199	Death Becomes Her	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1200	Ferris Bueller's Day Off	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1201	Boys on the Side	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1202	In the Line of Fire	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1203	Conan the Barbarian	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1204	Jerry Maguire	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1205	Above the Law	(5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1206	Crocodile Dundee II	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1207	Lionheart	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1208	Set It Off	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1209	Private Parts	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1210	Double Team	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1211	Red Corner	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1212	Another Stakeout	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1213	Great Expectations	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1214	Fallen	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1215	Picture Perfect	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1216	The Man Who Knew Too Little	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1217	Murder at 1600	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1218	Money Talks	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1219	Wrongfully Accused	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1220	A Civil Action	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1221	Virus	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1222	Soldier	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1223	The Fly	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1224	The Full Monty	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1225	A Night at the Roxbury	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1226	Go!	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1227	The Edge	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1228	Kiss the Girls	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1229	Primary Colors	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1230	Stepmom	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1231	Dead Men Don't Wear Plaid	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1232	Chariots of Fire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1233	Anastasia	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1234	Apt Pupil	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1235	Babe: Pig in the City	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1236	The Big Hit	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1237	Brassed Off	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1238	Election	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1239	Bulworth	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1240	Ever After	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1241	Deep Rising	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1242	Enter the Dragon	(0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1243	Cookies Fortune	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1244	Celebrity	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1245	He Got Game	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1246	Scent of a Woman	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1247	The Bone Collector	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1248	Judge Dredd	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1249	You've Got Mail	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1250	Half Baked	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1251	Blue Steel	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1252	Twins	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1253	Look Who's Talking	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1254	The Crow	(5, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0)
1255	Glengarry Glen Ross	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1256	Runaway	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1257	Menace II Society	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1258	Candyman	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1259	Superman III	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
1260	Analyze This	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1261	Scanners	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1262	Dead Ringers	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1263	Sniper	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1264	Ricochet	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1265	Old Shatterhand	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1266	The Right Stuff	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1267	The Exorcist	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1268	King Lear	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1269	Darkman	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1270	King of New York	(0, 0, 0, 0, 5, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1271	A Walk in the Clouds	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1272	Any Given Sunday	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
1273	The Fan	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0)
1274	Hard to Kill	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1275	The Black Hole	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1276	Dazed and Confused	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1277	Flubber	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1278	Tootsie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1279	Charly	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1280	Convoy	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1281	Not Without My Daughter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1282	The Bonfire of the Vanities	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1283	Little Women	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1284	Quigley Down Under	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1285	That Thing You Do!	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1286	Last Action Hero	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1287	Hot Shots!	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1288	Babe	(0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1289	Coming to America	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1290	Clueless	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1291	Red Heat	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1292	Single White Female	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1293	Super Mario Bros.	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1294	Of Mice and Men	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1295	Conan the Destroyer	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0)
1296	Romy and Michele's High School Reunion	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1297	Coneheads	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1298	Happy Gilmore	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1299	Tango & Cash	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1300	Dante's Peak	(5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1301	Beverly Hills Ninja	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1302	The Juror	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1303	The Glimmer Man	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1304	Red Sonja	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1305	The Negotiator	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1306	Phantasm	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1307	Loaded Weapon 1	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1308	Scrooged	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1309	The Italian Job	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1310	Black Christmas	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1311	Mad Max	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1312	Operation Petticoat	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1313	Starman	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1314	Glory	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1315	Crocodile Dundee	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1316	Sweet and Lowdown	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1317	Assassins	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1318	Straight to Hell	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1319	Bound by Honor	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1320	The Wicker Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1321	Allan Quatermain and the Lost City of Gold	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1322	Holy Man	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1323	Hope Floats	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1324	Everyone Says I Love You	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1325	Shoot To Kill	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1326	Friday the 13th Part 2	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1327	Bad Boys	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1328	Demolition Man	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1329	Kundun	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1330	D.O.A.	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1331	Fletch	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1332	The Big Red One	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1333	Cry-Baby	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1334	Mad City	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1335	Proof	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1336	The Hills Have Eyes	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1337	Enemy of the State	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1338	The Fast and the Furious	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1339	Philadelphia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1340	The Rock	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1341	Waterworld	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1342	Thursday	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1343	Marvin's Room	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1344	The Parent Trap	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1345	The Mighty	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1346	Mighty Joe Young	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1347	Mystery Men	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1348	Lake Placid	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1349	The Phantom	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1350	King Solomon's Mines	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1351	School for Scoundrels	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1352	The Opposite of Sex	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1353	To Live and Die in L.A.	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1354	My Favorite Martian	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1355	The Go-Getter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1356	Patriot Games	(7, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0)
1357	Explorers	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
1358	Cobra	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1359	Urban Legend	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1360	Striptease	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1361	The Siege	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1362	Johnny Mnemonic	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1363	The Stepford Wives	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1364	The Cable Guy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1365	Shallow Grave	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1366	Dangerous Minds	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1367	The Postman	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1368	Legal Eagles	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1369	Down and Out in Beverly Hills	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1370	Major League	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1371	The Pelican Brief	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1372	John Carpenter's Vampires	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5)
1373	End of Days	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0)
1374	The Brave	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1375	Lord Of The Flies	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1376	Bad Taste	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1377	Uncommon Valor	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1378	The Last Run	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1379	Lock Up	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1380	Children of the Revolution	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1381	Mona Lisa	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1382	The Saint	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1383	Peggy Sue Got Married	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1384	Heartbreak Ridge	(5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1385	The Wraith	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1386	Mannequin	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1387	Dragnet	(7, 0, 0, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1388	Very Bad Things	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1389	When a Stranger Calls	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 7, 0)
1390	Killer's Kiss	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1391	Escape from L.A.	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1392	The Amityville Horror	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1393	House of Wax	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1394	The Shaggy Dog	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1395	9 1/2 Weeks	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
1396	A Nightmare on Elmstreet 3: Dream Warriors	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0)
1397	The Principal	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1398	Empire of the Sun	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1399	Flight of the Navigator	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1400	Colors	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1401	Alien Nation	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1402	Gorillas in the Mist: The Story of Dian Fossey	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1403	A Nightmare on Elmstreet 4: The Dream Master	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1404	Talk Radio	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1405	Cyborg	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1406	Road House	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1407	The Golden Child	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1408	Dirty Rotten Scoundrels	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1409	Casualties of War	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1410	Smoke	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1411	Sphere	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1412	Mickey Blue Eyes	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1413	U-Turn	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1414	History of the World, Part I	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1415	White Men Can't Jump	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1416	My Left Foot	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1417	Waking Ned Devine	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1418	The Lawnmower Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1419	Cadillac Man	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1420	The Witches	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1421	The Freshman	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1422	Men at Work	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1423	Marked for Death	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1424	The Quiet Earth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1425	The Caine Mutiny	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1426	The Ice Pirates	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1427	Mary Queen of Scots	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1428	Buffy the Vampire Slayer	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1429	Message in a Bottle	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1430	Muppets from Space	(0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1431	A Midsummer Night's Dream	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1432	Ravenous	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1433	Sliding Doors	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1434	The Sweet Hereafter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1435	Swingers	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1436	Snow Falling on Cedars	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1437	Rounders	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1438	A Simple Plan	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1439	Foxfire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1440	The Way We Were	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1441	The Honeymoon Killers	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1442	What Ever Happened to Baby Jane?	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1443	The Flight of the Phoenix	(0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1444	Porky's	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1445	The Rocketeer	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1446	Hamlet	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1447	Yentl	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1448	Return to Paradise	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1449	Summer of Sam	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1450	How to marry a Millionaire	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1451	Hush Hush, Sweet Charlotte	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1452	The Jewel of the Nile	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1453	Stigmata	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1454	Patch Adams	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1455	She's All That	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1456	Being There	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1457	Clash of the Titans	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1458	Forever Young	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1459	Cocoon	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1460	Congo	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1461	Freaky Friday	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1462	Night of the Living Dead	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1463	Spawn	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0)
1464	Bugsy	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1465	Moby Dick	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1466	Teaching Mrs. Tingle	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1467	K-9	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1468	The Dark Half	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1469	Wishmaster	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1470	True Crime	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1471	Volcano	(5, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1472	Resurrection	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1473	Catch-22	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1474	Tea with Mussolini	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1475	Quadrophenia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1476	My Cousin Vinny	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1477	Drop Dead Fred	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1478	The Limey	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1479	For Love of the Game	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1480	Wolf	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1481	Tequila Sunrise	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1482	Angela's Ashes	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1483	Double Jeopardy	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1484	Mansfield Park	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1485	The Player	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1486	Encino Man	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1487	Housesitter	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1488	Strictly Ballroom	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1489	Hoffa	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1490	The Distinguished Gentleman	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1491	Romper Stomper	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1492	Nowhere to run	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1493	The Mighty Ducks	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1494	Swing Kids	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0)
1495	Red Rock West	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1496	Hackers	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1497	Takedown	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1498	Mad Dog and Glory	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1499	Chaplin	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1500	The Age of Innocence	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1501	The Muppet Christmas Carol	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1502	Beethoven's 2nd	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1503	Hocus Pocus	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1504	Manhattan Murder Mystery	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1505	Fearless	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1506	Shadowlands	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1507	Rapa Nui	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1508	When a Man Loves a Woman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1509	Corrina, Corrina	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1510	The Money Pit	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1511	The Road to Wellville	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1512	The Basketball Diaries	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1513	Cujo	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1514	Drop Dead Gorgeous	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1515	Dead Calm	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1516	Bitter Moon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
1517	Point of No Return	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1518	Happy-Go-Lucky	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1519	Miracle on 34th Street	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1520	Plan 9 from Outer Space	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1521	The Andromeda Strain	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1522	Marathon Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1523	Forget Paris	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1524	The Scarlet Letter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1525	White Squall	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1526	The Doors	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1527	Outland	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1528	Fear	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1529	The Hunchback of Notre Dame	(0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1530	The Arrival	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1531	Family Business	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1532	Cat's Eye	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1533	Remo Williams: The Adventure Begins	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1534	East is East	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1535	Under Suspicion	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1536	Three to Tango	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1537	Where The Heart Is	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1538	Psycho II	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1539	Childâ€™s Play	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1540	The Ghost and the Darkness	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1541	The Girl Next Door	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1542	George of the Jungle	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1543	The Philadelphia Experiment	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1544	Bob Roberts	(0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1545	Taps	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1546	All of Me	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1547	The Hunted	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1548	In the Heat of the Night	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1549	Friday	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1550	Threesome	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1551	Futureworld	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1552	The Unbearable Lightness of Being	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
1553	Magnum Force	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1554	The Enforcer	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1555	Sudden Impact	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1556	The Dead Pool	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1557	Hamburger Hill	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1558	The Seven Year Itch	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1559	Hair	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0)
1560	Gettysburg	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1561	Needful Things	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1562	It Could Happen to You	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1563	The Waterboy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1564	Suicide Kings	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1565	Deliverance	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1566	Rollercoaster	(5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1567	Airport	(0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1568	Wall Street	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1569	Frantic	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1570	Happiness	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1571	Courage under Fire	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1572	Space Truckers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1573	The Chase	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1574	Hero	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1575	Henry V	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1576	French Connection II	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1577	Firefox	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1578	Wolfen	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1579	Darkness Falls	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1580	Quick Change	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1581	The Client	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1582	The Alamo	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5)
1583	Escape From Alcatraz	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1584	Toy Soldiers	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1585	Private Benjamin	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1586	Damien: Omen II	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1587	The Final Conflict	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1588	Network	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1589	Little Shop of Horrors	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0, 0, 0)
1590	The Frighteners	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0)
1591	Overboard	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1592	Cabaret	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1593	The Thing from Another World	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1594	Robin and Marian	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1595	The Invisible Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1596	The Party	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1597	Logan's Run	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
1598	King Ralph	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1599	In & Out	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1600	Candyman: Farewell to the Flesh	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
1601	Matilda	(0, 5, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1602	The Draughtman's Contract	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1603	Heartbreakers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1604	Cross of Iron	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1605	After Hours	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1606	Out of the Blue	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1607	The Purple Rose of Cairo	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1608	Nixon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1609	Stakeout	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1610	Steel Magnolias	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1611	Eye of the Needle	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1612	Joy Ride	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1613	The Accused	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1614	Herbie Rides Again	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1615	Switchback	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1616	The Ref	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1617	Muppet Treasure Island	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1618	The Fabulous Baker Boys	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1619	I Love Trouble	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1620	Gloria	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1621	Stripes	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1622	Tin Men	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1623	The Little Rascals	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1624	The Man with One Red Shoe	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1625	The Adventures of Robin Hood	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1626	Inferno	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1627	The Guns of Navarone	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1628	Heaven's Gate	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5)
1629	Barfly	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1630	Beautiful Thing	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1631	Jumpin' Jack Flash	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1632	New Jack City	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1633	Silent Movie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1634	A Night to Remember	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1635	Creature from the Black Lagoon	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1636	Mulholland Falls	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1637	Fatal Attraction	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1638	Commando	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1639	The Birdcage	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1640	Blue Streak	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1641	Greystoke: The Legend of Tarzan, Lord of the Apes	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1642	The Wedding Singer	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1643	Awakenings	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1644	Smokey and the Bandit	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1645	Cheaper by the Dozen	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1646	Saturday Night Fever	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1647	Damage	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
1648	Key Largo	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1649	Billy Madison	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1650	Year of the Dragon	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1651	Picnic at Hanging Rock	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1652	The Postman always rings twice	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0)
1653	The Big Easy	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1654	Zelig	(0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1655	This Is Spinal Tap	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1656	Dressed to Kill	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1657	The Great Gatsby	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1658	Iron Eagle	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1659	Tough Guys	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1660	Little Big Man	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1661	The Beverly Hillbillies	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1662	Arizona Dream	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1663	Where Eagles Dare	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1664	Terms of Endearment	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1665	The Last Temptation of Christ	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1666	Internal Affairs	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1667	City Hall	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1668	Brewster's Millions	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1669	Boomerang	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1670	Singles	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1671	Them!	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1672	Blazing Saddles	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1673	Striking Distance	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1674	Fly Away Home	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1675	The Seventh Sign	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1676	Mutiny on the Bounty	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1677	The Hand that Rocks the Cradle	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1678	Presumed Innocent	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1679	Head above Water	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1680	The Associate	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1681	My Fair Lady	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1682	Tess	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1683	Earthquake	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1684	Human Traffic	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1685	Nuns on the Run	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1686	Poltergeist II: The Other Side	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1687	The Electric Horseman	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1688	She-Devil	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1689	Honey, I Blew Up the Kid	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1690	Tora! Tora! Tora!	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1691	Peeping Tom	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1692	The Muppet Movie	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1693	Mask	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1694	Child's Play 2	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1695	Mystic Pizza	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1696	Rembrandt	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1697	Patton	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1698	Wait Until Dark	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1699	Robinson Crusoe	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1700	Baby's Day Out	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1701	Baby Boom	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1702	The Trouble with Harry	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1703	Coma	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1704	Freeway	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1705	The Omega Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1706	Local Hero	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1707	The Secret Garden	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1708	The Meteor Man	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1709	A Room with a View	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1710	Far and Away	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1711	Cocoon: The Return	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1712	The Cannonball Run	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1713	A League of Their Own	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
1714	Paper Moon	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1715	Birdy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1716	The Howling	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1717	Something Wild	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1718	Bananas	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1719	Mystery Train	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1720	Extreme Measures	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1721	The World According to Garp	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1722	The Hotel New Hampshire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1723	Hardware	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
1724	Macbeth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1725	The Madness of King George	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1726	Tommy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1727	Midnight Express	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1728	The Old Man and the Sea	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1729	Popeye	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1730	The Dead Zone	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 5, 0)
1731	Stardust Memories	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1732	Into the Night	(5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1733	Warlock	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
1734	Always	(0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1735	Bowfinger	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1736	Never Been Kissed	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1737	The Odd Couple	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1738	Walking Tall	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1739	She's the One	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1740	Regarding Henry	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1741	Wilde	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1742	Blood Simple	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1743	The Eagle has landed	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0)
1744	EDtv	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1745	House on Haunted Hill	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1746	Tommy Boy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1747	Bullets Over Broadway	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1748	The Hard Way	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1749	Hatari!	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1750	The Crying Game	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1751	Lord Jim	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1752	The Belles of St. Trinian's	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1753	Superman IV â€“ The Quest for Peace	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1754	The Long Kiss Goodnight	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1755	The Defiant Ones	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1756	The Mission	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1757	European Vacation	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1758	Vegas Vacation	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1759	Midway	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1760	High Society	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1761	From Here to Eternity	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1762	Dead End	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1763	Dead Presidents	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1764	Welcome to the Dollhouse	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1765	Mighty Aphrodite	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1766	Quiz Show	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1767	Manhunter	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1768	Up In Smoke	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1769	Suspicion	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1770	Battle of Britain	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1771	Great Balls of Fire!	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1772	Nine Months	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1773	The Warriors	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1774	Repulsion	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1775	Rollerball	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1776	Take the Money and Run	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1777	Firestarter	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1778	Dead Again	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1779	The Serpent and the Rainbow	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1780	Body Double	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1781	Silverado	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1782	1941	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1783	Grumpy Old Men	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1784	Little Man Tate	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1785	Pretty in Pink	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1786	Thief	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1787	Excalibur	(0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1788	The Sandlot	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1789	The Misfits	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1790	The Year of Living Dangerously	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1791	Altered States	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0)
1792	Kingpin	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1793	Rushmore	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1794	*batteries not included	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
1795	Invasion of the Body Snatchers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1796	Journey to the Center of the Earth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1797	St. Elmo's Fire	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1798	Silver Streak	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1799	Sleeper	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1800	Crimes and Misdemeanors	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1801	Class of 1984	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1802	Dave	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1803	The Crimson Pirate	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1804	Inspector Clouseau	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1805	Support Your Local Sheriff	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1806	The Great Race	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1807	It's a Mad Mad Mad Mad World	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1808	The First Great Train Robbery	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1809	Roxanne	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1810	The Producers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1811	Exorcist II: The Heretic	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1812	The Exorcist III	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1813	Kelly's Heroes	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1814	Slap Shot	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1815	The Man with Two Brains	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1816	Serial Mom	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1817	Nobody's Fool	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1818	Another 48 Hrs.	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1819	Toys	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1820	Stir of Echoes	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1821	The List of Adrian Messenger	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1822	Yellowbeard	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1823	Play It Again, Sam	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1824	Rio Grande	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1825	The Haunting	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1826	Quo Vadis	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1827	Blast from the Past	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1828	The Medusa Touch	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1829	Blow Out	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1830	Gallipoli	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1831	Five Fingers	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1832	Following	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1833	The Commitments	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1834	Cyrano de Bergerac	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1835	Halloween H20: 20 Years Later	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
1836	Love and Death	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1837	Bloodsport	(0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1838	Cat Ballou	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1839	The Man Who Shot Liberty Valance	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1840	The Replacement Killers	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1841	Kiss of the Spider Woman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1842	War and Peace	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1843	Tightrope	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1844	Chitty Chitty Bang Bang	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0)
1845	Village of the Damned	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1846	I.Q.	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1847	The Deer Hunter	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1848	Rob Roy	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1849	My Beautiful Laundrette	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1850	Harvey	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1851	Peter's Friends	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1852	The Hound of the Baskervilles	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1853	Fright Night	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1854	Naked in New York	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1855	Beethoven	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1856	U.S. Marshals	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1857	Leprechaun	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1858	Weird Science	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1859	On Golden Pond	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1860	Doc Hollywood	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1861	Teen Wolf	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1862	Amistad	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1863	Jabberwocky	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1864	The Court Jester	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0)
1865	The Return of the Pink Panther	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1866	The Van	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1867	Father of the Bride	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1868	The Presidio	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1869	Bad Girls	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1870	Pecker	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1871	Air America	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1872	How to make an American Quilt	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1873	Father of the Bride Part II	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1874	Enemy Mine	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1875	The Color of Money	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1876	Near Dark	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5)
1877	The Last Starfighter	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1878	Runaway Train	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1879	Curly Sue	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1880	Throw Momma from the Train	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1881	How the West Was Won	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1882	Kind Hearts and Coronets	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1883	The Muppets Take Manhattan	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1884	High Plains Drifter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
1885	Young Sherlock Holmes	(0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1886	The Company of Wolves	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
1887	Two Mules for Sister Sara	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5)
1888	Dolores Claiborne	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1889	Bride of Chucky	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1890	Nothing but Trouble	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1891	The Hudsucker Proxy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1892	Capricorn One	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
1893	The Gods Must Be Crazy II	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1894	Clockwise	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1895	A Day at the Races	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1896	Bring Me the Head of Alfredo Garcia	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1897	Jeremiah Johnson	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1898	Joan of Arc	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1899	Merry Christmas Mr. Lawrence	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1900	Vanishing Point	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1901	Lifeforce	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1902	UHF	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1903	Three Days of the Condor	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1904	Young Guns	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1905	Tombstone	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1906	Much Ado about Nothing	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1907	The 'Burbs	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1908	The Rainmaker	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1909	Legend	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1910	Caddyshack	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
1911	The Prophecy	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0)
1912	Look Who's Talking Now	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1913	Fortress	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1914	Alice in Wonderland	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1915	Soylent Green	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1916	Kramer vs. Kramer	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1917	The Quick and the Dead	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1918	Dracula: Dead and Loving it	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1919	Instinct	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1920	Police Academy 3: Back in Training	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1921	My Stepmother is an Alien	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1922	Made in America	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1923	Chain Reaction	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1924	Dennis the Menace	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1925	Alone in the Dark	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1926	Bad Lieutenant	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1927	Fierce Creatures	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1928	Sea of Love	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1929	Ruthless People	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1930	Three Men and a Baby	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1931	Green Card	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1932	Vampire in Brooklyn	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
1933	What Dreams May Come	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1934	Wyatt Earp	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1935	The Governess	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1936	Heaven Can Wait	(0, 0, 0, 5, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1937	Defending Your Life	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1938	Heart and Souls	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1939	The Story of Us	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1940	White Fang	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1941	The Thief of Bagdad	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
1942	Jagged Edge	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1943	The Osterman Weekend	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1944	Home Fries	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1945	The Pink Panther Strikes Again	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1946	The Paper	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1947	Bachelor Party	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1948	The Four Musketeers	(5, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1949	Thunderheart	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
1950	The incredible shrinking woman	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
1951	In the Army Now	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1952	The Hidden	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
1953	Skin Deep	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1954	Breakfast of Champions	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1955	The Gingerbread Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1956	Gridlock'd	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1957	Sling Blade	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1958	Fathers' Day	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1959	The Big Country	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1960	Silkwood	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1961	Under Fire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1962	Little Nikita	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1963	Cry Freedom	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1964	Honeymoon in Vegas	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1965	Sirens	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1966	The Last Supper	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1967	Titus	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1968	Southern Comfort	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0)
1969	Avanti!	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1970	High Anxiety	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1971	The French Lieutenant's Woman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1972	Senseless	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1973	Jesus Christ Superstar	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0)
1974	The Big Chill	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1975	Without a Clue	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1976	The Shootist	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1977	Pushing Tin	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1978	The Fury	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
1979	Victor/Victoria	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1980	Death of a Salesman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1981	One Night Stand	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1982	Midnight Lace	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1983	Random Hearts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1984	Suspect	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1985	Broadcast News	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1986	Live Wire	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1987	The Star Chamber	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1988	The Big Bounce	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1989	Backbeat	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1990	New York, New York	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
1991	Return of the Seven	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
1992	Billy Bathgate	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1993	The Mouse That Roared	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1994	Memphis Belle	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
1995	I Went Down	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1996	Feeling Minnesota	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1997	Undercover Blues	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
1998	Powder	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
1999	Still Smokin'	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2000	Revolution	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2001	Smokey and the Bandit II	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2002	Croupier	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2003	Orca	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2004	That Touch of Mink	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2005	Big Business	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2006	She's Having a Baby	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2007	Firewalker	(5, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2008	Flashback	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2009	Inventing the Abbotts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2010	Broadway Danny Rose	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2011	Missing in Action 2: The Beginning	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2012	Vera Cruz	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2013	Leap of Faith	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2014	Navy SEALS	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2015	Last Exit to Brooklyn	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2016	Flesh & Blood	(5, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2017	Greedy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2018	Homeboy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2019	End of the line	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2020	All Over Me	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2021	Wild Side	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2022	Kidnapped	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2023	The Last Days of Pompeii	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2024	10 to Midnight	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2025	Mo' Better Blues	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2026	The Women	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2027	Taxman	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2028	When the Bough breaks	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2029	Mad Dog Time	(0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2030	Beyond the Law	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2031	Dreamscape	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
2032	Rogue Trader	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0)
2033	Last Night	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2034	The Reckoning	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2035	The Big Brawl	(5, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2036	Gone in 60 Seconds	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2037	After The Thin Man	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2038	The Long Good Friday	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2039	Pickup on South Street	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2040	Ironweed	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2041	Coffy	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2042	Hell's Angels	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2043	King of Kings	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2044	How to Get Ahead in Advertising	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2045	The Painted Veil	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2046	Death Race 2000	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2047	Just one of the guys	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2048	The Misadventures of Margaret	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2049	Powwow Highway	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2050	Young at Heart	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2051	King of the Hill	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2052	Permanent Vacation	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2053	Slacker	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2054	The Secret War of Harry Frigg	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2055	Rascal	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2056	The Carey Treatment	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2057	New Moon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
2058	The Stranger	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2059	Revenge	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2060	Dad	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2061	Electric Dreams	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2062	Mortal Thoughts	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2063	Where the Buffalo roam	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2064	New Jersey Drive	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2065	The Quatermass Xperiment	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
2066	Quatermass 2	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2067	The Food of the Gods	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2068	Teachers	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2069	Darling	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2070	Living it up	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2071	The Bridge at Remagen	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2072	The Night Digger	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2073	Bride of Re-Animator	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2074	Woman of the Year	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2075	Crossroads	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2076	Reds	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2077	Dillinger	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2078	Candleshoe	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2079	Life during Wartime	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2080	Grace of My Heart	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2081	Burnt Offerings	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2082	The Entity	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2083	Roadie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2084	Zandy's Bride	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2085	Urban Cowboy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2086	The Mole People	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2087	Terror by Night	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2088	The Last Detail	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2089	Fort Apache the Bronx	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2090	Communion	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2091	Look Back in Anger	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2092	Theatre of Blood	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2093	The Invisible Man Returns	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2094	The Abominable Dr. Phibes	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2095	The Invisible Woman	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
2096	Dr. Phibes Rises Again	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2097	The Invisible Man's Revenge	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2098	Big Top Pee-wee	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2099	Jack the Ripper	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2100	The Bullfighters	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2101	The Dancing Masters	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2102	Saps At Sea	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2103	Our Relations	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2104	Jeffrey	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2105	The Bohemian Girl	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2106	The Devil's Brother	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2107	Pack Up Your Troubles	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2108	Pardon Us	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2109	Miracle Mile	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2110	From Beyond	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
2111	The Wolfman	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2112	Strike!	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2113	Simply Irresistible	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2114	Storm	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2115	Vanya on 42nd Street	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2116	Sabotage	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2117	Boxcar Bertha	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2118	Purple Rain	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2119	The Lion in Winter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2120	Valmont	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2121	Kiss Me Kate	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2122	Fire Down Below	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2123	Nighthawks	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2124	The Delta Force	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2125	The Premature Burial	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2126	Gas, Food Lodging	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2127	The Search	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2128	Project X	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2129	Six-String Samurai	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2130	South of the border	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2131	The Wild One	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2132	The Neighbor	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2133	The private Lives of Elizabeth and Essex	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2134	Basket Case	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2135	A Royal Scandal	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2136	The Web	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2137	House of Usher	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2138	Killer Klowns from Outer Space	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2139	Not of This Earth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2140	Rage	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2141	Return of the Fly	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2142	Edge of Darkness	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2143	The Raven	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
2144	The last Man on Earth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2145	Carry On Camping	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2146	Hard Core Logo	(0, 0, 0, 5, 0, 0, 5, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2147	Modesty Blaise	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2148	Grand Canyon	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2149	Spanking the Monkey	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2150	Love & Human Remains	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2151	August	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2152	To have and have not	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2153	Black Beauty	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2154	A Face in the Crowd	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2155	Scarlet Street	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2156	Defiance	(5, 0, 0, 0, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2157	Meet John Doe	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2158	Panic in the Streets	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2159	Night and the City	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0)
2160	Kiss Me Deadly	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2161	The Asphalt Jungle	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2162	The Woman In White	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2163	Unlawful Entry	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2164	Mr. Baseball	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2165	The Sea Wolves	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2166	The Lusty Men	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2167	The Crazies	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2168	The Shop Around the Corner	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2169	The Killers	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2170	Detour	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2171	Force of Evil	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2172	The Whistleblower	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2173	Personal Services	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2174	The Last of Sheila	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2175	When in Rome	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2176	The Stepfather	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2177	Band of the Hand	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2178	The Groove Tube	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2179	In the Navy	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2180	Kongo	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2181	That Old Feeling	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2182	The Unknown	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2183	True Grit	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2184	Dust Be My Destiny	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2185	Butterfly Kiss	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2186	Escape To Witch Mountain	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2187	The Wild Angels	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2188	Hell's Angels '69	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2189	Machine-Gun Kelly	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2190	Last Train from Gun Hill	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5)
2191	Hells Angels on Wheels	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2192	Maniac Cop	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2193	Surviving The Game	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2194	Strait-Jacket	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2195	The Substance of Fire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2196	Priest	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 5)
2197	Cockfighter	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2198	The Shooting	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2199	Ride in the Whirlwind	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2200	Highway to Hell	(0, 5, 0, 5, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
2201	Destiny Turns on the Radio	(0, 0, 0, 5, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2202	Every Day's a Holiday	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2203	A Thousand Acres	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2204	Trespass	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2205	Jane Eyre	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2206	Above Suspicion	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2207	Stone	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2208	Tickle Me	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2209	Nine Men	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2210	Kiss Tomorrow Goodbye	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2211	The Shaggy D.A.	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2212	The Proud Valley	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2213	The Terror of Tiny Town	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5)
2214	Kansas City Confidential	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2215	A Little Princess	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2216	Brighton Rock	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2217	White Christmas	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2218	Heidi	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2219	It Takes Two	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2220	Dirty Work	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2221	The Preacher's Wife	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2222	The Black Shield Of Falworth	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2223	Brute Force	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2224	Strange Bedfellows	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2225	Comes a Horseman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2226	The Day of the Triffids	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2227	Tiger Bay	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2228	Twisted Nerve	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2229	The Lonely Guy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2230	Excess Baggage	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2231	Held Up	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2232	One From the Heart	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2233	Gun Crazy	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2234	Hell Is For Heroes	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2235	The Swarm	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2236	Road, Movie	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2237	Sole Survivor	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2238	Nothing But the Truth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2239	The Love Bug	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2240	Beyond a Reasonable Doubt	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2241	Polyester	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2242	McBain	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2243	Rancho Notorious	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2244	Something Wicked This Way Comes	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2245	Cannibal Women in the Avocado Jungle of Death	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2246	Beat the Devil	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2247	The Green Glove	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2248	The City of the Dead	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2249	The Ghoul	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2250	The Ghost Train	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2251	The Face at the Window	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2252	The Devil Makes Three	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2253	The Irishman	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2254	The Man in the Gray Flannel Suit	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2255	A Kind of Loving	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2256	Buffalo Bill and the Indians	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2257	Beat Street	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2258	The Final Programme	(5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
2259	Long Day's Journey Into Night	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2260	The Keep	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2261	Disorderlies	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2262	The Last American Hero	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2263	Twentieth Century	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2264	Hawk the Slayer	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2265	A Kiss Before Dying	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2266	The Land That Time Forgot	(5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
2267	The Green Berets	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2268	Son In Law	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2269	In Too Deep	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2270	Nothing Personal	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2271	The Day the Earth Caught Fire	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2272	She	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2273	Tension	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2274	The Big Combo	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2275	Gunga Din	(5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2276	Bad Timing	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2277	The Bridge of San Luis Rey	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2278	At First Sight	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2279	Bhaji on the Beach	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2280	The 4th Floor	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2281	The Mechanic	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2282	It's a Wonderful World	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2283	My Bloody Valentine	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2284	The Golden Voyage of Sinbad	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2285	Backfire!	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2286	Something to Talk About	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2287	Better Off Dead	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2288	Empire of the Ants	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2289	20 Million Miles to Earth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2290	Tower of Evil	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2291	The Beast from 20,000 Fathoms	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2292	The Valley of Gwangi	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2293	Nomads	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2294	The Monster That Challenged the World	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2295	Hardcore	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2296	Made in U.S.A.	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2297	Next Stop, Greenwich Village	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2298	Don't Tell Mom the Babysitter's Dead	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2299	Alias Jesse James	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2300	Dimples	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2301	Outrage	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2302	Black Sunday	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2303	52 Pick-Up	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2304	The Collector	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2305	A Woman Under the Influence	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2306	Donovan`s Brain	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2307	Werewolf of London	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2308	Fiend without a face	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2309	Motel Hell	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2310	A Midnight Clear	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2311	Repo Man	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2312	The Gauntlet	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2313	Every Which Way But Loose	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2314	Bronco Billy	(5, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2315	Any Which Way You Can	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2316	City Heat	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2317	Bird	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2318	Fatso	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2319	Pink Cadillac	(5, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2320	White Hunter Black Heart	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2321	The Wings of the Dove	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2322	Made in Heaven	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2323	The Killer Elite	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2324	Triumph of the Spirit	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0)
2325	Father Brown	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2326	Footsteps in the Fog	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2327	The Wrong Box	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2328	First Men in the Moon	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2329	Earth vs. the flying saucers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0)
2330	Underworld U.S.A.	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2331	Mr. Blandings Builds His Dream House	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2332	The Bachelor and the Bobby-Soxer	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2333	One Crazy Summer	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2334	Mother Night	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2335	Vision Quest	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2336	Freebie and the Bean	(5, 0, 0, 5, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2337	Demon Seed	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2338	The Little Girl Who Lives Down The Lane	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2339	Rock 'n' Roll High School	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2340	Beaches	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2341	The Loneliness of the Long Distance Runner	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2342	Manâ€™s Favorite Sport?	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2343	Lover Come Back	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2344	Morning Glory	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2345	Perfect Strangers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2346	Jefferson in Paris	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2347	Samson and Delilah	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0)
2348	Fandango	(0, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2349	The Incredible Mr Limpet	(0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2350	Shakedown	(5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2351	Fast Times At Ridgemont High	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2352	Never Let Me Go	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2353	Night of the Demons 2	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2354	Mrs. Winterbourne	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2355	Rampage	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2356	Tower of London	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0)
2357	The Power of One	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2358	Cold Heaven	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2359	The Steel Helmet	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2360	Tough Enough	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2361	The Baron of Arizona	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2362	The Castle	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2363	The Secret Life of Walter Mitty	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2364	Barbarian Queen II: The Empress Strikes Back	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0)
2365	Riptide	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2366	The Story of Ruth	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2367	Copacabana	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2368	The Sword and the Sorcerer	(5, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2369	Face	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2370	The Corpse Grinders	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2371	Two Thousand Maniacs!	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2372	Piranha Part Two: The Spawning	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2373	Speaking Parts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2374	Next of Kin	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2375	The Falcon and the Snowman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2376	Full Moon in Blue Water	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2377	One Touch of Venus	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2378	Late for Dinner	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2379	Branded	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2380	The Far Horizons	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2381	Squanto: A Warrior's Tale	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2382	No Way to Treat a Lady	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2383	Second Chance	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2384	Ring of Fire	(0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2385	The Protector	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2386	Dead of Winter	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2387	Deranged	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2388	If Looks Could Kill	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2389	Tarzan the Ape Man	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2390	Memories of Me	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2391	Captains of the Clouds	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2392	Gang Related	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2393	Rush	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2394	The Dunwich Horror	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2395	Love is a Ball	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2396	The Mack	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2397	Pascali's Island	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2398	Ground Zero	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2399	The Haunted Palace	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2400	Biggles-Adventures in Time	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
2401	Rio Lobo	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2402	Priest of Love	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2403	Chisum	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2404	Trust	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2405	Missing in Action	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2406	Zone Troopers	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2407	Green Hell	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2408	The House of the Seven Gables	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2409	Brigham Young	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2410	Knightriders	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2411	The Enemy Below	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2412	The Battle of the River Plate	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2413	The Big Bus	(0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2414	Billy Liar	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2415	Homegrown	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2416	Putney Swope	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2417	The Tempest	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2418	Phoenix	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2419	Witness To Murder	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2420	A Dangerous Woman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2421	That Cold Day in the Park	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2422	Dead Heat on a Merry-Go-Round	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2423	The Siege of Firebase Gloria	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2424	Krippendorf's Tribe	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2425	Heat and Dust	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2426	Drowning by Numbers	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2427	Point Blank	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2428	Cruising	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2429	Flipper	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2430	Sunday Bloody Sunday	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2431	The Woman in the Window	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2432	Tom Sawyer	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2433	Buddy	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2434	Tomorrow	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
2435	Paradise	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2436	A Far Off Place	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2437	I confess	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2438	Nuts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2439	Beloved	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2440	The Morning After	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2441	Thick as Thieves	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2442	The Deep End of the Ocean	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2443	The Imposters	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2444	Black and White	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2445	Three Fugitives	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2446	The Accidental Tourist	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2447	Flying Tigers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2448	That Darn Cat	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2449	Unstrung Heroes	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2450	A Low Down Dirty Shame	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2451	I Accuse	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2452	Bittersweet	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2453	Higher Learning	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2454	The Last Days of Disco	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2455	Bend of the River	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2456	A Little Bit of Soul	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2457	Dr. Giggles	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2458	The Adventures of Huck Finn	(0, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2459	Games	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2460	Mystery, Alaska	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2461	Return from Witch Mountain	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2462	Ben	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2463	Party Girl	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2464	How to Murder Your Wife	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2465	Clay Pigeons	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2466	Intersection	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2467	Losing Isaiah	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2468	Homecoming	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2469	Selena	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2470	Bliss	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
2471	Air Bud	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2472	My Dinner with Andre	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2473	A Raisin in the Sun	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2474	Body Heat	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2475	Clue	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2476	The Adventures of the Wilderness Family	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2477	The Education of Little Tree	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2478	The Bad News Bears	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2479	Barefoot in the Park	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2480	Cuba	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2481	Funny Face	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2482	Do not Disturb	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2483	Deception	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2484	Drive	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2485	Eye of the Storm	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2486	Women in Love	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2487	Sleeping Dogs	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2488	This Happy Breed	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2489	Sun Valley Serenade	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2490	The Horse Soldiers	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2491	The Milagro Beanfield War	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2492	The Honey Pot	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2493	Five Corners	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2494	The Uninvited	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2495	Goin' South	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2496	Deceived	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2497	Heart	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2498	The Savage Innocents	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2499	Ordinary People	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2500	Down to Earth	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2501	Eight on the Lam	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2502	On Dangerous Ground	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2503	House II: The Second Story	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2504	Impulse	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2505	American Me	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2506	Dick	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2507	Blue	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2508	Who Was That Lady?	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2509	The Eiger Sanction	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2510	The Paleface	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2511	The Little Prince	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2512	Posse	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2513	The Onion Field	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2514	All I Want for Christmas	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2515	MacArthur	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2516	A Private Function	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2517	October Sky	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2518	The Naked Jungle	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2519	Winterhawk	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2520	Beachhead	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2521	Miami Rhapsody	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2522	Kiss Me, Stupid	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2523	Lady Jane	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2524	Cry of the Banshee	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2525	Night Crossing	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2526	Rooster Cogburn	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2527	Champions	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2528	Untamed Heart	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2529	Three Violent People	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2530	Saboteur	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2531	Heartburn	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2532	Sisters	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2533	The Offence	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2534	Prefontaine	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2535	Taras Bulba	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2536	Track 29	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2537	The Ladies Man	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2538	The Comfort of Strangers	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2539	The Last House on the Left	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2540	The Wiz	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0)
2541	V.I. Warshawski	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2542	The Sons of Katie Elder	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2543	Waterloo	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2544	The Molly Maguires	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2545	Washington Square	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2546	Water	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2547	Impromptu	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2548	The Magnificent Seven Ride!	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2549	For Whom the Bell Tolls	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2550	Waterhole #3	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2551	Never Cry Wolf	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2552	Paint Your Wagon	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5)
2553	Betrayed	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2554	The Parallax View	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2555	In Country	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2556	Who's That Girl	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2557	The Dark Tower	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0)
2558	Kissing a Fool	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2559	Gunfight at the O.K. Corral	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2560	Shame	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2561	The Love Letter	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2562	Soapdish	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2563	Miranda	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2564	Nightfall	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2565	The Wrong Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2566	Bobby Deerfield	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2567	Oh! What a Lovely War	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2568	The Moon-Spinners	(0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2569	The Cat and the Canary	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2570	Victim	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2571	Saturday Night and Sunday Morning	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2572	Foul Play	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2573	This Sporting Life	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2574	Madame DuBarry	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2575	And Soon the Darkness	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2576	Contraband	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2577	That'll Be the Day	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2578	In the Good Old Summertime	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2579	Bluebeard	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2580	Next Stop Wonderland	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2581	The Secret Invasion	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2582	My Fellow Americans	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2583	House of Numbers	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2584	Kings Go Forth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2585	Firelight	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2586	Head Over Heels	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2587	Green for Danger	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2588	The Talk of the Town	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2589	I Am a Fugitive from a Chain Gang	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2590	Rosencrantz and Guildenstern are Dead	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2591	Murphy's War	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2592	North Dallas Forty	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2593	Boy, Did I Get a Wrong Number!	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2594	Song Without End	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2595	The Wicked Lady	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2596	Mata Hari	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
2597	Eddie and the Cruisers	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0)
2598	Accident	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2599	The Human Factor	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2600	The Paradine Case	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2601	Who Is Killing the Great Chefs of Europe?	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2602	Margaret's Museum	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2603	Cops and Robbers	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2604	My American Cousin	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2605	Desert Sands	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2606	The Unbelievable Truth	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2607	The Split	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2608	Robot Monster	(0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2609	Hannibal Brooks	(0, 5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2610	When Strangers Marry	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2611	Days of Heaven	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2612	Tea and Sympathy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2613	Walking and Talking	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2614	High Wall	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2615	Gunsight Ridge	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2616	Transylvania 6-5000	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2617	The Cyclops	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2618	The Pied Piper	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0)
2619	Ski Party	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2620	Dead of Night	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2621	Two Bits	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2622	The Abominable Snowman	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2623	The Scapegoat	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2624	The Cobweb	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2625	The Miracle of the Bells	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2626	Petulia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2627	Sugar Hill	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2628	Circle of Danger	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2629	River Street	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2630	Kid Glove Killer	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2631	The Last Gangster	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2632	Possessed	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2633	Mutiny on the Buses	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2634	On the Buses	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2635	The People That Time Forgot	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2636	The Man Who Loved Cat Dancing	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2637	Ziegfeld Girl	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2638	The Senator Was Indiscreet	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2639	I Know Where I'm Going!	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2640	Ernest Scared Stupid	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2641	Ernest Goes to Jail	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2642	The Mountain	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2643	Sign of the Pagan	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2644	Hard Country	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2645	The Sign of the Cross	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2646	Day of the Outlaw	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2647	Busting	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2648	A Show of Force	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2649	Conspirator	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2650	The Tall Target	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2651	Whose Life Is It Anyway?	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2652	Monkey Shines	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
2653	Straight on Till Morning	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2654	Two Weeks in Another Town	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2655	The Westerner	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2656	Dodsworth	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2657	The Reptile	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2658	The Time of Their Lives	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2659	The Plague of the Zombies	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2660	She Done Him Wrong	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2661	Stranger On The Third Floor	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2662	This Gun for Hire	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2663	Outside Providence	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2664	Crimewave	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2665	Of Unknown Origin	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2666	Scott of the Antarctic	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2667	My Science Project	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2668	Arabian Nights	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2669	Ali Baba and the Forty Thieves	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2670	Ifans.	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2671	Most Wanted	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2672	Wake of the Red Witch	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2673	The World of Suzie Wong	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2674	It Happened to Jane	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2675	Stiff Upper Lips	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2676	Riot	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2677	At Gunpoint	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2678	The Confession	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2679	The Mercenaries	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2680	Fitzwilly	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2681	Lisa	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2682	The Hunters	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2683	My Childhood	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2684	My Ain Folk	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2685	My Way Home	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2686	The Naked Prey	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2687	California Split	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2688	Midnight	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2689	Last Holiday	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2690	The MacKintosh Man	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2691	Dark Waters	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2692	Love Letters	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2693	Jack The Giant Killer	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2694	In the Bleak Midwinter	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2695	Sgt. Peppers Lonely Hearts Club Band	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2696	The Intruder	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2697	The Girl Can't Help It	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2698	The Devil Rides Out	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2699	Attack of the Crab Monsters	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2700	Big Bad Mama	(5, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0)
2701	Tripoli	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2702	Quentin Durward	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2703	The More the Merrier	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2704	The Cry Baby Killer	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2705	Arthur	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2706	Zero Hour!	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2707	The Crowded Sky	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2708	Hell in the Pacific	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2709	The Slumber Party Massacre	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2710	The Cars That Ate Paris	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2711	Southie	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2712	Cabin in the Sky	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2713	The Clock	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2714	Dutch	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2715	The Border	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2716	The Wood	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2717	The Deep Blue Sea	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2718	The Thirty Nine Steps	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2719	The Gnome-Mobile	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2720	Bataan	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2721	Convicts	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2722	Thoroughly Modern Millie	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2723	A Time to Love and a Time to Die	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2724	Fingers	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2725	Stranded	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0)
2726	Cat Chaser	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2727	I Mobster	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2728	The Tunnel	(0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2729	The Silent Partner	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2730	Guadalcanal Diary	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2731	The Iron Curtain	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2732	13 Ghosts	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2733	All I Desire	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2734	Thereâ€™s Always Tomorrow	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2735	Interlude	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2736	The Tarnished Angels	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2737	Zorro, the Gay Blade	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2738	The Mark of Zorro	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2739	The Curse of the Cat People	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
2740	The Leopard Man	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2741	Pandora and the Flying Dutchman	(0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2742	Tell Them Willie Boy Is Here	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2743	Kansas City Bomber	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2744	It Conquered the World	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2745	Stakeout on Dope Street	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2746	The Legend of Billie Jean	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2747	Suburbia	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2748	Senti-Mental Journey	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2749	Man Hunt	(5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2750	Operation: Daybreak	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2751	Harriet the Spy	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2752	Frog Dreaming	(0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2753	Rolling Thunder	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2754	The Cheap Detective	(0, 0, 0, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2755	The Reincarnation of Peter Proud	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2756	They Shoot Horses, Don't They?	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2757	For Pete's Sake	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2758	Funny Girl	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2759	Eye of the Cat	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2760	The Strange Door	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2761	The Flesh and the Fiends	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2762	White Dog	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2763	Let's Scare Jessica to Death	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2764	The Vikings	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2765	Visiting Hours	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2766	Safari	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2767	The Wackiest Ship in the Army	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2768	Remember My Name	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2769	Ask Any Girl	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2770	Cool Breeze	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2771	Annie	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2772	Test Pilot	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2773	Silent Tongue	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 5)
2774	The Innocents	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2775	The Return of the Musketeers	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2776	Love in the Afternoon	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2777	The Satan Bug	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0)
2778	CrissCross	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2779	Frogs	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2780	Tension at Table Rock	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2781	The Games	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2782	Ada	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2783	Texasville	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2784	The Little Drummer Girl	(5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2785	The Ambassador	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2786	Edward II	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2787	Raining Stones	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2788	Wild in the Streets	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2789	Move Over, Darling	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2790	The Coca-Cola Kid	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2791	Lady in a Cage	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2792	El Cid	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2793	Scandal	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2794	Buck and the Preacher	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2795	Revenge of the Creature	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2796	The Pleasure of His Company	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2797	The City Under the Sea	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2798	Sorry, Wrong Number	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2799	The Last September	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2800	The Family Way	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2801	The Giant Claw	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0)
2802	Tobruk	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2803	The Boys in the Band	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2804	In Which We Serve	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2805	Easter Parade	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2806	You Were Never Lovelier	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2807	Dancing Lady	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2808	Number Seventeen	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2809	The Long Night	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2810	Donâ€™t Go in the Woods	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2811	Invitation	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2812	Night of the Comet	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 5, 0)
2813	Waiting for Guffman	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2814	The Old Dark House	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2815	Zotz!	(0, 0, 0, 5, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0)
2816	Mr. Sardonicus	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2817	The Houston Story	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2818	The Night Walker	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0)
2819	Serpent of the Nile	(0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2820	Undertow	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2821	Welcome to Hard Times	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2822	Cimarron	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2823	Abandoned	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2824	Too Late for Tears	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2825	T-Men	(0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2826	Happy Birthday to Me	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2827	Motherâ€˜s Day	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2828	The Children's Hour	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2829	In Love and War	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2830	Hollywood Story	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2831	The Unsinkable Molly Brown	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5)
2832	The Landlord	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2833	Wide Sargasso Sea	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2834	Blindfold	(5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2835	Baxter!	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2836	Rudy	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0)
2837	The Wild Duck	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2838	Forbidden Zone	(0, 0, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0)
2839	Audrey Rose	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2840	The Buddy Holly Story	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2841	Holiday Affair	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2842	Three Strangers	(0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2843	Hobson's Choice	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2844	They Won't Believe Me	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2845	Palm Springs Weekend	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2846	They All Laughed	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2847	Conquest of Cochise	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2848	House of Dracula	(0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 5, 0, 0, 0, 0, 0, 0)
2849	Star 80	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2850	Nightwing	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0)
2852	Has Anybody Seen My Gal?	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2853	Riff-Raff	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2854	The Sun Also Rises	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2855	Waltzes from Vienna	(0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0)
2856	Telefon	(5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0)
2857	The Purple Plain	(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0)
2858	Deep End	(0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2859	Easy to Love	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2860	Tarzan's Greatest Adventure	(0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
2861	Texas Across the River	(0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)
2862	Avatar	(0, 7, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 5, 10, 0, 0, 0)
\.


--
-- Data for Name: movies_actors; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY movies_actors (movie_id, actor_id) FROM stdin;
1	3165
1	644
1	1753
1	3768
2	4666
2	4094
2	1560
2	3489
3	2739
3	247
3	4606
3	4870
4	2493
4	3623
4	38
4	4194
5	4292
5	3120
5	3955
5	3271
6	573
6	3449
6	1559
6	1880
7	3205
7	3185
7	4035
7	2835
8	854
8	3477
8	1572
8	3961
9	509
9	573
9	3061
9	802
10	854
10	1572
10	1258
10	4285
11	2474
11	4029
11	2635
11	1880
12	1300
12	1294
12	440
12	335
13	1946
13	1658
13	247
13	3823
14	1417
14	2567
14	166
14	1735
15	1753
15	4186
15	4301
15	1298
16	1753
16	2599
16	3698
16	4133
17	1753
17	2621
17	2472
17	148
18	2170
18	3677
18	914
18	2209
19	1753
19	4296
19	1086
19	118
20	1268
20	2531
20	2325
20	2962
21	2028
21	2856
21	397
21	309
22	573
22	469
22	392
22	2973
23	1268
23	2531
23	2325
23	2594
24	2136
24	562
24	1051
24	812
25	4181
25	2287
25	872
25	3604
26	4029
26	2290
26	74
26	1773
27	3350
27	798
27	2846
27	905
28	294
28	623
28	1353
28	453
29	50
29	4471
29	3414
29	3217
30	2551
30	3959
30	2084
30	3859
31	2136
31	2362
31	4454
31	2558
32	2724
32	4296
32	4029
32	185
33	1270
33	2864
33	3597
33	4145
34	460
34	163
34	754
34	4448
35	389
35	1796
35	1028
35	1241
36	2909
36	293
36	2446
36	3020
37	1372
37	4427
37	2658
37	2128
38	3552
38	1268
38	248
38	1495
39	4929
39	2887
39	1612
39	1997
40	4929
40	2887
40	1057
40	1997
41	4929
41	2887
41	1057
41	1997
42	1589
42	509
42	3245
42	185
43	2449
43	4941
43	1138
43	53
44	324
44	1608
44	3660
44	584
45	3350
45	798
46	4929
46	2887
46	1057
46	1997
47	2735
47	971
47	1550
47	4175
48	4929
48	2887
48	1057
48	1997
49	4929
49	2887
49	1057
49	1997
50	2136
50	4093
50	3307
50	143
51	2979
51	1469
51	4518
51	2136
52	384
52	1516
52	775
52	2183
53	3637
53	4241
53	4029
53	3356
54	3079
54	3673
54	31
54	3321
55	3676
55	2467
55	528
55	2845
56	3456
56	2659
56	1824
56	711
57	3293
57	665
57	4398
57	3674
58	635
58	1930
58	4071
58	1457
59	3676
59	2467
59	528
59	2845
60	3676
60	2467
60	528
60	2845
61	1773
61	4029
61	1038
61	155
62	4093
62	1417
62	4069
62	1546
63	651
63	2504
63	2108
63	3888
64	651
64	1430
64	2015
64	2225
65	294
65	3323
65	2936
65	3728
66	2569
66	1995
66	3888
66	3943
67	1995
67	3513
67	4212
67	207
68	2839
68	2263
68	1610
68	2536
69	1833
69	748
69	3795
69	525
70	3246
70	3861
70	597
70	3677
71	3246
71	3426
71	1132
71	1100
72	2701
72	2355
72	2599
72	4697
73	4010
73	4875
73	882
73	2208
74	4696
74	455
74	3846
74	4397
75	3185
75	50
75	1987
75	3983
76	3146
76	2297
76	4700
76	1940
77	50
77	4035
77	1129
77	4029
78	4948
78	2578
78	4679
78	4105
79	50
79	1129
79	185
79	4537
80	1453
80	4018
80	563
80	1499
81	4451
81	863
81	4805
81	2102
82	431
82	1659
82	1842
82	3774
83	2640
83	3340
83	969
83	3135
84	3677
84	1085
84	4874
84	4702
85	4113
85	4955
85	2063
85	852
86	363
86	399
86	2036
86	1761
87	4032
87	3060
87	3029
87	1669
88	1336
88	3717
88	587
88	2536
89	1732
89	1636
89	783
89	1742
90	3356
90	1946
90	2749
90	3346
91	2290
91	267
91	265
91	4285
92	4903
92	1476
92	4454
92	3797
93	4625
93	3477
93	487
93	4927
94	1441
94	4669
94	1328
94	4169
95	294
95	2936
95	1294
95	4059
96	3860
96	190
96	4679
96	2578
97	1940
97	4350
97	1515
97	3882
98	2724
98	4503
98	4625
98	4722
99	1552
99	1678
99	4604
99	2979
100	1866
100	1899
100	3702
100	831
101	2437
101	2362
101	2543
101	3361
102	1802
102	3656
102	321
103	509
103	267
103	817
103	2152
104	2440
104	1061
104	4000
104	4844
105	1899
105	651
105	831
105	2895
106	1268
106	2531
106	1790
106	556
107	4029
107	2031
107	1332
107	4733
108	4736
108	1724
108	3726
108	1093
109	775
109	3655
109	3378
109	556
110	4225
110	2826
110	2144
110	3924
111	2144
111	2558
111	3756
111	3924
112	2558
112	4903
112	2333
112	4659
113	1813
113	835
113	2098
113	691
114	4941
114	1567
114	2969
114	68
115	4189
115	582
115	4827
115	916
116	4659
116	3564
116	3063
116	1961
117	4680
117	4363
117	4781
117	1760
118	3356
118	969
118	3414
118	805
119	4036
119	1785
119	2449
119	4136
120	3560
120	1837
120	4722
120	2362
121	1534
121	3093
121	2437
121	2460
122	1238
122	4659
122	4756
122	1622
123	651
123	1678
123	548
123	2225
124	1336
124	3936
124	4256
124	1611
125	3288
125	2728
125	4633
125	2118
126	185
126	798
126	4902
126	462
127	3340
127	4325
127	1592
127	2133
128	3477
128	2223
128	934
128	3685
129	3956
129	4381
129	2054
129	2485
130	3860
130	2577
130	4888
130	2787
131	4753
131	4691
131	2236
131	3564
132	2915
132	399
132	3860
132	637
133	2028
133	2756
133	340
133	4667
134	1317
134	854
134	2857
134	81
135	1988
135	1843
135	3642
135	289
136	2561
136	1147
136	2602
136	3251
137	3560
137	1321
137	2557
137	3970
138	2892
138	816
138	2384
138	1748
139	2053
139	1200
139	692
139	4172
140	4010
140	2664
140	2023
140	4924
141	2394
141	1415
141	3953
141	676
142	4856
142	1454
142	3351
142	1577
143	3246
143	2681
143	2013
143	1784
144	3560
144	2826
144	4888
144	1926
145	1866
145	2631
145	4054
145	3764
146	4093
146	3245
146	392
146	4427
147	2346
147	608
147	3223
147	3622
148	4666
148	3334
148	501
148	1035
149	4626
149	3363
149	768
149	4454
150	1813
150	4849
150	1529
150	2821
151	4642
151	4296
151	1127
151	3198
152	1387
152	2567
152	2127
152	4534
153	2551
153	1856
153	3974
153	3918
154	1946
154	3022
154	4922
154	3322
155	958
155	4942
155	182
155	2597
156	1678
156	3881
156	4028
156	2442
157	2449
157	3200
157	4264
157	3655
158	4029
158	4325
158	2303
158	2031
159	934
159	2328
159	1986
159	599
160	3250
160	4186
160	3414
160	2880
161	3906
161	4569
161	3083
161	2553
162	2159
162	3368
162	2925
162	2800
163	270
163	2069
163	4775
163	2358
164	258
164	4258
164	2391
164	1193
165	608
165	401
165	3246
165	2850
166	4065
166	2787
166	4225
166	4280
167	2153
167	3397
167	402
167	1003
168	509
168	1300
168	1806
168	3285
169	1572
169	631
169	1396
169	4426
170	2257
170	3379
170	242
170	351
171	573
171	69
171	3905
171	500
172	655
172	1151
172	1092
172	1975
173	523
173	3854
173	2365
173	295
174	4577
174	2492
174	3059
174	1820
175	1678
175	2028
175	4863
175	4591
176	4666
176	463
176	2720
176	1560
177	636
177	4209
177	1508
177	4095
178	4101
178	4642
178	2223
178	4516
179	2456
179	87
179	370
179	468
180	2028
180	1211
180	518
180	414
181	1396
181	4907
181	4067
181	1277
182	3564
182	3246
182	2287
182	653
183	4172
183	4070
183	3950
183	2998
184	4172
184	2998
184	3486
184	2497
185	2724
185	3225
185	1681
185	4104
186	1238
186	4029
186	239
186	1088
187	1572
187	2341
187	1522
187	814
188	1693
188	3213
188	3814
188	4035
189	1813
189	2052
189	2336
189	716
190	2629
190	2892
190	1475
190	478
191	4907
191	1666
191	1389
191	3503
192	3255
192	11
192	4807
192	3840
193	1819
193	1079
193	4051
193	1232
194	4887
194	464
194	2144
194	3225
195	2664
195	2835
195	647
195	1864
196	3313
196	4065
196	2777
196	3357
197	4691
197	4887
197	2935
197	4807
198	901
198	2254
198	383
198	1168
199	3246
199	2720
199	1092
199	3536
200	4873
200	2724
200	3410
200	3864
201	460
201	934
201	1749
201	3996
202	2436
202	3609
202	4481
202	2141
203	2449
203	1491
203	2870
203	1378
204	2342
204	2039
204	2728
204	3373
205	3777
205	1100
205	278
205	3805
206	4231
206	1723
206	2397
206	2557
207	1439
207	1440
207	2480
207	2730
208	4433
208	1534
208	402
208	2737
209	2544
209	1496
209	3878
209	420
210	4907
210	1189
210	3630
210	4073
211	3426
211	4029
211	2960
211	725
212	4035
212	1199
212	1185
212	3071
213	3655
213	2424
213	3005
213	4022
214	3288
214	473
214	644
214	574
215	3717
215	4065
215	2633
215	4483
216	4296
216	4751
216	2503
216	1941
217	2835
217	907
217	1884
217	3481
218	1200
218	1350
218	4680
218	4219
219	3185
219	2853
219	2610
219	1430
220	1760
220	3507
220	1062
220	1867
221	4296
221	964
221	3001
221	4070
222	4296
222	1840
222	1630
222	4348
223	4296
223	839
223	24
223	3028
224	1799
224	463
224	650
224	2034
225	726
225	4434
225	1935
225	1777
226	4296
226	44
226	2606
226	3427
227	1599
227	1125
227	4568
227	1537
228	4052
228	2055
228	2769
228	3917
229	4363
229	645
229	3323
229	2813
230	2436
230	4241
230	4748
230	573
231	4296
231	2230
231	698
231	2810
232	4113
232	797
232	553
232	3259
233	2290
233	1035
233	3254
233	2031
234	4503
234	4300
234	4063
234	3886
235	3313
235	854
235	251
235	4794
236	4113
236	338
236	908
236	3968
237	1946
237	4339
237	974
237	4281
238	2558
238	163
238	4625
238	1940
239	4947
239	1129
239	3367
239	3139
240	4113
240	2982
240	3362
240	885
241	4113
241	633
241	4711
241	3049
242	4113
242	3259
242	3015
242	2789
243	4829
243	3185
243	2754
243	2610
244	4947
244	1129
244	4708
244	630
245	2385
245	3712
245	1596
245	4004
246	431
246	233
246	1610
246	677
247	4113
247	805
247	4548
247	1677
248	4632
248	3238
248	2197
248	2296
249	3823
249	4292
249	1922
249	1447
250	1856
250	163
250	2002
250	4365
251	1837
251	1773
251	4225
251	226
252	3823
252	2474
252	3419
252	4579
253	294
253	2039
253	4648
253	463
254	903
254	1040
254	2715
254	3080
255	2236
255	2828
255	3577
256	4616
256	4503
256	365
256	3978
257	74
257	4325
257	163
257	2136
258	3823
258	4398
258	4024
258	1092
259	954
259	1427
259	3066
259	2533
260	3340
260	4035
260	349
260	4733
261	4659
261	2133
261	1572
261	1258
262	232
262	1238
262	2633
262	4894
263	1704
263	740
263	1751
263	2775
264	4872
264	4438
264	2780
264	3495
265	705
265	4742
265	3184
265	1356
266	4296
266	2777
266	3276
266	342
267	4659
267	2682
267	4753
267	261
268	573
268	1726
268	4696
268	3610
269	2390
269	3793
269	2259
269	1095
270	3110
270	307
270	3485
270	2022
271	3110
271	4482
271	4054
271	1468
272	1567
272	2398
272	3046
272	4313
273	2436
273	3560
273	2256
273	1171
274	1589
274	3839
274	1773
274	2578
275	3110
275	4124
275	583
275	171
276	3110
276	2955
276	583
276	4915
277	3146
277	2062
277	1352
277	693
278	1680
279	564
279	1347
279	3944
279	427
280	564
280	4262
280	937
280	2616
281	564
281	1360
281	3097
281	1875
282	4029
282	3879
282	2303
282	2997
283	4829
283	822
283	3612
283	4604
284	3058
284	2303
284	962
284	2367
285	3058
285	2303
285	666
285	962
286	1417
286	2530
286	1676
286	4748
287	399
287	4115
287	615
287	4159
288	4093
288	4214
288	3823
288	1772
289	30
289	2039
289	2069
289	2370
290	720
290	4888
290	1469
290	2725
291	1913
291	2798
291	1100
291	2826
292	1693
292	2856
292	1051
292	468
293	3560
293	3288
293	164
293	1097
294	4265
294	4199
294	3896
294	4307
295	4093
295	1469
295	4734
295	743
296	2015
296	4489
296	4341
296	3796
297	1693
297	324
297	1262
297	1770
298	3314
298	2338
298	4189
298	4355
299	509
299	3477
299	1715
299	3840
300	566
300	848
300	4128
300	2216
301	2598
301	2979
301	3781
301	2568
302	1036
302	2181
302	1703
302	2445
303	1330
303	3400
303	3452
303	4311
304	3437
304	1784
305	2720
305	472
305	4029
305	509
306	2724
306	4691
306	1559
306	2720
307	4402
307	589
307	3991
307	3184
308	3564
308	1439
308	3982
308	2234
309	1107
309	283
309	3657
309	1567
310	4907
310	1935
310	86
310	4310
311	4374
311	4836
311	3715
311	714
312	3381
312	3660
312	1860
312	4224
313	1946
313	1454
313	2374
313	3753
314	4850
314	236
314	2906
314	4859
315	2145
315	1446
315	3915
315	2811
316	3786
316	1348
316	1897
316	3631
317	2031
317	4391
317	1066
317	3772
318	1110
318	1264
318	1570
318	4620
319	3950
319	1509
319	4578
319	3300
320	1480
320	2891
320	507
320	2519
321	1449
321	4193
321	4080
321	2877
322	1010
322	1644
322	3200
322	3460
323	4860
323	4753
323	2284
323	2116
324	3787
324	601
324	3863
324	2364
325	2693
325	3052
325	1480
325	137
326	678
326	4720
326	4419
326	2524
327	2236
327	608
327	3499
327	4614
328	491
328	798
328	2278
328	697
329	4666
329	4679
329	1289
329	374
330	4666
330	3288
330	464
330	4162
331	1658
331	2397
331	3414
331	4519
332	3250
332	923
332	2444
332	134
333	294
333	4325
333	3851
333	4137
334	4666
334	4613
334	1186
334	2407
335	4666
335	4613
335	2262
335	2686
336	2885
336	1223
336	3875
336	3081
337	294
337	3121
337	4955
337	2235
338	2449
338	2629
338	2565
338	1238
339	4325
339	4890
339	4651
339	3829
340	3177
340	4626
340	1806
340	3334
341	3430
341	1831
341	4556
341	742
342	1573
342	1198
342	1063
342	2113
343	4874
343	3100
343	971
343	46
344	3723
344	4868
344	2880
344	4070
345	3184
345	856
345	224
345	4854
346	4093
346	1238
346	2551
346	491
347	4659
347	1946
347	1085
347	2720
348	2026
348	1067
348	1837
348	1318
349	4466
349	1295
349	217
349	2610
350	1528
350	3492
350	943
350	4577
351	2362
351	1333
351	3996
351	4160
352	1238
352	4065
352	1951
352	3195
353	589
353	2610
353	4591
353	3537
354	2631
354	651
354	3283
354	4822
355	3717
355	1598
355	3039
355	3479
356	2544
356	3109
356	3211
356	3030
357	1866
357	2831
357	2422
357	3193
358	4837
358	880
358	4749
358	1435
359	4466
359	1454
359	3692
359	1954
360	717
360	3733
360	1947
361	4466
361	4078
361	1963
361	1181
362	2749
362	573
362	2380
362	4894
363	2449
363	1554
363	905
363	2813
364	1011
364	2690
364	4287
364	1564
365	3627
365	967
365	1635
365	3953
366	4613
366	69
366	4709
366	4228
367	1850
367	2392
367	2745
367	1187
368	4975
368	3818
368	2361
368	4063
369	3250
369	2118
369	3127
369	1730
370	2565
370	1200
370	1832
370	844
371	3796
371	1037
371	4079
371	618
372	49
372	3282
372	4854
372	1424
373	3107
373	3379
373	3709
373	930
374	3293
374	971
374	1550
374	3461
375	3293
375	971
375	2303
375	2518
376	3293
376	971
376	2303
376	3909
377	3293
377	971
377	2303
377	3909
378	2263
378	3015
378	3067
378	3092
379	3793
379	86
379	272
379	1935
380	1199
380	2039
380	3502
380	3635
381	50
381	4029
381	4753
381	2463
382	294
382	3742
382	3641
383	4659
383	2463
383	1377
383	1811
384	3291
384	3996
384	464
385	593
385	3151
385	1654
385	2239
386	1866
386	3786
386	3211
386	1652
387	2986
387	3229
387	3590
387	1638
388	2492
388	1161
388	233
388	4621
389	4962
389	1317
389	4466
389	691
390	2769
390	2839
390	2121
390	705
391	50
391	2341
391	696
391	770
392	2769
392	3862
392	25
392	1601
393	589
393	4700
393	4497
393	3203
394	509
394	2042
394	1048
394	337
395	1813
395	943
395	3214
395	272
396	651
396	2631
396	2028
396	4190
397	1502
397	2836
397	2069
397	194
398	4296
398	3328
398	802
398	4207
399	854
399	179
399	2438
399	3910
400	1940
400	4849
400	4503
400	4808
401	2053
401	1940
401	3340
401	4283
402	2028
402	4082
402	1496
402	4071
403	3717
403	1958
403	3825
403	1587
404	1003
404	4005
404	616
404	4706
405	2839
405	3328
405	84
405	2399
406	1238
406	4496
406	3799
406	4531
407	1515
407	356
407	1296
407	3830
408	3297
408	2629
408	4268
408	4370
409	2290
409	3959
409	464
409	1999
410	1572
410	4172
410	1458
410	4704
411	1021
411	4770
411	4266
411	2340
412	3959
412	4763
412	301
412	2413
413	2136
413	4625
413	2262
413	1841
414	3677
414	2664
414	1550
414	2994
415	892
415	292
415	1701
415	4807
416	2796
416	4877
416	4530
416	1006
417	2492
417	115
417	3623
417	4720
418	2796
418	2857
418	1396
418	1199
419	232
419	4790
419	1896
419	178
420	3245
420	1715
420	2530
420	658
421	267
421	1376
421	2003
421	803
422	2436
422	2006
422	4221
422	2079
423	755
423	811
423	4148
423	3419
424	4164
424	3787
424	2406
424	3641
425	472
425	4948
425	3655
425	3748
426	4523
426	4537
426	591
426	623
427	4523
427	4537
427	591
427	623
428	4523
428	3941
428	534
428	458
429	4523
429	3941
429	3089
429	2797
430	4523
430	4537
430	591
430	623
431	4523
431	4537
431	591
431	623
432	4523
432	4537
432	591
432	4210
433	651
433	4396
433	3191
433	1763
434	775
434	4703
434	4413
434	4107
435	1589
435	2173
435	3356
435	4241
436	2007
436	4358
436	443
436	1110
437	473
437	962
437	574
437	3663
438	1565
438	3255
438	1491
438	3272
439	540
439	602
439	1231
439	941
440	3452
440	3665
440	1010
440	992
441	163
441	3780
441	2026
441	2830
442	2188
442	2390
442	357
442	1883
443	2290
443	749
443	2950
443	4663
444	2771
444	2031
444	2640
444	2509
445	726
445	2069
445	3623
445	2489
446	3782
446	18
446	3722
446	1274
447	3328
447	1879
447	553
447	2412
448	1719
448	291
448	4363
448	2989
449	2538
449	1318
449	2513
449	3408
450	2157
450	4447
450	1148
450	4123
451	2096
451	882
451	1138
451	883
452	2747
452	2551
452	2720
452	4890
453	4465
453	1138
453	2664
453	2287
454	4683
454	2394
454	4084
454	3566
455	573
455	2188
455	4241
455	1681
456	4029
456	2303
456	670
456	1503
457	2028
457	2347
457	4379
457	876
458	2028
458	1204
458	2954
458	1820
459	2449
459	2892
459	2578
459	988
460	3959
460	1300
460	2828
460	2396
461	3796
461	1337
461	1610
461	1823
462	4029
462	3552
462	2221
462	2578
463	4029
463	728
463	2928
463	1482
464	4292
464	1370
464	895
464	3756
465	865
465	4188
465	3037
466	4446
466	471
466	2249
466	461
467	1268
467	934
467	2039
467	1086
468	4065
468	4955
468	2048
468	3477
469	4948
469	891
469	1300
469	1994
470	1572
470	4888
470	1476
470	507
471	2647
471	3231
471	3236
471	2223
472	2090
472	2994
472	328
472	3363
473	1439
473	4280
473	1156
473	4292
474	1330
474	523
474	1477
474	3621
475	2664
475	4251
475	1100
475	2142
476	4251
476	392
476	3260
476	4470
477	4251
477	2192
477	1103
477	4867
478	3185
478	3129
478	2130
478	660
479	2747
479	2136
479	3506
479	4251
480	3254
480	4251
480	4241
480	2739
481	2855
481	691
481	1396
481	4568
482	4300
482	1559
482	1258
482	4094
483	4296
483	83
483	4285
483	4225
484	824
484	3867
484	3951
484	3500
485	726
485	398
485	2267
485	2854
486	4102
486	2754
486	511
486	3512
487	2664
487	546
487	758
488	2147
488	560
488	343
488	1015
489	1987
489	2647
489	3956
489	1479
490	3560
490	2346
490	2397
490	4815
491	4102
491	825
491	3512
491	2909
492	4363
492	1837
492	4885
492	4914
493	1336
493	4097
493	1995
493	648
494	3626
494	2565
494	916
494	387
495	4644
495	722
495	1084
495	3720
496	4300
496	2530
496	2629
496	3657
497	167
497	3367
497	4947
497	1825
498	3513
498	3929
498	4179
498	1588
499	3293
499	1671
499	2272
499	452
500	3796
500	2202
500	4486
500	3050
501	69
501	2915
501	2551
501	40
502	4812
502	4444
502	4704
502	752
503	4848
503	3650
503	2660
503	877
504	52
504	4005
504	2335
504	2736
505	2618
506	2720
506	2388
506	1138
506	801
507	1659
507	1063
507	2401
507	1214
508	1004
508	1659
508	1925
508	349
509	1144
509	1205
509	2349
509	1679
510	2475
510	1439
510	774
510	4696
511	3006
511	3185
511	2503
511	272
512	1998
512	3852
512	3519
512	4199
513	3340
513	4785
513	2067
513	4953
514	392
514	3245
514	2935
514	2094
515	818
515	214
515	1141
515	3447
516	4052
516	725
516	4526
516	2375
517	668
517	4296
517	4815
517	4885
518	1956
518	2007
518	789
518	4894
519	1350
519	3575
519	4451
519	1814
520	4759
520	1175
520	1127
520	1755
521	2236
521	891
521	493
521	969
522	1697
522	3306
522	389
522	4362
523	2449
523	402
523	4644
523	1340
524	4402
524	4358
524	2631
524	2632
525	3677
525	597
525	2846
525	989
526	3185
526	4577
526	1438
526	1953
527	1113
527	190
527	77
527	48
528	3861
528	3649
528	3866
528	1321
529	2771
529	2099
529	2543
529	4005
530	1940
530	4849
530	4127
530	2535
531	3183
531	4910
531	3806
531	2387
532	3165
532	1753
532	644
532	1039
533	3511
533	1439
533	2915
533	1882
534	953
534	4727
534	2893
534	2894
535	4402
535	1528
535	1573
535	1146
536	2449
536	3185
536	1454
536	1717
537	277
537	4831
537	1109
537	961
538	1453
538	4451
538	3885
538	4819
539	2664
539	722
539	2089
539	1686
540	4345
540	3463
540	3493
540	3816
541	2494
541	1582
541	4685
541	2533
542	4052
542	3146
542	4138
542	4693
543	2120
543	1068
543	1037
543	3490
544	4052
544	2121
544	3467
544	1824
545	1576
545	943
545	853
545	4811
546	4358
546	1215
546	4238
546	3735
547	3717
547	1430
547	2853
547	3863
548	2839
548	631
548	2668
548	3209
549	2290
549	2915
549	3516
549	3971
550	2171
550	2530
550	1880
550	4888
551	267
551	2373
551	232
551	2360
552	3854
552	4810
552	4380
552	2647
553	3340
553	1715
553	4803
553	3372
554	3256
554	4221
554	2462
554	4377
555	431
555	1813
555	1586
555	3106
556	3184
556	2064
556	3396
556	3986
557	2308
557	1453
557	2901
557	4018
558	4874
558	3073
558	2652
558	4869
559	2028
559	2756
559	1940
559	1401
560	4503
560	3552
560	3798
560	209
561	2125
561	295
561	2813
561	4954
562	3952
562	4235
562	2533
562	1305
563	2346
563	1900
563	2396
563	2924
564	3250
564	3655
564	3794
564	2149
565	731
565	3560
565	4808
565	3613
566	1107
566	3507
567	2749
567	4753
567	4576
567	1545
568	3950
568	1663
568	2106
568	3613
569	3288
569	3250
569	2683
569	4561
570	4251
570	464
570	3780
570	3762
571	4651
571	491
571	1699
571	2284
572	401
572	3655
572	4744
572	3232
573	1946
573	2640
573	4050
573	4906
574	2449
574	890
574	712
574	805
575	83
575	2749
575	3363
575	2031
576	1559
576	2870
576	229
576	2578
577	4242
577	3518
577	1017
577	2917
578	1359
578	356
578	2860
578	2264
579	1359
579	217
579	682
579	4895
580	294
580	2644
580	990
580	4230
581	2086
581	760
581	4602
581	138
582	1152
582	4522
582	4054
582	2880
583	4465
583	4801
583	3952
583	3141
584	1366
584	269
584	2529
584	3465
585	2692
585	1955
585	4685
585	772
586	3293
586	2780
586	1690
586	3120
587	3350
587	1567
587	2268
587	3365
588	4181
588	1710
588	2739
588	1994
589	4659
589	4035
589	3564
589	3869
590	4101
590	72
590	4967
590	4304
591	4540
591	4426
591	3539
591	3589
592	4523
592	1773
592	3879
592	4029
593	4024
593	3634
593	4285
593	3023
594	3959
594	1597
594	1132
594	491
595	4198
595	566
595	1914
595	4136
596	4910
596	3452
596	1784
596	2805
597	4850
597	2263
597	344
597	3786
598	4434
598	3872
598	1278
598	1199
599	2796
599	1928
599	2639
599	3055
600	2796
600	105
600	3448
600	2884
601	1805
601	3123
601	2317
601	43
602	1034
602	1614
602	4327
602	4445
603	4613
603	3912
603	4422
603	4679
604	4102
604	1194
604	1356
604	1336
605	1565
605	2144
605	932
605	2563
606	1439
606	3655
606	3552
606	2506
607	250
607	292
607	1720
607	1845
608	3564
608	464
608	83
608	386
609	392
609	2091
609	2315
609	653
610	2221
610	292
610	1525
610	1197
611	718
611	816
611	4029
611	4361
612	2436
612	3061
612	4633
613	4093
613	4225
613	1360
613	3602
614	4666
614	1333
614	4050
614	2367
615	4093
615	292
615	1733
615	1428
616	4625
616	1334
616	967
616	3244
617	541
617	2135
617	3145
617	2094
618	2738
618	2091
618	2191
618	2094
619	2188
619	4595
619	292
619	2307
620	2876
620	1434
620	3008
620	292
621	2796
621	4475
621	3603
621	1727
622	3414
622	3255
622	3602
622	83
623	4065
623	4358
623	934
623	1046
624	2724
624	1999
624	154
624	4630
625	4246
625	1530
625	3149
625	1375
626	3655
626	2495
626	292
626	4555
627	517
627	894
627	3196
627	4561
628	4961
628	3928
628	1985
628	3588
629	1527
629	981
629	829
629	3407
630	3276
630	3319
630	648
630	1895
631	481
631	1678
631	4907
631	273
632	378
632	3568
632	1547
632	4778
633	3426
633	1183
633	950
633	730
634	4094
634	650
634	770
634	3084
635	1152
635	3102
635	3640
635	3017
636	1916
636	2126
636	787
636	2124
637	3450
637	2501
637	4341
637	3929
638	4659
638	3886
638	638
638	1838
639	134
639	4459
639	1466
639	333
640	134
640	440
640	3370
640	4680
641	2335
641	134
641	3265
641	272
642	1981
642	3328
642	2936
642	2459
643	3288
643	83
643	3527
643	2647
644	3206
644	1107
644	3288
644	2729
645	2335
645	3058
645	154
645	2115
646	2335
646	934
646	247
646	4429
647	4666
647	993
647	1422
647	2335
648	2335
648	1422
648	4050
648	3288
649	3959
649	1078
649	3013
649	1024
650	3959
650	2870
650	3433
650	4670
651	4523
651	4325
651	2031
651	4100
652	4947
652	2773
652	473
652	2543
653	4941
653	775
653	4318
653	2969
654	3340
654	4300
654	1067
654	2020
655	4225
655	2564
655	2594
655	1051
656	4644
656	3896
656	4903
656	2256
657	4042
657	2568
657	2979
657	683
658	4176
658	4910
658	2747
658	2162
659	1783
659	2515
659	3327
660	2449
660	1882
660	655
660	3346
661	3293
661	267
661	2839
661	1293
662	3142
662	128
662	3687
662	4934
663	737
663	993
663	4225
663	3365
664	1940
664	4350
664	3008
664	847
665	4511
665	4746
665	2075
665	1632
666	2502
666	3800
666	2543
666	1880
667	1880
667	3747
667	3890
667	3693
668	1899
668	1610
668	3124
668	227
669	1258
669	3217
669	3323
670	2262
670	204
670	3874
670	798
671	4575
671	1864
671	1710
671	455
672	3212
672	304
672	2587
672	3078
673	2360
673	3786
673	3060
673	4082
674	3593
674	1119
674	3750
674	1302
675	3959
675	2834
675	2541
675	1790
676	1573
676	2903
676	3624
676	1618
677	3206
677	699
677	3230
677	923
678	4941
678	1417
678	2065
678	4470
679	3021
679	832
679	35
679	828
680	3237
680	4303
681	2717
681	103
681	2603
681	1909
682	2395
682	1964
682	866
682	1074
683	4035
683	469
683	2582
683	1450
684	1037
684	1459
684	4054
684	617
685	1946
685	1799
685	1687
685	907
686	2449
686	722
686	2301
686	3549
687	204
687	3874
687	798
687	779
688	2796
688	4890
688	4029
688	1200
689	432
689	1671
689	1129
689	3073
690	3400
690	3604
690	3938
690	1489
691	2436
691	163
691	4910
691	491
692	3220
692	710
692	329
693	3941
693	394
693	2566
693	3354
694	2436
694	3414
694	805
694	142
695	460
695	934
695	4363
695	1749
696	425
696	2911
696	4840
696	3051
697	3296
697	3255
697	3356
697	3076
698	850
698	1935
698	3153
698	3406
699	3164
699	984
699	4101
699	3697
700	324
700	3793
700	1317
700	1857
701	364
701	3578
701	1080
701	4541
702	1836
703	3299
703	4120
703	3775
703	2556
704	4682
704	4120
704	2374
704	631
705	1940
705	4120
705	1220
705	3432
706	2015
706	1834
706	815
706	1583
707	3003
707	503
707	900
708	3711
708	1055
708	797
709	705
709	3923
709	2864
709	389
710	4380
710	523
710	3048
710	2985
711	1577
711	3291
711	3210
711	3062
712	2236
712	888
712	4301
712	4695
713	1268
713	3627
713	3602
713	3762
714	1068
714	1037
714	4326
714	1021
715	4700
715	835
715	4326
715	4081
716	1942
716	4117
716	4326
716	1874
717	1061
717	1337
717	4326
717	3501
718	3686
718	352
718	4326
718	3692
719	4853
719	385
719	1586
719	4174
720	1704
720	1751
720	740
720	4983
721	2373
721	3874
721	3548
722	4379
722	3859
722	2953
722	389
723	3768
723	4780
723	1519
723	4372
724	1892
724	3653
724	2953
724	389
725	378
725	2953
725	503
725	389
726	822
726	833
726	4845
726	4146
727	3768
727	1780
727	4077
727	797
728	1512
728	1648
728	1292
728	1390
729	2759
729	2979
729	3686
729	419
730	2110
730	2028
730	831
730	1287
731	3310
731	2839
731	1037
731	1468
732	651
732	4141
732	3859
732	1574
733	356
733	1813
733	693
733	1423
734	1813
734	2934
734	4792
734	669
735	2440
735	3474
735	2282
735	4844
736	1866
736	4848
736	4621
736	561
737	2759
737	3924
737	3132
737	2537
738	2728
738	4715
738	2271
738	4010
739	503
739	2987
739	2336
739	238
740	3768
740	4494
740	4608
740	4055
741	2440
741	3265
741	369
741	4851
742	64
742	2110
742	4764
742	514
743	2544
743	2015
743	1932
743	689
744	2440
744	2150
744	4775
744	3513
745	1238
745	2463
745	4526
745	2401
746	998
746	339
746	3527
746	2601
747	3768
747	1483
747	1425
747	3347
748	267
748	769
748	1536
748	3797
749	3205
749	4381
749	4858
749	1556
750	4197
750	3152
750	1741
750	1124
751	2261
751	1932
751	4980
751	1433
752	2565
752	4575
752	55
752	3775
753	797
753	2606
753	2255
753	2022
754	589
754	3723
754	2132
754	4515
755	503
755	2911
755	2605
755	713
756	4475
756	1381
756	1437
756	2634
757	2125
757	23
757	4472
757	3543
758	1753
758	3296
758	4363
758	83
759	2221
759	2759
759	4229
759	376
760	4919
760	3492
760	3264
760	3508
761	1263
761	1902
761	2849
761	2825
762	1336
762	3185
762	4038
762	538
763	1126
763	474
763	270
763	3153
764	4941
764	195
764	4874
764	4770
765	530
765	1323
765	917
765	3584
766	1715
766	1439
766	4696
766	1112
767	2954
767	3808
767	1204
767	3802
768	4396
768	3796
768	4824
768	73
769	1141
769	2934
769	1947
769	1272
770	3872
770	2421
770	3749
770	4023
771	4792
771	634
771	2987
771	2372
772	75
772	4596
772	2074
772	702
773	3293
773	1560
773	1084
773	3909
774	3888
774	1291
775	4223
775	3305
775	3276
775	4711
776	4460
776	1903
776	2499
776	1810
777	3793
777	3796
777	4947
777	4120
778	4199
778	4221
778	3437
778	3536
779	4066
779	1133
779	126
779	3298
780	4066
780	1133
780	3298
780	489
781	592
781	2119
781	708
781	1500
782	4006
782	3623
782	1438
782	1657
783	4006
783	1659
783	2489
783	1601
784	3414
784	50
784	1790
784	2627
785	1158
785	2077
785	3428
785	505
786	3746
786	308
786	1574
786	2468
787	3746
787	308
787	2822
787	977
788	3746
788	308
788	2822
788	925
789	3746
789	308
789	2822
789	925
790	2449
790	1806
790	69
790	4635
791	925
791	3746
791	308
791	2822
792	3746
792	308
792	2822
792	925
793	308
793	2822
793	925
793	2468
794	3746
794	308
794	2822
794	925
795	3746
795	308
795	2822
795	925
796	3746
796	308
796	2822
796	925
797	3746
797	308
797	2822
797	3160
798	3746
798	308
798	2822
798	3160
799	1079
799	3054
799	475
799	4286
800	3356
800	83
800	1565
800	253
801	3717
801	1295
801	1337
801	1127
802	219
802	3058
802	934
802	2039
803	3340
803	185
803	2699
803	2621
804	3150
804	4053
804	467
805	2258
805	736
805	130
805	1252
806	2723
806	3320
807	1773
807	1180
807	3538
807	4717
808	201
808	4293
808	2668
808	1616
809	201
809	4293
809	4135
809	4645
810	2723
810	3241
810	2990
811	1899
811	1693
811	3331
811	3917
812	1899
812	2492
812	3396
813	76
813	2831
813	2129
813	1899
814	2723
814	488
814	3165
815	3798
815	3314
815	4368
815	2982
816	3798
816	2050
816	3542
816	3073
817	3938
817	2181
817	3674
817	3015
818	3536
818	1000
818	888
818	4383
819	1000
819	3536
819	888
819	4265
820	2723
821	3798
821	2831
821	644
821	2360
822	2173
822	3205
822	277
822	3284
823	802
823	1630
823	839
823	4120
824	4250
824	4799
824	1490
824	1974
825	3959
825	2173
825	4503
825	2957
826	2290
826	4580
826	3555
826	3525
827	1085
827	4803
827	232
827	2085
828	7
828	1781
828	1582
828	4705
829	1834
829	1201
829	4574
829	1114
830	3927
830	1558
830	3626
830	1834
831	4742
831	3660
831	1834
831	2610
832	509
832	267
832	40
832	2550
833	509
833	1753
833	2552
833	3104
834	4065
834	1085
834	4948
834	4313
835	3967
835	270
835	639
835	1880
836	430
836	32
836	1759
836	2841
837	658
837	1582
837	793
837	2494
838	3938
838	2627
838	1915
838	4700
839	2295
839	1627
839	3683
839	3019
840	2629
840	1376
840	1856
840	4685
841	731
841	4941
841	779
841	491
842	3205
842	549
842	4225
842	1116
843	610
843	1685
843	1633
843	2318
844	2031
844	534
844	4801
844	132
845	2657
845	3358
845	3277
845	2795
846	1152
846	1221
846	3700
846	3136
847	3936
847	51
847	4120
847	4754
848	909
848	366
848	860
848	1235
849	909
849	590
849	1235
849	3062
850	1538
850	4585
850	477
850	782
851	1199
851	1510
851	2956
851	1874
852	850
852	1578
852	2388
852	4525
853	2551
853	3959
853	2262
853	4009
854	927
854	4215
854	2923
854	4811
855	651
855	324
855	4849
855	1991
856	2172
856	4071
856	2767
856	4033
857	1469
857	846
857	4724
857	1818
858	1502
858	2767
858	1646
858	4466
859	1847
859	205
859	1163
859	4784
860	3959
860	2749
860	4748
860	1385
861	573
861	3959
861	4358
861	1136
862	3185
862	1502
862	3651
862	2121
863	3616
863	1510
863	4434
863	2015
864	1861
864	4348
864	1442
864	4880
865	2809
865	850
865	1861
865	4193
866	3604
866	1337
866	3924
866	688
867	3328
867	1510
867	2610
867	1254
868	1037
868	1510
868	2383
868	916
869	1293
869	3362
869	3598
869	1083
870	4113
870	1835
870	276
870	3598
871	1183
871	4510
871	2098
871	4623
872	4296
872	725
872	4260
872	2322
873	1183
873	3742
873	4902
873	486
874	2015
874	1898
874	4100
874	3537
875	771
875	4638
875	162
875	4430
876	1756
876	1898
876	3292
877	854
877	1898
877	1254
877	3648
878	1608
878	1898
878	2675
878	3751
879	3991
879	1898
879	1813
879	1763
880	4962
880	815
880	1898
880	726
881	2028
881	1813
881	1898
881	1557
882	4792
882	1709
882	4062
882	232
883	4097
883	1211
883	4707
883	855
884	481
884	1898
884	3219
884	1248
885	1781
885	2552
885	2495
885	2817
886	4097
886	1211
886	4707
886	4591
887	4872
887	1550
887	4954
887	3355
888	3454
888	2192
888	99
888	1636
889	590
889	2160
889	3527
889	3025
890	590
890	1262
890	1259
890	409
891	590
891	2780
891	2227
891	4062
892	590
892	661
892	398
892	1306
893	1061
893	4052
893	1898
893	4102
894	3177
894	590
894	2333
894	2558
895	4753
895	1246
895	2619
895	2511
896	1646
896	4296
896	3863
896	100
897	4222
897	2639
897	231
897	3646
898	2360
898	3333
898	3405
898	1394
899	3153
899	3811
899	3053
899	4111
900	3299
900	3798
900	3279
900	1643
901	3966
901	1337
901	4522
901	4514
902	2714
902	359
902	410
902	703
903	2714
903	2238
903	1764
903	2273
904	4357
904	2238
904	981
904	2714
905	2238
905	2714
905	4357
905	359
906	4357
906	2238
906	191
906	2714
907	4357
907	2714
907	2238
907	140
908	1671
908	4889
908	398
908	3025
909	4889
909	1200
909	2601
909	586
910	3314
910	644
910	3328
910	349
911	3340
911	3325
911	4832
911	4092
912	4181
912	774
912	2981
912	929
913	3073
913	87
913	4072
913	3013
914	4890
914	2681
914	4344
914	2302
915	2136
915	4214
915	294
915	3842
916	3987
916	4344
916	3022
916	587
917	3313
917	665
917	545
917	2648
918	1769
918	865
918	1208
918	2975
919	4067
919	4575
919	3798
919	3306
920	3959
920	4580
920	1985
920	1130
921	2137
921	1484
921	4488
921	1670
922	1010
922	3302
922	3667
922	1392
923	1010
923	1315
923	3441
924	3691
924	4758
924	4581
924	3870
925	3691
925	4758
925	4581
925	3870
926	985
926	2431
926	1007
926	1920
927	1753
927	4691
927	4305
927	2558
928	2655
928	86
928	674
928	1823
929	849
929	572
929	1731
929	531
930	3800
930	3498
930	942
931	3800
931	390
931	2361
931	3147
932	290
932	3661
932	1984
932	3757
933	3922
933	1530
933	2466
933	739
934	4628
934	1799
934	444
934	3390
935	656
935	4916
935	4501
935	2141
936	3736
936	1329
936	3168
936	1134
937	559
937	788
937	2880
937	4894
938	1572
938	349
938	1100
938	598
939	1602
939	4568
939	288
939	2068
940	1160
940	912
940	3095
940	2382
941	324
941	76
941	1617
941	826
942	76
942	4509
942	1857
942	1275
943	3717
943	2561
943	2921
943	1739
944	3340
944	2747
944	1429
944	2749
945	737
945	440
945	2578
945	2450
946	1830
946	2779
946	4535
947	348
947	566
947	2601
947	4896
948	3009
948	3350
948	4153
948	3294
949	465
949	463
949	3544
949	3656
950	1152
950	1987
950	3328
950	4296
951	2728
951	779
951	2654
951	1319
952	3956
952	4466
952	475
952	4386
953	4466
953	3717
953	4907
953	1454
954	4466
954	4360
954	1316
954	4134
955	4466
955	2610
955	538
955	307
956	4466
956	2845
956	1317
956	398
957	4466
957	3924
957	3941
957	615
958	4466
958	1238
958	4946
958	4030
959	4466
959	2007
959	3924
959	691
960	4466
960	398
960	4062
960	2296
961	4466
961	4323
961	3335
961	4195
962	4097
962	2831
962	4071
962	1218
963	1577
963	699
963	2487
963	2539
964	2890
964	3608
964	2400
964	3400
965	4707
965	203
965	4054
965	3269
966	194
966	1336
966	4097
966	1624
967	1306
967	4730
967	1992
967	3774
968	1753
968	239
968	1043
968	1965
969	1946
969	4503
969	3414
969	731
970	1005
970	4241
970	3560
970	1799
971	50
971	4300
971	3742
971	2384
972	3796
972	180
972	1823
972	588
973	1559
973	4941
973	267
973	2664
974	3507
974	3079
974	2367
974	249
975	4874
975	2652
975	1991
975	361
976	294
976	969
976	1376
976	1491
977	3521
977	2850
977	4786
977	3272
978	4172
978	4858
978	616
978	3079
979	763
979	1572
979	1454
979	4063
980	3253
980	3317
980	230
980	4611
981	1589
981	3177
981	1884
981	4403
982	4251
982	3564
982	4481
982	1138
983	969
983	1693
983	3742
983	3825
984	4465
984	409
984	672
984	3056
985	3560
985	4350
985	333
985	1285
986	691
986	2229
986	1227
986	4415
987	1268
987	3201
987	3596
987	3549
988	2440
988	4480
988	1401
988	1442
989	2440
989	1626
989	4851
989	3376
990	4052
990	2572
990	1558
990	75
991	1866
991	324
991	4907
991	4847
992	1589
992	3564
992	3091
992	292
993	589
993	324
993	320
993	2427
994	2440
994	4052
994	1987
994	687
995	496
995	4056
995	379
995	4846
996	814
996	1760
996	1518
996	438
997	726
997	233
997	4962
997	1295
998	1172
998	1256
998	2722
998	235
999	726
999	2338
999	3195
999	384
1000	4438
1000	773
1000	3018
1000	2685
1001	2867
1001	2706
1001	1752
1001	2920
1002	360
1002	4197
1002	3062
1002	2707
1003	1238
1003	3909
1003	3477
1003	2739
1004	4455
1004	663
1004	3720
1004	4118
1005	4858
1005	4629
1005	3013
1005	2277
1006	2448
1006	4101
1006	4513
1006	3975
1007	648
1007	3894
1007	3858
1007	194
1008	1621
1008	3524
1008	2897
1008	1938
1009	4341
1009	3171
1009	745
1009	3863
1010	2796
1010	2751
1010	1095
1010	2010
1011	4296
1011	4872
1011	1773
1011	652
1012	4358
1012	3328
1012	3556
1012	3835
1013	3936
1013	4113
1013	3961
1013	1740
1014	2136
1014	1294
1014	3031
1014	2329
1015	4093
1015	1132
1015	539
1015	2173
1016	37
1016	2471
1016	2829
1016	921
1017	1940
1017	2851
1017	521
1017	2493
1018	4593
1018	2968
1019	3414
1019	1589
1019	3069
1019	88
1020	3727
1020	607
1020	4774
1020	728
1021	4381
1021	3825
1021	152
1021	4911
1022	3710
1022	4791
1022	19
1022	362
1023	4612
1023	4276
1023	2630
1023	39
1024	3254
1024	3748
1024	4470
1024	4903
1025	2551
1025	3666
1025	2719
1025	1331
1026	3344
1026	1800
1026	4626
1026	3931
1027	2248
1027	2066
1027	621
1027	3873
1028	4659
1028	576
1028	1321
1028	2958
1029	2236
1029	4744
1029	83
1029	3965
1030	1582
1030	2588
1030	4389
1030	757
1031	1710
1031	3883
1031	972
1031	2373
1032	2130
1032	3115
1032	2704
1032	1894
1033	955
1033	1376
1033	3756
1033	2395
1034	779
1034	2016
1034	666
1034	3770
1035	650
1035	3970
1035	4114
1035	158
1036	1346
1036	3517
1036	1388
1036	327
1037	796
1037	4165
1037	819
1037	4296
1038	796
1038	4296
1038	4820
1038	3349
1039	2436
1039	1572
1039	3909
1039	969
1040	691
1040	398
1040	3942
1040	2229
1041	1439
1041	608
1041	1837
1041	1084
1042	277
1042	4221
1042	2286
1042	729
1043	4363
1043	4941
1043	1169
1043	4125
1044	4029
1044	2892
1044	1340
1044	752
1045	1336
1045	3936
1045	3914
1045	4102
1046	3790
1046	3023
1046	1032
1046	246
1047	3065
1047	4142
1048	4029
1048	2118
1048	3514
1048	4427
1049	2346
1049	2739
1049	2530
1049	119
1050	3328
1050	523
1050	1157
1050	4743
1051	3314
1051	4910
1051	2300
1051	83
1052	3560
1052	2287
1052	2006
1052	750
1053	4947
1053	3314
1053	2568
1053	4708
1054	4910
1054	2855
1054	534
1054	2280
1055	4770
1055	1806
1055	1376
1055	267
1056	4849
1056	4070
1056	3195
1056	1790
1057	4103
1057	3287
1057	2672
1057	1584
1058	651
1058	1068
1058	3946
1058	3535
1059	4666
1059	1799
1059	762
1059	3721
1060	2724
1060	3477
1060	775
1060	3217
1061	4888
1061	3592
1061	4299
1061	1009
1062	737
1062	4465
1062	3206
1062	3654
1063	3647
1063	3843
1063	1811
1063	1184
1064	3494
1064	3392
1064	3157
1064	4253
1065	4292
1065	4395
1065	4978
1065	3526
1066	2992
1066	4583
1066	2500
1066	2081
1067	2835
1067	4225
1067	2639
1067	2311
1068	775
1068	188
1068	2676
1068	735
1069	775
1069	2720
1069	1559
1069	1360
1070	4282
1070	2290
1070	3202
1070	2339
1071	3175
1071	2787
1071	3682
1071	2189
1072	1772
1072	232
1072	3250
1072	539
1073	2236
1073	2142
1073	2833
1073	3438
1074	1184
1074	4757
1074	1250
1074	3763
1075	2328
1075	4622
1075	2438
1075	4776
1076	4887
1076	2728
1076	2702
1076	4221
1077	691
1077	574
1077	422
1077	3361
1078	177
1078	2478
1078	664
1078	4586
1079	1113
1079	4679
1079	2159
1079	1176
1080	803
1080	3119
1080	1572
1080	1957
1081	517
1081	3328
1081	1439
1081	2234
1082	665
1082	4176
1082	1963
1082	3602
1083	4856
1083	50
1083	3065
1083	719
1084	555
1084	4288
1084	2222
1084	945
1085	3560
1085	3655
1085	2362
1085	4815
1086	4035
1086	4744
1086	1319
1086	4770
1087	3560
1087	1560
1087	2367
1087	625
1088	199
1088	590
1088	855
1088	3627
1089	2769
1089	4308
1089	199
1089	1996
1090	2768
1090	3741
1090	404
1090	4364
1091	3246
1091	1454
1091	1560
1091	4900
1092	1359
1092	2270
1092	1557
1092	4787
1093	4753
1093	3033
1093	3768
1093	2189
1094	3065
1094	277
1094	2474
1094	2249
1095	2125
1095	3316
1095	4129
1095	570
1096	3293
1096	2551
1096	3676
1096	911
1097	573
1097	83
1097	3442
1097	738
1098	3077
1098	1383
1098	464
1098	779
1099	1107
1099	1048
1099	3756
1099	1151
1100	4093
1100	2771
1100	2470
1101	4475
1101	4691
1101	1550
1101	1391
1102	2530
1102	3155
1102	3615
1102	2057
1103	83
1103	2390
1103	3742
1103	3762
1104	4466
1104	189
1104	1251
1104	3600
1105	1199
1105	2959
1105	4796
1105	2032
1106	4320
1106	230
1106	3981
1106	2529
1107	3861
1107	3649
1107	3199
1107	721
1108	1268
1108	2755
1108	298
1108	1990
1109	3437
1109	944
1109	4011
1109	4609
1110	3437
1110	944
1110	805
1110	4609
1111	2551
1111	1118
1111	608
1111	4177
1112	854
1112	3366
1112	646
1112	768
1113	926
1113	1514
1113	1090
1113	508
1114	4603
1114	4208
1114	2804
1114	4241
1115	1572
1115	1113
1116	2784
1116	4060
1116	3773
1116	1335
1117	4465
1117	1671
1117	2342
1117	3172
1118	1924
1118	963
1118	2726
1118	2496
1119	1568
1119	2253
1119	2897
1119	4027
1121	3340
1121	1085
1121	1200
1121	4116
1122	3296
1122	1258
1122	3377
1122	14
1123	3313
1123	1046
1123	2498
1123	4431
1124	2388
1124	3300
1124	3105
1124	2516
1125	2346
1125	983
1125	261
1125	504
1126	179
1126	820
1126	316
1126	4294
1127	50
1127	4181
1127	802
1127	1136
1128	4029
1128	699
1128	4955
1128	2325
1129	3350
1129	1538
1129	266
1129	1533
1130	4177
1130	865
1130	1478
1130	3896
1131	16
1131	2315
1131	2461
1131	862
1132	3520
1132	1190
1132	1326
1132	1690
1133	3281
1133	3414
1133	2996
1133	3267
1134	401
1134	3082
1134	3413
1134	2211
1135	722
1135	2720
1135	891
1135	4484
1136	50
1136	2418
1136	1936
1136	445
1137	1234
1137	2561
1137	4081
1137	484
1138	3155
1138	4034
1138	501
1138	2286
1139	4296
1139	2835
1139	2621
1139	4280
1140	110
1140	4197
1140	2398
1140	3881
1141	2128
1141	357
1141	4745
1141	1402
1142	4340
1142	1551
1142	786
1142	792
1143	4241
1143	1422
1143	3040
1143	3429
1144	2321
1144	3086
1144	2877
1144	3534
1145	2551
1145	613
1145	4807
1145	868
1146	737
1146	934
1146	4458
1146	1203
1147	1268
1147	3979
1147	3895
1147	967
1148	1366
1148	2747
1148	3004
1148	775
1149	3340
1149	247
1149	3350
1149	3205
1150	1837
1150	4034
1150	232
1150	696
1151	3677
1151	4872
1151	2384
1151	4481
1152	2125
1152	3831
1152	3887
1152	1209
1153	1781
1153	4870
1153	2623
1153	1156
1154	2551
1154	2397
1154	1591
1154	3344
1155	4296
1155	2997
1155	2521
1155	4108
1156	4465
1156	934
1156	3804
1156	1663
1157	2686
1157	2833
1157	4014
1157	1760
1158	3800
1158	4170
1158	2176
1158	176
1159	2436
1159	775
1159	4235
1159	1084
1160	720
1160	2979
1160	4756
1160	3941
1161	779
1161	4160
1161	4606
1161	3296
1162	4259
1162	1232
1162	4680
1162	734
1163	294
1163	1987
1163	4768
1163	1991
1164	1113
1164	4181
1164	2681
1164	4902
1165	3058
1165	1319
1165	4866
1165	1035
1166	2482
1166	842
1166	2827
1166	2509
1167	3717
1167	4065
1167	4070
1167	696
1168	1366
1168	3424
1168	3909
1168	267
1169	294
1169	3804
1169	4376
1169	4009
1170	1753
1170	2682
1170	2484
1170	3036
1171	3246
1171	3577
1171	230
1171	2833
1172	2440
1172	4052
1172	1813
1172	4296
1173	573
1173	967
1173	163
1173	1991
1174	2436
1174	2802
1174	1469
1174	4035
1175	4612
1175	3838
1175	2250
1175	2444
1176	2179
1176	1645
1176	2302
1176	2413
1177	1048
1177	1445
1177	4125
1177	3185
1178	3618
1178	2550
1178	36
1178	3669
1179	796
1179	4090
1179	2944
1179	652
1180	3340
1180	2640
1180	969
1180	4981
1181	1268
1181	1972
1181	1991
1182	1753
1182	4888
1182	231
1182	1197
1183	573
1183	566
1183	4928
1183	805
1184	4290
1184	2506
1184	2140
1184	882
1185	267
1185	277
1185	668
1185	1149
1186	2875
1186	4263
1186	2589
1186	2491
1187	4659
1187	3891
1187	2302
1187	3973
1188	399
1188	3363
1188	108
1188	1469
1189	2125
1189	1165
1190	4523
1190	2388
1190	3385
1190	2076
1191	3996
1191	3096
1191	3247
1191	2791
1192	3293
1192	4641
1192	571
1192	197
1193	3293
1193	2290
1193	2007
1193	1681
1194	2173
1194	1884
1194	2463
1194	1387
1195	955
1195	3061
1195	4183
1195	1386
1196	2720
1196	1518
1196	1460
1196	3889
1197	50
1197	2449
1197	3363
1197	574
1198	1718
1198	3420
1198	1637
1198	79
1199	3313
1199	573
1199	1671
1199	1913
1200	3250
1200	70
1200	3316
1200	2151
1201	4874
1201	3236
1201	1232
1201	3254
1202	854
1202	2397
1202	3909
1202	1246
1203	294
1203	1999
1203	3276
1203	4248
1204	4659
1204	907
1204	3913
1204	2683
1205	4475
1205	3637
1205	1818
1205	4325
1206	3703
1206	2940
1206	2405
1206	1399
1207	2125
1207	1754
1207	1070
1207	2967
1208	1972
1208	3837
1208	4828
1208	2761
1209	1849
1209	3224
1209	2679
1209	3699
1210	2125
1210	1108
1210	3426
1210	3698
1211	3959
1211	2950
1211	513
1211	595
1212	3950
1212	1366
1212	4160
1212	1096
1213	1715
1213	1417
1213	752
1213	232
1214	1113
1214	2362
1214	1200
1214	1360
1215	2157
1215	2103
1215	2720
1215	3613
1216	460
1216	3780
1216	2284
1216	108
1217	4872
1217	1132
1217	951
1217	1103
1218	772
1218	720
1218	1786
1218	3724
1219	2906
1219	3400
1219	2680
1219	3301
1220	2436
1220	4035
1220	4709
1220	4903
1221	2039
1221	4890
1221	1200
1221	2280
1222	2796
1222	2100
1222	2089
1222	872
1223	2144
1223	1565
1223	2359
1223	2523
1224	4024
1224	3162
1224	4931
1224	4461
1225	4882
1225	759
1225	2163
1225	3334
1226	2654
1226	4269
1226	2103
1226	4634
1227	83
1227	267
1227	1339
1227	1748
1228	3477
1228	315
1228	650
1228	92
1229	2436
1229	1376
1229	469
1229	2647
1230	2551
1230	4503
1230	1258
1230	2154
1231	4465
1231	3853
1231	622
1231	3910
1232	394
1232	1877
1232	733
1232	112
1233	2346
1233	3288
1233	2686
1233	798
1234	4380
1234	510
1234	565
1234	1043
1236	3177
1236	3004
1236	776
1236	335
1237	3756
1237	4549
1237	1439
1237	4449
1238	3250
1238	3896
1238	760
1238	2219
1239	4856
1239	1727
1239	4290
1239	1176
1240	1232
1240	1230
1240	204
1240	3297
1241	4719
1241	1447
1241	265
1241	2726
1243	1658
1243	2558
1243	2973
1243	3660
1244	2702
1244	2543
1244	2300
1244	2892
1245	1113
1245	3876
1245	3449
1245	4144
1246	50
1246	763
1246	2020
1246	1538
1247	1113
1247	195
1247	3837
1247	3385
1248	4523
1248	1132
1248	291
1248	4014
1249	4666
1249	3288
1249	2656
1249	1687
1250	994
1250	1707
1250	2233
1250	1744
1251	2039
1251	4129
1251	819
1251	1334
1252	294
1252	969
1252	2683
1252	747
1253	2436
1253	2773
1253	3613
1253	573
1254	515
1254	4096
1254	1400
1254	3397
1255	50
1255	1940
1255	83
1255	53
1256	4678
1256	914
1256	1575
1256	2773
1257	4741
1257	2816
1257	1661
1257	1972
1258	4820
1258	4710
1258	4951
1258	2615
1259	803
1259	3979
1259	1957
1259	3088
1260	4029
1260	473
1260	2966
1260	728
1261	2175
1261	4440
1261	3674
1261	2843
1262	2188
1262	1578
1262	1793
1262	346
1263	4651
1263	478
1263	1928
1263	22
1264	1113
1264	2388
1264	1885
1264	2737
1265	2912
1265	1709
1265	3824
1265	928
1266	4229
1266	4285
1266	1258
1266	1107
1267	1341
1267	3276
1267	2853
1267	2776
1268	2669
1268	267
1268	1715
1269	2915
1269	1476
1269	866
1269	2819
1270	805
1270	1005
1270	2835
1270	4788
1271	2664
1271	41
1271	272
1271	1636
1272	50
1272	608
1272	1107
1272	2031
1273	4029
1273	4872
1273	1340
1273	2384
1274	4475
1274	2680
1274	4927
1274	1523
1275	3279
1275	270
1275	4038
1275	4967
1276	2093
1276	4139
1276	4876
1276	4273
1277	4093
1277	3093
1277	799
1277	3886
1278	1238
1278	2221
1278	4578
1279	2778
1279	2575
1279	2131
1279	2596
1280	2780
1280	110
1280	1396
1280	591
1281	4214
1281	108
1281	3228
1281	4335
1282	4666
1282	573
1282	3296
1282	2751
1283	4941
1283	1534
1283	4725
1283	4235
1284	4678
1284	2830
1284	69
1284	757
1285	4661
1285	2973
1285	2448
1285	4470
1286	294
1286	332
1286	694
1286	1441
1287	720
1287	650
1287	4756
1287	2453
1288	781
1288	3458
1288	975
1288	1864
1289	1268
1289	296
1289	1999
1289	2324
1290	113
1290	3720
1290	4407
1290	554
1291	294
1291	1981
1291	3762
1291	2835
1292	546
1292	2171
1292	4478
1292	3779
1293	491
1293	2384
1293	1100
1293	4235
1294	2397
1294	1560
1294	3882
1294	654
1295	294
1295	1677
1295	4939
1295	4716
1296	3454
1296	2966
1296	2065
1296	58
1297	4047
1297	934
1297	2051
1297	4376
1298	16
1298	799
1298	2562
1298	1473
1299	4523
1299	2796
1299	4579
1299	1948
1300	3823
1300	2936
1300	701
1300	2040
1301	756
1301	3567
1301	4090
1301	3522
1302	1085
1302	83
1302	2495
1302	239
1303	4475
1303	2667
1303	487
1303	533
1304	294
1304	550
1304	4248
1304	3707
1305	4241
1305	2739
1305	1035
1305	4128
1306	3
1306	466
1306	3899
1306	2650
1307	1366
1307	4241
1307	2459
1307	4616
1308	460
1308	2599
1308	2361
1308	2353
1309	3177
1309	722
1309	1200
1309	2101
1310	2653
1310	3417
1310	2782
1310	3218
1311	3293
1311	2283
1311	1858
1311	4452
1312	651
1312	4700
1312	2270
1312	1150
1313	2136
1313	2599
1313	706
1313	3964
1314	3250
1314	1113
1314	650
1314	3477
1315	3703
1315	2940
1315	2405
1315	1019
1316	4947
1316	395
1316	957
1316	939
1317	4523
1317	277
1317	2558
1317	160
1318	1142
1318	4520
1318	891
1318	2305
1319	931
1319	2212
1319	403
1319	1379
1320	3560
1320	1341
1320	2617
1320	1474
1321	3938
1321	4325
1321	1999
1321	1818
1322	1268
1322	2144
1322	2683
1322	4050
1323	4251
1323	1758
1323	1567
1323	3069
1324	1300
1324	1232
1324	1153
1324	3515
1325	4358
1325	4651
1325	2773
1325	819
1326	156
1326	2356
1326	32
1326	2770
1327	3201
1327	4887
1327	4744
1327	4561
1328	4523
1328	4872
1328	4251
1328	3570
1329	4571
1329	4570
1329	4731
1329	1716
1330	1107
1330	3288
1330	725
1330	962
1331	737
1331	2296
1331	948
1331	3971
1332	2855
1332	3165
1332	4025
1332	495
1333	2449
1333	153
1333	3828
1333	4507
1334	2436
1334	1238
1334	3315
1334	52
1335	1715
1335	267
1335	1976
1335	976
1336	6
1336	2639
1336	4814
1336	1365
1337	4887
1337	1572
1337	2463
1337	2960
1338	3727
1338	4804
1338	3416
1338	2482
1339	4666
1339	1113
1339	4083
1339	594
1340	4296
1340	3560
1340	1258
1340	2430
1341	2724
1341	685
1341	3994
1341	3841
1342	4603
1342	3730
1342	4
1342	2013
1343	1129
1343	3313
1343	2892
1343	4029
1344	2947
1344	1107
1344	3516
1344	1310
1345	4325
1345	1312
1345	2748
1345	1567
1346	722
1346	3855
1346	463
1347	1730
1347	2065
1347	4903
1347	2677
1348	464
1348	546
1348	3602
1348	436
1349	478
1349	4719
1349	2793
1349	2021
1350	3938
1350	4325
1350	1823
1350	2420
1351	469
1351	2458
1351	1929
1351	3334
1352	779
1352	3197
1352	2966
1352	3044
1353	4918
1353	4888
1353	2414
1353	1076
1354	2142
1354	1330
1354	993
1354	798
1355	3010
1355	4986
1355	2154
1355	1651
1356	1753
1356	231
1356	3666
1356	4292
1357	1417
1357	4010
1357	497
1357	1994
1358	4523
1358	550
1358	3910
1358	179
1359	114
1359	2079
1359	3892
1359	3386
1360	1085
1360	590
1360	291
1360	4815
1361	1113
1361	247
1361	573
1361	4709
1362	2664
1362	1151
1362	4536
1362	1885
1363	3564
1363	3250
1363	432
1363	1658
1364	2236
1364	3250
1364	2905
1364	1931
1365	2717
1365	793
1365	1439
1365	2698
1366	3414
1366	1592
1366	889
1366	4086
1367	2724
1367	4885
1367	2816
1367	4675
1368	4065
1368	1078
1368	993
1368	534
1369	3552
1369	432
1369	3950
1369	2972
1370	4651
1370	720
1370	881
1370	3114
1371	2551
1371	1113
1371	4229
1371	4889
1372	2031
1372	950
1372	4345
1372	4601
1373	294
1373	1534
1373	4092
1373	4745
1374	3185
1374	3189
1374	2449
1374	1353
1375	1979
1375	4664
1375	4655
1375	1854
1376	4587
1376	3755
1376	899
1376	3436
1377	1572
1377	1518
1377	4071
1377	3677
1378	1516
1378	149
1378	1393
1378	4474
1379	4523
1379	1200
1379	2324
1379	4392
1380	2543
1380	4225
1380	1441
1380	3982
1381	491
1381	671
1381	3328
1381	4015
1382	4753
1382	1321
1382	3855
1382	4755
1383	2640
1383	3560
1383	372
1383	662
1384	854
1384	3188
1384	1437
1384	3484
1385	720
1385	3549
1385	4344
1385	3869
1386	177
1386	2751
1386	1411
1386	2026
1387	934
1387	4666
1387	802
1387	1768
1388	775
1388	2193
1388	962
1388	2133
1389	610
1389	2653
1389	4690
1389	536
1390	1501
1390	2041
1390	1905
1391	2796
1391	4412
1391	4454
1391	3777
1392	4200
1392	3303
1392	2214
1392	746
1393	1322
1393	3644
1393	543
1393	2080
1394	4613
1394	2786
1394	4401
1394	971
1395	3426
1395	2749
1395	3114
1395	1029
1396	3655
1396	4036
1396	904
1396	2835
1397	1981
1397	3013
1397	3857
1397	3399
1398	774
1398	2397
1398	3455
1398	3569
1399	2313
1399	3736
1399	4781
1399	845
1400	4300
1400	4035
1400	3121
1400	3868
1401	1987
1401	3084
1401	4575
1401	2744
1402	4363
1402	576
1402	2569
1402	2411
1403	4036
1403	4732
1403	2695
1403	4106
1404	1381
1404	1344
1404	2904
1404	2332
1405	2125
1405	1071
1405	4809
1405	89
1406	3677
1406	2681
1406	4222
1406	397
1407	1927
1407	1268
1407	694
1407	724
1408	4465
1408	3328
1408	1663
1408	276
1409	3350
1409	4300
1409	1182
1409	2333
1410	1773
1410	2078
1410	4910
1410	1748
1411	1238
1411	4325
1411	4241
1411	3767
1412	1856
1412	1987
1412	2133
1412	591
1413	4300
1413	3552
1413	2173
1413	3831
1414	3291
1415	4872
1415	4948
1415	4161
1415	4740
1416	955
1416	519
1416	124
1416	2772
1417	1876
1417	1025
1417	1465
1417	4502
1418	2143
1418	3823
1418	2185
1418	332
1419	4093
1419	4625
1419	3641
1419	1471
1420	204
1420	3075
1420	2083
1420	2056
1421	3185
1421	3250
1421	574
1421	3742
1422	720
1422	1366
1422	2904
1422	2672
1423	4475
1423	380
1423	2672
1423	4686
1424	575
1424	122
1424	3758
1424	281
1425	1866
1425	2519
1425	4765
1425	1515
1426	4076
1426	3216
1426	3338
1426	204
1427	4280
1428	2793
1428	1200
1428	3736
1428	4186
1429	2724
1429	4094
1429	3717
1429	2426
1430	4469
1430	995
1430	446
1430	1497
1431	603
1431	220
1431	4177
1431	774
1432	1710
1432	4024
1432	1000
1432	447
1433	1715
1433	2365
1433	2395
1433	2133
1434	1880
1434	600
1434	4269
1434	4672
1435	2455
1435	4806
1435	4123
1435	3679
1436	1417
1436	4960
1436	3897
1436	243
1437	3245
1437	1300
1437	2437
1437	1701
1438	463
1438	546
1438	469
1438	526
1439	2062
1439	2138
1439	935
1439	3086
1440	360
1440	4065
1440	2031
1440	511
1441	4352
1441	4704
1441	2766
1441	3143
1442	431
1442	2261
1442	4789
1442	4871
1443	2028
1443	3924
1443	3775
1443	1740
1444	938
1444	3167
1444	4950
1444	918
1445	449
1445	2162
1445	53
1445	4632
1446	3293
1446	1658
1446	55
1446	3723
1447	360
1447	3084
1447	152
1447	3528
1448	4806
1448	239
1448	2287
1448	1008
1449	2384
1449	29
1449	3454
1449	2168
1450	3146
1450	435
1450	2831
1450	1052
1451	431
1451	3612
1451	38
1451	2492
1452	3340
1452	2640
1452	969
1452	4405
1453	3655
1453	1534
1453	2474
1453	3540
1454	4093
1454	3809
1454	487
1454	3767
1455	1520
1455	3844
1455	3253
1455	3727
1456	3796
1456	4350
1456	3306
1456	1951
1457	1766
1457	2532
1457	2839
1457	3073
1458	3293
1458	2039
1458	1319
1458	1911
1459	1174
1459	4877
1459	1865
1459	534
1460	2828
1460	1247
1460	1400
1460	4616
1461	2039
1461	2947
1461	3166
1461	1746
1462	1233
1462	2540
1462	2609
1462	3144
1463	3205
1463	3353
1463	2384
1463	920
1464	4856
1464	247
1464	1773
1464	399
1465	1693
1465	3927
1465	2878
1465	2022
1466	1800
1466	2654
1466	2152
1466	3465
1467	1981
1467	3295
1467	2740
1467	1260
1468	4633
1468	154
1468	3385
1469	172
1469	4542
1469	4036
1469	761
1470	854
1470	1917
1470	2963
1470	2031
1471	4691
1471	239
1471	1542
1471	1176
1472	796
1472	2866
1472	358
1472	3431
1473	53
1473	3195
1473	3928
1473	299
1474	731
1474	3073
1474	2533
1474	2929
1475	3803
1475	2900
1475	3807
1475	3178
1476	2303
1476	3861
1476	3155
1476	3462
1477	3818
1477	4003
1477	3188
1477	4622
1478	4575
1478	2898
1478	3035
1478	373
1479	2724
1479	2683
1479	2333
1479	2154
1480	1946
1480	802
1480	2026
1480	3414
1481	3293
1481	2796
1481	1928
1481	3414
1482	1372
1482	4024
1482	2294
1482	3360
1483	4691
1483	315
1483	568
1483	230
1484	1733
1484	4539
1484	2946
1484	2019
1485	4625
1485	1699
1485	1518
1485	4874
1486	4290
1486	523
1486	3734
1486	3290
1487	4465
1487	1671
1487	946
1487	2569
1488	3714
1488	4550
1488	455
1488	3652
1489	1946
1489	969
1489	291
1489	1928
1490	1268
1490	2814
1490	4346
1490	2296
1491	4181
1491	959
1491	1964
1491	93
1492	2125
1492	4142
1492	2748
1492	4564
1493	1366
1493	2518
1493	2814
1493	1792
1494	4069
1494	774
1494	1504
1494	349
1495	3560
1495	897
1495	2815
1496	2480
1496	195
1496	2213
1496	3253
1497	4383
1497	4184
1497	192
1497	1191
1498	4029
1498	4748
1498	460
1498	1005
1499	4034
1499	1624
1499	267
1499	934
1500	955
1500	3414
1500	4941
1500	106
1501	3328
1501	995
1502	699
1502	501
1502	3546
1502	790
1503	432
1503	4264
1503	2652
1503	3617
1504	4947
1504	1129
1504	2199
1504	52
1505	2136
1505	1913
1505	4161
1505	4669
1506	267
1506	1078
1506	2444
1506	2554
1507	2100
1507	1405
1507	4254
1507	1404
1508	185
1508	3288
1508	1341
1508	4640
1509	4874
1509	3879
1509	4640
1509	2262
1510	4666
1510	4340
1510	98
1510	3266
1511	267
1511	546
1511	3250
1511	2346
1512	2892
1512	2997
1512	2014
1512	3177
1513	978
1513	956
1513	804
1513	1079
1514	2771
1514	1340
1514	133
1514	1092
1515	3564
1515	4225
1515	478
1515	4099
1516	1856
1516	2787
1516	1378
1516	3767
1517	1534
1517	1118
1517	3429
1517	546
1518	4218
1518	107
1518	1266
1518	4243
1519	3924
1519	1333
1519	1246
1519	1928
1520	1696
1520	3468
1520	1236
1520	4671
1521	305
1521	1052
1521	2018
1521	2628
1522	1238
1522	2839
1522	4172
1522	4896
1523	473
1523	1078
1523	2300
1523	915
1524	1085
1524	1559
1524	4035
1524	2965
1525	2136
1525	637
1525	2426
1525	4289
1526	4753
1526	2798
1526	2725
1526	1504
1527	4296
1527	3762
1527	1479
1527	2024
1528	3177
1528	3896
1528	4918
1528	150
1529	4669
1529	1085
1529	2084
1529	2728
1530	720
1530	2945
1530	3984
1530	4316
1531	4296
1531	1238
1531	3250
1531	4143
1532	1232
1532	2031
1532	63
1532	2708
1533	1518
1533	2307
1533	4877
1534	3614
1534	2932
1534	1363
1534	2246
1535	1572
1535	3477
1535	4603
1535	3470
1536	3256
1536	3536
1536	1246
1536	3602
1537	3511
1537	315
1537	4481
1537	2262
1538	270
1538	4775
1538	3289
1538	4050
1539	662
1539	770
1539	94
1539	507
1540	3340
1540	4753
1540	4685
1540	2377
1541	1364
1541	1322
1541	4634
1541	2021
1542	523
1542	2905
1542	4600
1542	2342
1543	3375
1543	3498
1543	1382
1543	495
1544	4625
1544	1635
1544	69
1544	1046
1545	1587
1545	4633
1545	4137
1545	4300
1546	4465
1546	2929
1546	4801
1546	3064
1547	4691
1547	402
1547	872
1547	2908
1548	4358
1548	4100
1548	4858
1548	2851
1549	1884
1549	772
1549	3540
1549	4687
1550	2507
1550	4433
1550	2815
1550	104
1551	3777
1551	483
1551	305
1551	4962
1552	955
1552	2577
1552	2870
1552	1117
1553	854
1553	1725
1553	3461
1553	1044
1554	854
1554	4739
1554	1763
1554	511
1555	854
1555	4387
1555	3648
1555	511
1556	854
1556	3657
1556	2915
1556	1432
1557	260
1557	3324
1557	1176
1557	3339
1558	3146
1558	4662
1558	1436
1558	4393
1559	2426
1559	4719
1559	440
1559	252
1560	2142
1560	4651
1560	3205
1560	4222
1561	3276
1561	1258
1561	500
1561	143
1562	3560
1562	546
1562	4161
1562	4864
1563	16
1563	2647
1563	1445
1563	1821
1564	805
1564	1819
1564	4299
1564	2194
1565	2463
1565	590
1565	3527
1565	4137
1566	3991
1566	4629
1566	1813
1566	4505
1567	589
1567	1061
1567	2120
1567	1963
1568	720
1568	3340
1568	3205
1568	993
1569	1753
1569	434
1569	1378
1569	1155
1570	2047
1570	2459
1570	3809
1570	1245
1571	1113
1571	3288
1571	3004
1571	3366
1572	1100
1572	1064
1572	4438
1572	1613
1573	720
1573	2793
1573	4098
1573	1817
1574	1238
1574	1565
1574	185
1574	2262
1575	2702
1575	1116
1575	532
1575	2012
1576	1572
1576	1458
1576	411
1576	3812
1577	854
1577	1519
1577	1022
1577	4857
1578	76
1578	1136
1578	1298
1578	1691
1579	686
1579	1373
1579	2848
1579	1683
1580	460
1580	1565
1580	3869
1580	2098
1581	4503
1581	4691
1581	3236
1581	268
1582	1107
1582	469
1582	2096
1582	3680
1583	854
1583	3674
1583	1949
1583	4085
1584	4290
1584	4875
1584	2671
1584	172
1585	1671
1585	1306
1585	291
1585	4081
1586	4907
1586	2851
1586	2477
1586	4039
1587	4225
1587	4163
1587	1181
1587	2964
1588	1454
1588	4907
1588	3775
1588	4035
1589	3996
1589	1344
1589	4808
1589	4465
1590	3350
1590	2147
1590	1975
1590	738
1591	1671
1591	2796
1591	1297
1591	2635
1592	2976
1592	3400
1592	1809
1592	2307
1593	3111
1593	2711
1593	4027
1593	1228
1594	4296
1594	324
1594	4070
1594	3961
1595	831
1595	1665
1595	4904
1595	1820
1596	3796
1596	840
1596	3509
1596	2112
1597	3400
1597	3967
1597	2181
1597	4147
1598	2362
1598	3793
1598	2373
1598	612
1599	2728
1599	2262
1599	4678
1599	3246
1600	4710
1600	2685
1600	4917
1600	462
1601	3087
1601	969
1601	1360
1601	3916
1602	266
1602	2072
1602	245
1602	1855
1603	4363
1603	2174
1603	3879
1603	1572
1604	1991
1604	3279
1604	2015
1604	1051
1605	1703
1605	4142
1605	4776
1605	4689
1606	2611
1606	4544
1606	4366
1606	3258
1607	3314
1607	2142
1607	967
1607	1910
1608	267
1608	2256
1608	1928
1608	3724
1609	3950
1609	1366
1609	3061
1609	40
1610	4214
1610	1159
1610	4350
1610	2551
1611	1200
1611	2627
1611	4442
1611	791
1612	4470
1612	3727
1612	2858
1612	2218
1613	2682
1613	2290
1613	416
1613	2881
1614	1798
1614	2687
1614	4425
1614	2403
1615	838
1615	527
1615	3840
1615	1107
1616	1088
1616	2543
1616	2739
1616	1668
1617	4616
1617	2721
1617	2178
1617	471
1618	2136
1618	3414
1618	384
1618	1349
1619	3552
1619	2551
1619	4277
1619	2020
1620	1567
1620	2564
1620	2320
1620	581
1621	460
1621	1749
1621	4858
1621	3635
1622	3950
1622	969
1622	349
1622	2396
1623	4718
1623	2727
1623	2481
1623	4979
1624	4666
1624	923
1624	2995
1624	696
1625	1403
1625	3612
1625	378
1625	831
1626	2125
1626	3649
1626	980
1626	1540
1627	1693
1627	1037
1627	272
1627	4418
1628	2780
1628	805
1628	2373
1628	1916
1629	3426
1629	1454
1629	112
1629	1945
1630	2938
1630	3286
1630	1653
1630	3208
1631	4874
1631	4435
1631	2444
1631	2474
1632	4872
1632	1885
1632	131
1632	769
1633	3291
1633	3210
1633	1166
1633	4354
1634	2709
1634	4131
1634	4019
1634	1840
1635	3937
1635	2560
1635	3946
1635	279
1636	3552
1636	3296
1636	728
1636	3363
1637	3340
1637	1658
1637	231
1637	1345
1638	294
1638	3857
1638	936
1638	4779
1639	4093
1639	1572
1639	3521
1639	1138
1640	3201
1640	3042
1640	3782
1640	994
1641	796
1641	163
1641	3863
1642	16
1642	1232
1642	786
1642	127
1643	4029
1643	4093
1643	2571
1643	4192
1644	590
1644	4214
1644	2210
1644	3434
1645	4465
1645	501
1645	3826
1645	4684
1646	2436
1646	2604
1646	372
1646	2488
1647	2188
1647	2577
1647	3455
1647	4178
1648	1866
1648	1295
1648	2831
1648	2954
1649	16
1649	990
1649	547
1649	513
1650	3426
1650	2390
1650	285
1650	2889
1651	3849
1651	4826
1651	1801
1651	2774
1652	1946
1652	2221
1652	2343
1652	3361
1653	1107
1653	1340
1653	3527
1653	2362
1654	4947
1654	3314
1654	2331
1654	3670
1655	4013
1655	2763
1655	727
1655	4321
1656	3328
1656	199
1656	3498
1656	2673
1657	4065
1657	3314
1657	566
1657	2601
1658	3013
1658	2088
1658	4628
1658	2818
1659	589
1659	2769
1659	696
1659	106
1660	1238
1660	1454
1660	741
1660	3195
1661	2244
1661	1148
1661	1391
1661	860
1662	2449
1662	2205
1662	1454
1662	2924
1663	3936
1663	854
1663	3233
1663	3681
1664	4350
1664	1078
1664	1946
1664	969
1665	4888
1665	1773
1665	349
1665	1003
1666	3959
1666	185
1666	2842
1666	3506
1667	50
1667	2346
1667	546
1667	967
1668	3979
1668	2335
1668	2988
1668	4435
1669	1268
1669	4089
1669	1727
1669	996
1670	546
1670	613
1670	2802
1670	4334
1671	4314
1671	1280
1671	2276
1671	1978
1672	843
1672	1577
1672	3291
1672	3062
1673	573
1673	4264
1673	1096
1673	4679
1674	2142
1674	226
1674	946
1674	4585
1675	1085
1675	3323
1675	2594
1675	3779
1676	3185
1676	4720
1676	1857
1676	3921
1677	229
1677	3891
1677	3249
1677	1400
1678	1753
1678	534
1678	3874
1678	500
1679	1773
1679	608
1679	478
1679	898
1680	4874
1680	1138
1680	1317
1680	4617
1681	324
1681	3914
1681	4419
1681	4880
1682	3507
1682	3776
1682	2861
1682	2344
1684	2428
1684	2999
1684	4329
1684	970
1685	1383
1685	4015
1685	612
1685	2072
1686	2254
1686	901
1686	1789
1686	3605
1687	4065
1687	2053
1687	4761
1687	4936
1688	3313
1688	4153
1688	1255
1688	2939
1689	3996
1689	3096
1689	4057
1689	960
1690	3195
1690	4529
1690	2492
1690	4556
1691	2613
1691	3464
1691	223
1691	3280
1692	2240
1692	1497
1692	2207
1692	3963
1693	731
1693	4222
1693	1387
1693	1411
1694	94
1694	2181
1694	1629
1694	782
1695	230
1695	2551
1695	2924
1695	4807
1696	2823
1696	1977
1696	3573
1696	3559
1697	1587
1697	2610
1697	4450
1697	3391
1698	324
1698	53
1698	3941
1698	1304
1699	3823
1699	4933
1699	3829
1699	1878
1700	2300
1700	2815
1700	2302
1700	537
1701	1129
1701	4229
1701	1749
1701	2788
1702	1280
1702	2353
1702	3445
1702	3444
1703	1578
1703	3340
1703	1325
1703	4005
1704	2747
1704	3896
1704	4943
1704	143
1705	726
1705	275
1705	4140
1705	3706
1706	589
1706	3794
1706	1532
1706	1087
1707	2625
1707	1829
1707	175
1707	3073
1708	4075
1708	3181
1708	1265
1708	4041
1709	3073
1709	1806
1709	1086
1709	2557
1710	4659
1710	3564
1710	4598
1710	4063
1711	1174
1711	4877
1711	888
1711	1865
1712	590
1712	4113
1712	1450
1712	1061
1713	4666
1713	1565
1713	3065
1713	2994
1714	4197
1714	4557
1714	3062
1714	2368
1715	3255
1715	3560
1715	2366
1715	4255
1716	1079
1716	3672
1716	1094
1716	804
1717	2142
1717	3296
1717	1585
1717	2859
1718	4947
1718	3024
1718	628
1718	3523
1719	3239
1719	4960
1719	3566
1719	4454
1720	1856
1720	1572
1720	4264
1720	1035
1721	4093
1721	3215
1721	1658
1721	2388
1722	4011
1722	2290
1722	3713
1722	384
1723	1246
1723	4409
1723	2337
1723	4908
1724	2456
1724	1480
1724	3204
1724	4572
1725	3570
1725	1800
1725	1880
1725	4178
1726	3604
1726	217
1726	4109
1726	1358
1727	506
1727	1906
1727	485
1727	3869
1728	4402
1728	1456
1728	1757
1728	1178
1729	4093
1729	4339
1729	3882
1729	3694
1730	805
1730	557
1730	4680
1730	3205
1731	4947
1731	725
1731	2220
1731	3138
1732	2144
1732	4408
1732	629
1732	3414
1733	2557
1733	2995
1733	3952
1733	3234
1734	3950
1734	1837
1734	2362
1734	324
1735	4465
1735	1268
1735	1784
1736	1232
1736	1000
1736	3394
1736	3466
1737	1940
1737	4849
1737	2351
1737	1822
1738	1240
1738	2451
1738	3526
1738	2785
1739	1289
1739	3435
1739	608
1739	2157
1740	1753
1740	247
1740	3348
1740	4421
1741	4439
1741	2530
1741	4770
1741	2167
1742	2359
1742	1476
1742	936
1742	3054
1743	3328
1743	1200
1743	4035
1743	2181
1744	3254
1744	2155
1744	4948
1744	4220
1745	1582
1745	1447
1745	4559
1745	3780
1746	756
1746	1045
1746	534
1746	484
1747	2346
1747	1138
1747	2179
1748	3350
1748	2031
1748	4441
1749	2440
1749	1740
1749	1357
1749	3894
1750	1469
1750	3455
1750	4446
1750	26
1751	3793
1751	2015
1751	908
1751	1317
1752	73
1752	1591
1753	803
1753	1572
1753	1957
1754	1565
1754	4241
1754	4973
1755	4700
1755	4358
1755	4594
1755	707
1756	4029
1756	2188
1756	3880
1756	40
1757	737
1757	440
1757	947
1757	2092
1758	737
1758	440
1758	3869
1758	1416
1759	726
1759	1285
1759	1813
1759	1991
1760	481
1760	1678
1760	1502
1760	677
1761	589
1761	3474
1761	1068
1761	1204
1762	3884
1762	2930
1762	3422
1762	102
1763	2816
1763	2672
1763	772
1763	1521
1764	1787
1764	4797
1764	777
1764	780
1765	4947
1765	3454
1765	1806
1765	1441
1766	2437
1766	4012
1766	3860
1766	3723
1767	4918
1767	2753
1767	1096
1767	533
1768	729
1768	4689
1768	4483
1768	1273
1769	651
1769	2263
1769	4379
1769	3568
1770	1755
1770	3328
1770	4720
1770	908
1771	1107
1771	4941
1771	2350
1771	4448
1772	1856
1772	2558
1772	4648
1772	2262
1773	3402
1773	1222
1773	542
1773	2021
1774	661
1774	1879
1774	2354
1774	4972
1775	1987
1775	2370
1775	3259
1775	2327
1776	4947
1776	2070
1776	3090
1776	1969
1777	1024
1777	1232
1777	1519
1777	1786
1778	2702
1778	1376
1778	1116
1778	185
1779	464
1779	671
1779	4982
1779	3728
1780	904
1780	3296
1780	1690
1780	1072
1781	2728
1781	4285
1781	2724
1781	971
1782	934
1782	3527
1782	2328
1782	797
1783	1940
1783	4849
1783	217
1783	586
1784	2290
1784	1138
1784	13
1784	1758
1785	3465
1785	2453
1785	177
1785	1760
1786	1987
1786	4733
1786	4936
1786	1981
1787	3572
1787	3542
1787	1800
1787	732
1788	4665
1788	3439
1788	1999
1788	3675
1789	822
1789	3146
1789	3474
1789	4591
1790	3293
1790	4363
1790	2939
1790	3367
1791	4910
1791	482
1791	486
1791	700
1792	4948
1792	3869
1792	4767
1792	460
1793	2099
1793	460
1793	3610
1793	4313
1794	1865
1794	2223
1794	1495
1794	1334
1795	2729
1795	949
1795	2820
1795	2765
1796	523
1796	2510
1796	202
1796	4312
1797	1366
1797	4011
1797	1085
1797	2529
1798	1577
1798	2227
1798	3979
1798	3674
1799	4947
1799	1129
1799	2327
1799	3222
1800	4947
1800	3200
1800	204
1800	2279
1801	3752
1801	3311
1801	4636
1801	3350
1802	2728
1802	4363
1802	1491
1803	589
1803	3550
1803	1426
1803	4712
1804	53
1804	1489
1804	1081
1804	3668
1805	2007
1805	2266
1805	4844
1805	1768
1806	1940
1806	4700
1806	3513
1806	3774
1807	4402
1807	3451
1807	4354
1807	1273
1808	4296
1808	1200
1808	2899
1808	71
1809	4465
1809	993
1809	3997
1809	4339
1810	3521
1810	4882
1810	3250
1810	4748
1811	2933
1811	3936
1811	3022
1811	3276
1812	1587
1812	1257
1812	507
1812	2095
1813	854
1813	4568
1813	1186
1813	649
1814	3717
1814	4483
1814	3370
1814	2180
1815	4465
1815	2640
1815	1051
1815	3688
1816	2640
1816	4231
1816	3999
1816	3253
1817	3717
1817	2223
1817	573
1817	3296
1818	1268
1818	3552
1818	551
1818	2740
1819	4093
1819	3344
1819	2262
1819	4094
1820	4976
1820	2720
1820	2642
1820	1890
1821	1587
1821	949
1821	856
1821	1970
1822	1680
1822	3762
1822	729
1822	4689
1823	4947
1823	1129
1823	4708
1823	2203
1824	2440
1824	3262
1824	398
1824	830
1825	2924
1825	2915
1825	668
1825	3633
1826	4074
1826	1068
1826	2878
1826	3798
1827	523
1827	113
1827	805
1827	4381
1828	3936
1828	2951
1828	2856
1828	1755
1829	2436
1829	3498
1829	2388
1829	1097
1830	3170
1830	3293
1830	456
1830	1628
1831	2835
1831	4199
1831	4714
1831	870
1832	2196
1832	90
1832	3034
1832	2410
1833	4017
1833	3318
1833	196
1833	3122
1834	1719
1834	234
1834	4810
1834	1971
1835	2039
1835	2509
1836	4947
1836	1129
1836	1615
1836	1487
1837	2125
1837	1196
1837	2697
1837	498
1838	2053
1838	2855
1838	3329
1838	1239
1839	2440
1839	2028
1839	4775
1839	2855
1840	749
1840	3454
1840	3385
1840	2712
1841	4910
1841	3874
1841	4388
1841	2520
1842	324
1842	1813
1842	3292
1842	4825
1843	854
1843	1578
1843	936
1843	119
1844	1147
1844	4213
1844	2955
1844	1630
1845	1610
1845	355
1845	3207
1845	3347
1846	4625
1846	3288
1846	4849
1846	3008
1847	4029
1847	805
1847	2426
1847	3313
1848	2915
1848	2221
1848	2373
1848	4626
1849	4207
1849	4159
1849	955
1849	1675
1850	2028
1850	2504
1850	3739
1850	695
1851	1859
1851	2702
1851	4439
1851	136
1852	3768
1852	183
1852	797
1852	3182
1853	770
1853	4921
1853	141
1853	4102
1854	1387
1854	3236
1854	3861
1854	4700
1855	699
1855	501
1855	1060
1855	3546
1856	4691
1856	4872
1856	4034
1856	2302
1857	4860
1857	2157
1857	2694
1857	3168
1858	269
1858	2680
1858	1889
1858	463
1859	2631
1859	1813
1859	2053
1859	1225
1860	3350
1860	2574
1860	361
1860	4948
1861	3350
1861	2009
1861	4508
1861	2204
1862	3477
1862	3570
1862	267
1862	1156
1863	3373
1863	1764
1863	2383
1863	3275
1864	973
1864	1668
1864	378
1864	194
1865	3796
1865	802
1865	1823
1865	667
1866	870
1866	1192
1866	1620
1866	641
1867	4465
1867	1129
1867	1607
1867	2764
1868	4296
1868	3166
1868	3288
1868	1951
1869	3061
1869	3231
1869	163
1869	1232
1870	1294
1870	779
1870	424
1870	3169
1871	3293
1871	4034
1871	3506
1871	1030
1872	4941
1872	232
1872	1341
1872	2627
1873	4465
1873	1129
1873	3206
1873	2764
1874	1107
1874	3013
1874	551
1874	3972
1875	3717
1875	4659
1875	3217
1875	1802
1876	27
1876	2185
1876	2813
1876	463
1877	2812
1877	940
1877	664
1877	341
1878	2463
1878	1385
1878	3891
1878	2800
1879	1981
1879	117
1879	2681
1879	2359
1880	969
1880	473
1880	2753
1880	241
1881	648
1881	2853
1881	1813
1881	642
1882	1106
1882	86
1882	2265
1882	4760
1883	2240
1883	1497
1883	995
1883	4469
1884	854
1884	4776
1884	3133
1884	3461
1885	3545
1885	57
1885	4399
1885	266
1886	4267
1886	194
1886	1051
1886	4737
1887	4350
1887	854
1887	3085
1887	80
1888	2647
1888	2171
1888	2546
1888	802
1889	2179
1889	507
1889	2634
1889	3554
1890	737
1890	934
1890	2335
1890	1085
1891	4625
1891	2171
1891	3717
1891	696
1892	1350
1892	1985
1892	521
1892	4231
1893	3494
1893	2868
1893	1738
1893	1308
1894	2342
1894	3745
1894	1848
1894	2464
1895	1704
1895	740
1895	1751
1895	125
1896	4858
1896	1918
1896	4081
1896	1639
1897	4065
1897	4883
1897	1082
1897	2505
1898	2858
1898	3831
1898	3531
1898	3613
1899	1003
1899	4657
1899	4203
1899	4536
1900	373
1900	843
1900	1059
1900	4800
1901	4467
1901	3776
1901	1489
1901	3242
1902	4861
1902	4798
1902	3382
1902	1002
1903	4065
1903	1454
1903	850
1903	3276
1904	1366
1904	2747
1904	3004
1904	720
1905	2796
1905	4753
1905	4222
1905	463
1906	2702
1906	1376
1906	3934
1906	2664
1907	4666
1907	644
1907	887
1907	566
1908	3245
1908	969
1908	971
1908	816
1909	4659
1909	3316
1909	4616
1909	1001
1910	737
1910	4105
1910	4563
1910	3371
1911	805
1911	1318
1911	4820
1911	1387
1912	2436
1912	2773
1912	1016
1912	4533
1913	796
1913	2797
1913	3000
1913	851
1914	2641
1914	3907
1914	4777
1914	1395
1915	726
1915	1295
1915	2862
1915	807
1916	1238
1916	3313
1916	2048
1916	2591
1917	4325
1917	1572
1917	4181
1917	2892
1918	2906
1918	3291
1918	158
1918	3787
1919	267
1919	907
1919	1200
1919	3260
1920	4459
1920	580
1920	1018
1920	3398
1921	934
1921	2749
1921	2459
1921	138
1922	4874
1922	4562
1922	3540
1922	4887
1923	2664
1923	3477
1923	3854
1923	1518
1924	4849
1924	3240
1924	2271
1924	798
1925	775
1925	4551
1925	4438
1925	1488
1926	1773
1926	4788
1926	1506
1926	4087
1927	2342
1927	2039
1927	2728
1928	50
1928	1340
1928	2362
1928	3385
1929	969
1929	432
1929	2531
1929	1803
1930	4678
1930	4459
1930	4562
1930	3506
1931	1719
1931	163
1931	386
1931	1689
1932	1268
1932	190
1933	4093
1933	907
1933	229
1933	3276
1934	2724
1934	1107
1934	1572
1934	997
1935	2173
1936	4856
1936	2565
1936	2015
1936	1243
1937	74
1937	3313
1937	4005
1937	2851
1938	4034
1938	699
1938	2802
1938	1321
1939	573
1939	3414
1939	4013
1939	869
1940	2777
1940	1417
1940	4313
1940	4500
1941	875
1941	4206
1941	2583
1941	2376
1942	1658
1942	2136
1942	3767
1942	2813
1943	4186
1943	2373
1943	901
1943	1100
1944	1232
1944	666
1944	3042
1944	1975
1945	3796
1945	1823
1945	2899
1945	588
1946	3356
1946	4035
1946	1658
1946	3155
1947	4666
1947	4558
1947	28
1947	1594
1948	3400
1948	1454
1948	3604
1948	3938
1949	4753
1949	1681
1949	1518
1949	4229
1950	2929
1950	699
1950	3527
1951	3734
1951	184
1951	2994
1951	996
1952	2798
1952	3368
1952	836
1952	821
1953	2423
1953	4808
1953	139
1953	2306
1954	573
1954	76
1954	3552
1954	349
1955	2702
1955	1360
1955	4034
1955	993
1956	4735
1956	4626
1956	4590
1956	697
1957	469
1957	2423
1957	4035
1957	1242
1958	4093
1958	473
1958	2547
1958	3507
1959	1693
1959	2121
1959	648
1959	726
1960	3313
1960	2796
1960	731
1960	901
1961	3552
1961	1258
1961	1572
1961	2278
1962	4358
1962	4010
1962	3965
1962	638
1963	1113
1963	2728
1963	3743
1963	2622
1964	1987
1964	3560
1964	4264
1965	1856
1965	4549
1965	4225
1965	1339
1966	608
1966	4121
1966	230
1966	2473
1967	267
1967	2221
1967	2475
1967	3257
1968	2670
1968	3831
1968	1518
1968	1507
1969	1940
1969	2579
1969	858
1969	1286
1970	3291
1970	3062
1970	860
1970	1774
1971	3313
1971	2188
1972	3186
1972	1045
1972	3253
1972	4005
1973	4565
1973	620
1973	4971
1973	368
1974	4651
1974	1658
1974	2144
1974	4910
1975	3328
1975	399
1975	2151
1975	3052
1976	2440
1976	2831
1976	4122
1976	2028
1977	2346
1977	469
1977	658
1977	195
1978	2769
1978	2338
1978	646
1978	696
1979	2561
1979	2007
1979	4062
1980	1238
1980	2628
1980	2397
1980	4441
1981	4872
1981	3507
1981	2798
1981	3453
1982	1211
1982	3914
1982	2358
1982	3492
1983	1753
1983	2787
1983	712
1983	501
1984	731
1984	1107
1984	2915
1984	2396
1985	4910
1985	74
1985	1837
1985	4063
1986	3823
1986	4129
1986	394
1986	2962
1987	3340
1987	1725
1987	4955
1987	4324
1988	3633
1988	720
1988	3477
1988	1560
1989	4438
1989	1878
1989	1549
1989	764
1990	2976
1990	4029
1990	2956
1990	375
1991	4962
1991	4040
1991	2556
1991	4858
1992	1238
1992	3564
1992	2989
1992	573
1993	3796
1993	2120
1993	4905
1993	1026
1994	3255
1994	1387
1994	4555
1994	920
1995	524
1995	3788
1995	4701
1995	3765
1996	2664
1996	608
1996	4807
1996	1084
1997	2640
1997	1107
1997	1464
1997	4422
1998	3230
1998	4299
1998	2813
1998	2144
1999	729
1999	4689
1999	1737
1999	632
2000	50
2000	1200
2000	3507
2000	1122
2001	590
2001	1958
2001	2210
2001	1166
2002	857
2002	3553
2002	3541
2002	101
2003	3961
2003	725
2003	4886
2003	484
2004	651
2004	1211
2004	1639
2004	325
2005	432
2005	2929
2006	2720
2006	1332
2006	83
2006	4935
2007	808
2007	3013
2007	3305
2007	4886
2008	1100
2008	2747
2008	630
2008	3694
2009	2287
2009	2973
2009	2162
2009	472
2010	4947
2010	3314
2010	3547
2010	902
2011	808
2011	4394
2011	4479
2011	406
2012	1552
2012	589
2012	1091
2012	680
2013	4465
2013	1078
2013	2985
2013	2915
2014	720
2014	3323
2014	2284
2014	3997
2015	4441
2015	2171
2015	591
2015	3771
2016	4186
2016	2171
2016	4653
2016	1950
2017	3350
2017	2769
2017	3506
2017	3611
2018	3426
2018	805
2018	2460
2018	1076
2019	1891
2019	3562
2019	4627
2019	1371
2020	120
2020	4552
2020	861
2020	4938
2021	4487
2021	1282
2021	4956
2021	2517
2022	1309
2022	1031
2022	319
2022	3664
2023	3542
2023	3608
2023	1237
2023	2899
2024	691
2024	1569
2024	2962
2024	181
2025	1113
2025	4404
2025	4872
2025	1635
2026	2261
2026	3586
2026	4141
2026	2263
2027	2302
2027	4838
2027	1327
2027	3332
2028	135
2028	3205
2028	4125
2028	4552
2029	1340
2029	1534
2029	3950
2029	2144
2030	720
2030	2935
2030	3363
2030	889
2031	1107
2031	3276
2031	802
2031	1262
2032	1439
2032	220
2032	4965
2032	429
2033	2669
2033	1706
2033	4232
2033	1431
2034	3689
2034	3158
2034	4721
2034	4369
2035	1955
2035	2519
2035	2790
2036	1721
2036	3148
2036	2201
2036	2017
2037	4919
2037	3492
2037	2028
2037	1323
2038	3698
2038	2874
2038	2731
2038	3684
2039	3991
2039	2117
2039	4591
2039	3488
2040	1946
2040	3313
2040	648
2040	3369
2041	3637
2041	502
2041	4031
2041	4899
2042	809
2042	4966
2042	4897
2042	454
2043	2150
2043	4378
2043	1868
2043	4126
2044	3952
2044	3853
2044	3992
2044	1968
2045	659
2045	479
2045	480
2045	60
2046	1004
2046	4373
2046	4523
2046	3234
2047	4344
2047	841
2047	476
2048	3645
2048	2192
2048	893
2048	1332
2049	2
2049	1554
2049	2285
2049	144
2050	2231
2050	4898
2050	2293
2050	1795
2051	2213
2051	2197
2051	2961
2051	2599
2052	2394
2052	3930
2052	2863
2052	766
2054	3717
2054	4522
2054	173
2054	4652
2055	4458
2055	459
2055	3643
2055	1355
2056	1991
2056	2175
2056	3648
2056	4385
2057	2784
2057	4060
2057	4560
2057	314
2058	2651
2058	172
2058	313
2058	980
2059	3832
2059	4406
2059	3074
2059	2226
2060	1940
2060	4562
2060	3613
2060	2646
2061	2872
2061	4820
2061	3281
2061	582
2062	2414
2062	1085
2062	573
2062	1663
2063	460
2063	3762
2063	574
2063	3908
2064	4328
2064	1535
2064	4278
2064	1713
2065	535
2065	1952
2065	3116
2065	4607
2066	535
2066	2391
2066	4357
2066	578
2067	3159
2067	3640
2067	3862
2067	2454
2068	3552
2068	2254
2068	2528
2068	3861
2069	1448
2069	1406
2069	1887
2069	4750
2070	1061
2070	2205
2070	2069
2070	1287
2071	1611
2071	4078
2071	397
2071	511
2072	3660
2072	3542
2072	3638
2072	2109
2073	2147
2073	560
2073	827
2073	1443
2074	2631
2074	4402
2074	1451
2074	3904
2075	552
2075	259
2075	4984
2075	4553
2076	4856
2076	1129
2076	1946
2076	1297
2077	4858
2077	398
2077	3415
2077	860
2078	2290
2078	1037
2078	1798
2078	2880
2079	134
2079	725
2079	810
2079	4349
2080	1890
2080	778
2080	2437
2080	1387
2081	2601
2081	3604
2081	586
2081	1307
2082	349
2082	4129
2082	1027
2082	1590
2083	3285
2083	111
2083	1066
2083	4171
2084	1572
2084	2974
2084	1760
2084	1307
2085	2436
2085	1078
2085	4285
2085	367
2086	2321
2086	913
2086	1852
2086	67
2087	378
2087	3568
2087	66
2087	1099
2088	1946
2088	3628
2088	3869
2088	630
2089	3717
2089	1288
2089	2701
2089	967
2090	2942
2090	3443
2090	3729
2090	3574
2091	3936
2091	815
2091	3233
2091	1275
2092	4811
2092	1125
2092	1879
2092	1755
2093	4379
2093	4811
2093	3496
2093	2434
2094	4811
2094	2492
2094	4293
2094	4588
2095	4818
2095	2326
2095	2371
2095	711
2096	4811
2096	4064
2096	3783
2096	1463
2097	2457
2097	2882
2097	2336
2097	59
2098	3736
2098	3742
2098	2780
2098	4756
2099	3328
2099	291
2099	3880
2099	2063
2100	4416
2100	3601
2100	3118
2100	3969
2101	4416
2101	3601
2101	4729
2101	4020
2102	4416
2102	3601
2103	4416
2103	3601
2103	62
2103	4359
2104	3676
2104	4478
2104	4363
2104	1418
2105	4416
2105	3601
2105	4592
2105	987
2106	4416
2106	3601
2106	1101
2106	4592
2107	4416
2107	3601
2107	1179
2107	1960
2108	4416
2108	3601
2108	2585
2108	4878
2109	261
2109	3098
2109	2321
2109	3007
2110	2147
2110	343
2110	2690
2110	4567
2111	402
2111	1368
2111	267
2111	1864
2112	2771
2112	1542
2112	1787
2112	3844
2113	4265
2113	4299
2113	3657
2113	1245
2114	159
2114	2717
2114	97
2114	4437
2115	3817
2115	3047
2115	1593
2115	2206
2116	4527
2116	3625
2116	1121
2116	2389
2117	349
2117	1004
2117	375
2117	415
2118	3833
2118	282
2118	3482
2118	3599
2119	2631
2119	267
2119	4632
2119	2058
2120	865
2120	247
2120	3289
2120	1445
2121	1847
2121	2643
2121	210
2121	4692
2122	4475
2122	3099
2122	1760
2122	3973
2123	4523
2123	474
2123	2948
2123	3754
2124	808
2124	2855
2124	3195
2124	2312
2125	3881
2125	3977
2125	1780
2125	1782
2126	557
2126	1900
2126	1445
2126	1985
2127	3474
2127	116
2127	2082
2127	4863
2128	3250
2128	1799
2128	4927
2129	2148
2129	2592
2129	2752
2129	4428
2131	3185
2131	3227
2131	4046
2131	2855
2132	3421
2132	3255
2132	1261
2132	1647
2133	431
2133	1403
2133	3612
2133	4811
2134	2741
2134	4582
2134	439
2135	4538
2135	693
2135	233
2135	4811
2136	4811
2136	1277
2136	1338
2136	4891
2137	4811
2137	3163
2137	3491
2137	1762
2138	1682
2138	4517
2138	2323
2138	2438
2139	3690
2139	441
2139	3478
2139	4925
2140	2530
2140	2533
2140	4454
2140	3671
2141	4811
2141	529
2141	2434
2141	1014
2142	3293
2142	972
2142	3883
2142	1089
2143	4811
2143	503
2143	3786
2143	1946
2144	4811
2144	1472
2144	1374
2144	1634
2145	4357
2145	2273
2145	2714
2145	1775
2146	1853
2146	605
2146	2417
2146	416
2147	3472
2147	4575
2147	1152
2147	3336
2148	2728
2148	971
2148	4465
2148	3225
2149	2187
2149	78
2149	405
2149	624
2150	4598
2150	4191
2150	606
2150	3315
2151	267
2151	2907
2151	2620
2151	1561
2152	1866
2152	2831
2152	4844
2152	1164
2153	4292
2153	1048
2153	2237
2153	3769
2154	186
2154	3660
2154	263
2154	4849
2155	1295
2155	2257
2155	935
2155	3106
2156	954
2156	2919
2156	2035
2156	95
2157	1552
2157	356
2157	1287
2157	4844
2158	3991
2158	3695
2158	340
2158	1948
2159	3991
2159	1576
2159	1672
2159	1860
2160	3862
2160	75
2160	3725
2160	2527
2161	4451
2161	3012
2161	2113
2161	2030
2162	1314
2162	106
2162	4521
2163	2796
2163	3879
2163	3061
2163	4110
2164	4678
2164	2700
2164	336
2164	1098
2165	1693
2165	4113
2165	1037
2165	4720
2166	4052
2166	4499
2166	307
2166	306
2167	4634
2167	965
2167	3856
2167	2291
2168	3112
2168	2028
2168	1496
2168	2501
2169	589
2169	334
2169	1277
2169	75
2170	4674
2170	213
2170	837
2170	1281
2171	2357
2171	382
2171	4599
2171	3137
2172	3854
2172	218
2173	2573
2173	4351
2173	87
2173	979
2174	3928
2174	1243
2174	1991
2174	2266
2175	2781
2175	2508
2175	204
2175	4881
2176	1247
2176	4305
2176	3744
2176	145
2177	2835
2177	4441
2177	2833
2177	2334
2178	737
2178	2696
2180	3130
2180	2593
2180	3278
2180	1041
2181	432
2181	1096
2181	3730
2181	1543
2182	2986
2182	2261
2182	3590
2183	2136
2183	3245
2183	2506
2183	1722
2184	2357
2184	3834
2184	62
2184	1494
2185	143
2185	4274
2185	2649
2185	1120
2186	1262
2186	4843
2186	1888
2186	3881
2187	3777
2187	3505
2187	566
2187	1131
2188	4681
2188	2195
2188	874
2188	4468
2189	691
2189	4491
2189	3476
2189	3947
2190	2769
2190	272
2190	642
2190	1249
2191	15
2191	1946
2191	4205
2191	2046
2192	4649
2192	564
2192	2840
2192	3981
2193	1885
2193	4186
2193	712
2193	1550
2194	2261
2195	4702
2195	4633
2195	4264
2195	4128
2196	3689
2196	3072
2196	3493
2196	2611
2197	4858
2197	3925
2197	1760
2197	1255
2198	4884
2198	3450
2198	1946
2198	4858
2199	609
2199	3450
2199	1946
2199	2636
2200	3666
2200	17
2200	684
2200	2793
2201	1246
2201	3506
2201	2013
2201	3839
2202	2386
2202	3387
2202	3760
2202	4168
2203	2221
2203	3414
2203	2171
2203	2098
2204	463
2204	1885
2204	4927
2204	1884
2205	1587
2205	4509
2205	1876
2205	1935
2206	2684
2206	810
2206	2087
2206	4512
2207	4029
2207	1300
2207	3449
2207	1380
2208	1359
2208	2560
2208	2288
2208	1944
2209	1939
2209	1673
2209	1526
2209	1684
2210	1988
2210	353
2210	1807
2210	4851
2211	1060
2211	4615
2211	4516
2211	2666
2212	3719
2212	1291
2212	4367
2212	3850
2214	2415
2214	2857
2214	1934
2215	1313
2215	2914
2215	2918
2215	4185
2216	4226
2216	1800
2216	2373
2216	169
2217	481
2217	973
2217	4154
2217	4773
2218	3582
2218	2098
2218	2063
2218	2913
2219	2773
2219	4459
2219	3235
2219	317
2220	3585
2220	737
2220	310
2220	799
2221	1113
2221	4873
2221	889
2221	1691
2222	4700
2222	2069
2222	1013
2222	354
2223	589
2223	1865
2223	4970
2223	689
2224	3703
2224	3330
2224	3756
2224	2718
2225	2053
2225	1987
2225	2098
2225	3166
2226	1230
2226	2311
2226	4770
2226	2097
2227	2406
2227	1843
2227	1779
2228	1779
2229	4465
2229	699
2229	2539
2229	4463
2230	113
2230	402
2230	805
2230	1950
2231	2037
2231	3540
2231	367
2231	2345
2232	1525
2232	4578
2232	3874
2232	3507
2233	3738
2233	2347
2234	4466
2234	494
2234	1991
2234	492
2236	9
2236	4275
2236	4545
2236	4772
2238	2618
2238	3246
2238	190
2238	52
2239	1060
2239	3411
2239	1049
2239	585
2240	2215
2240	147
2240	3340
2240	2309
2241	1154
2241	4532
2241	1276
2241	1042
2242	805
2242	3349
2242	4462
2242	2105
2243	3184
2243	307
2243	3292
2243	1664
2244	2098
2244	2474
2244	4802
2244	4331
2245	4319
2245	457
2245	30
2245	2242
2246	1866
2246	2172
2246	1646
2246	4054
2247	1659
2247	1623
2247	1601
2247	4379
2248	1102
2248	797
2248	3658
2248	4673
2249	503
2249	4379
2249	1397
2249	1217
2250	303
2250	3976
2250	2638
2250	3791
2251	4646
2251	3161
2251	2439
2251	2886
2252	1573
2252	3822
2252	3980
2252	3954
2253	4029
2254	1693
2254	2172
2254	1528
2254	3154
2255	55
2255	2586
2255	4607
2255	421
2256	3717
2256	2307
2256	2729
2256	1773
2257	3857
2257	1708
2257	4279
2258	2456
2258	2184
2258	4451
2258	3673
2259	1940
2259	426
2259	3780
2259	2739
2260	2594
2260	1534
2260	4285
2260	4380
2261	3173
2261	991
2261	933
2261	264
2262	2136
2262	4761
2262	1625
2262	3527
2263	2326
2263	635
2263	4845
2263	4146
2264	1948
2264	2435
2264	4916
2264	3792
2265	3246
2265	4301
2265	3276
2265	2023
2266	597
2266	4629
2266	2949
2266	989
2267	2440
2267	1023
2267	2241
2267	82
2268	3734
2268	625
2268	2814
2268	813
2269	3615
2269	2804
2269	3540
2269	4422
2270	4446
2270	3002
2270	4656
2270	1461
2271	2071
2271	2880
2271	1299
2271	3345
2272	4751
2272	3768
2272	2421
2272	410
2273	3927
2273	326
2273	910
2273	4893
2274	886
2274	3939
2274	535
2274	2123
2275	651
2275	4793
2275	4224
2275	1284
2276	4595
2276	299
2276	1773
2276	1086
2277	2922
2277	1398
2277	3871
2277	1173
2278	4753
2278	3454
2278	2682
2278	4478
2279	2760
2279	2247
2279	4272
2279	42
2280	2578
2280	4910
2280	4339
2280	333
2281	2101
2281	396
2281	1200
2281	2139
2282	833
2282	2028
2283	2186
2284	2416
2284	640
2284	4650
2284	1229
2285	2512
2285	4052
2285	4568
2285	4341
2286	2551
2286	1107
2286	4035
2286	1567
2287	2346
2287	144
2288	2260
2288	4048
2288	2348
2288	1301
2289	4909
2289	2274
2289	1498
2289	2447
2290	579
2290	2228
2290	225
2290	614
2291	3732
2291	673
2291	3704
2291	2711
2292	2004
2292	1641
2292	3937
2292	2838
2293	3823
2293	2899
2293	228
2293	2134
2294	4621
2294	323
2294	1736
2294	1743
2295	1587
2295	4302
2295	3762
2295	1143
2296	222
2296	2824
2296	2130
2296	4964
2297	2871
2297	4341
2297	1344
2297	2983
2298	776
2298	2278
2298	2359
2298	2507
2299	490
2299	3917
2299	4863
2299	1667
2300	1539
2300	1351
2300	1851
2300	3900
2301	4536
2301	2580
2301	4202
2301	3911
2302	4070
2302	566
2302	3194
2302	1529
2303	4172
2303	217
2303	4771
2303	2361
2304	2514
2304	3380
2304	170
2304	2526
2305	3774
2305	1567
2305	2806
2305	2352
2308	3190
2308	2801
2308	2757
2308	4420
2309	4945
2309	3708
2309	3504
2309	4138
2310	3759
2310	2725
2310	312
2310	1417
2311	1760
2311	1366
2311	4716
2311	3607
2312	854
2312	4387
2312	3648
2312	4920
2313	854
2313	4387
2313	1580
2313	440
2314	854
2314	4387
2314	1580
2314	4281
2315	854
2315	4387
2315	1580
2315	4930
2316	854
2316	590
2316	2048
2316	3062
2317	1469
2317	1136
2317	3401
2317	4240
2319	854
2319	409
2319	4631
2319	4610
2320	854
2320	2143
2320	723
2320	3591
2321	1806
2322	4633
2322	254
2322	3266
2322	216
2323	857
2323	4029
2323	1167
2323	400
2324	4888
2324	1298
2324	4050
2324	4867
2325	86
2325	2265
2325	3775
2326	4480
2326	2121
2327	2190
2327	2029
2327	3328
2327	2406
2328	1299
2328	3191
2328	2955
2328	3446
2329	1860
2329	2274
2329	1195
2329	3480
2330	850
2330	1162
2330	381
2330	3696
2331	651
2331	3492
2331	3306
2331	3902
2332	651
2332	3492
2332	4353
2333	2346
2333	2310
2333	2783
2333	1085
2334	3552
2334	4345
2334	53
2334	2362
2335	3255
2335	2935
2335	4137
2335	3389
2336	53
2336	1987
2336	1938
2336	2991
2337	2565
2337	1529
2337	1629
2337	418
2338	2290
2338	3205
2338	106
2338	3483
2339	3635
2339	4813
2339	2316
2339	2452
2340	432
2340	349
2340	2367
2340	4400
2341	4658
2341	3379
2341	1982
2341	2304
2342	4097
2342	3731
2342	3126
2342	2401
2343	4097
2343	1211
2343	4707
2343	1273
2344	3848
2344	1753
2344	3680
2344	1
2345	4011
2345	220
2345	2746
2345	2158
2346	3552
2346	1699
2347	1388
2347	1330
2347	3344
2347	1100
2348	2724
2348	2529
2348	4227
2348	806
2349	4974
2350	3800
2350	4222
2350	1600
2350	4597
2351	4300
2351	2171
2351	2531
2351	3818
2352	619
2352	174
2352	2669
2352	725
2353	906
2353	986
2353	4044
2353	3309
2354	4350
2354	523
2354	3999
2354	2989
2355	522
2355	4330
2355	3375
2355	3247
2356	378
2356	503
2356	4811
2356	351
2357	3477
2357	292
2357	3583
2357	34
2358	4595
2358	3166
2358	2023
2358	4885
2359	1571
2359	4043
2359	4453
2359	2000
2360	1107
2360	626
2360	4417
2360	3637
2361	4811
2361	1343
2361	4833
2361	437
2362	3330
2362	244
2362	4436
2362	274
2363	973
2363	4821
2363	503
2364	2808
2364	1688
2364	3893
2364	1324
2366	1311
2366	4485
2366	4682
2366	3740
2367	1916
2367	2984
2367	3594
2367	330
2368	2852
2368	2637
2368	4368
2368	1602
2369	4963
2369	1869
2370	4297
2370	3473
2370	4257
2370	4855
2371	4912
2371	871
2371	2146
2371	2198
2372	4723
2372	4464
2372	2813
2373	3403
2373	297
2373	1541
2374	3678
2374	3108
2374	4605
2374	408
2375	4633
2375	4300
2375	3648
2375	2525
2376	1572
2376	4578
2376	586
2376	1318
2377	334
2377	4080
2377	1140
2377	1433
2378	3759
2378	544
2378	3093
2378	657
2379	64
2379	3467
2379	689
2380	1515
2380	726
2380	1204
2380	347
2381	12
2381	4338
2381	1901
2381	1386
2382	1611
2382	2856
2382	4100
2382	1307
2383	3962
2383	302
2383	2570
2383	911
2384	1033
2385	1955
2385	967
2385	2750
2385	4167
2386	3230
2386	4102
2386	2043
2386	4926
2387	4782
2387	2200
2387	2038
2387	2166
2388	4618
2388	2762
2388	2038
2388	61
2389	3530
2389	3263
2389	596
2389	1213
2390	473
2390	63
2390	2254
2390	4058
2391	1988
2391	1104
2391	520
2391	3903
2392	1981
2392	4735
2392	2865
2392	1107
2393	2096
2393	2171
2393	4222
2393	3274
2394	4252
2394	1062
2394	1254
2394	2978
2395	1659
2395	1842
2395	690
2395	3919
2396	3273
2396	1181
2396	3979
2396	1604
2397	399
2397	694
2397	2743
2397	1800
2398	866
2398	1950
2398	1199
2398	3510
2399	4811
2399	1077
2399	2987
2399	1493
2400	3768
2400	91
2400	3529
2400	1462
2401	2440
2401	2483
2401	2175
2401	800
2402	4380
2402	2072
2402	334
2402	2483
2403	2440
2403	1470
2403	3045
2403	794
2404	857
2404	663
2404	2916
2404	4816
2405	808
2405	3054
2405	1050
2405	2873
2406	4628
2406	4636
2406	300
2406	1421
2407	1226
2407	2257
2407	2371
2407	4811
2408	1610
2408	3106
2408	4811
2408	1139
2409	4742
2409	4811
2409	2934
2409	1059
2410	1258
2410	4677
2410	1555
2410	151
2411	4052
2411	908
2411	1020
2411	4594
2412	271
2412	2363
2412	3775
2412	1881
2413	2487
2413	4481
2413	2327
2413	2821
2414	4658
2414	2565
2414	4879
2414	3469
2415	469
2415	1730
2415	2388
2415	4199
2416	4414
2416	129
2417	1156
2417	4180
2417	108
2417	58
2418	3879
2418	268
2418	950
2418	2193
2419	356
2419	1610
2419	1558
2419	2217
2420	2842
2420	1078
2420	349
2420	2435
2421	4256
2421	3326
2421	4510
2421	3367
2422	1991
2422	611
2422	82
2422	4150
2423	4940
2423	3840
2423	4016
2423	3174
2424	3950
2424	2155
2424	3515
2424	1694
2425	791
2425	1699
2425	4495
2425	2555
2426	2271
2426	2576
2426	2311
2426	412
2427	2855
2427	199
2427	2666
2427	649
2428	50
2428	3724
2428	2599
2428	3940
2429	807
2429	3041
2429	873
2429	2061
2430	3775
2430	1656
2430	3487
2430	3737
2431	1296
2431	2257
2431	3888
2431	1279
2432	1794
2432	407
2432	4747
2432	3014
2433	3558
2433	47
2433	161
2433	3821
2434	2509
2435	3296
2435	1183
2435	1319
2435	4606
2436	3896
2436	1416
2436	1950
2436	4271
2437	3474
2437	233
2437	2610
2437	530
2438	360
2438	3950
2438	3266
2438	2610
2439	3620
2439	971
2439	4590
2439	2761
2440	2053
2440	2136
2440	3874
2440	1134
2441	83
2441	164
2441	3353
2441	3891
2442	3414
2442	4719
2442	4874
2443	3602
2443	4422
2443	4839
2443	108
2444	4284
2444	4034
2444	4411
2444	2079
2445	3552
2445	3206
2445	4270
2445	1999
2446	4910
2446	2640
2446	1565
2446	464
2447	2915
2447	4957
2448	779
2448	1223
2448	1060
2448	1592
2449	163
2449	2437
2449	3382
2449	3272
2450	2667
2450	712
2450	1972
2451	1410
2451	2365
2451	2378
2451	4654
2452	200
2452	2023
2452	1385
2452	544
2453	3615
2453	2793
2453	3378
2453	2162
2454	748
2454	2618
2454	753
2454	2159
2455	2028
2455	307
2455	2560
2455	4097
2456	1582
2456	1053
2456	1477
2456	1788
2457	1838
2457	2819
2457	845
2457	1662
2458	1319
2458	889
2458	4015
2458	2098
2459	4374
2459	1987
2459	2633
2459	1188
2460	4181
2460	1730
2460	590
2460	3224
2461	431
2461	797
2461	2758
2461	1888
2462	2490
2462	309
2462	4158
2462	3308
2463	4074
2463	910
2463	2853
2463	2375
2464	1940
2464	4823
2464	4588
2464	1267
2465	2287
2465	2065
2465	4806
2465	1695
2466	3959
2466	4325
2466	2985
2466	3200
2467	1727
2467	1046
2467	907
2467	924
2468	3459
2468	3248
2468	2222
2468	3359
2469	2173
2469	1959
2469	878
2469	1298
2470	4862
2470	2182
2470	3847
2471	3355
2471	2742
2471	4869
2471	450
2472	4842
2472	165
2472	2114
2472	4166
2473	4295
2473	4247
2473	322
2473	3819
2474	4910
2474	2640
2474	3941
2474	4562
2475	1306
2475	4616
2475	3062
2475	798
2476	4049
2476	4493
2476	1839
2476	1728
2477	1994
2477	4546
2477	2486
2477	1681
2478	469
2478	3093
2478	1687
2478	4237
2479	4065
2479	2053
2479	690
2479	3445
2480	4296
2480	557
2480	1954
2480	1790
2481	324
2481	1512
2481	2663
2481	3404
2482	2179
2482	4910
2482	1088
2482	1481
2483	146
2483	3532
2483	4752
2483	2590
2484	4196
2484	619
2484	577
2484	74
2485	898
2485	512
2485	567
2485	350
2486	55
2486	3604
2486	1656
2486	2156
2487	4666
2487	2449
2488	4056
2488	678
2488	157
2488	121
2489	4390
2489	2415
2489	3451
2489	1660
2490	2440
2490	4907
2490	879
2490	2542
2491	4175
2491	3932
2491	4388
2491	2564
2492	3914
2492	3073
2492	850
2492	4499
2493	2290
2493	4625
2493	4647
2493	2437
2494	1369
2494	286
2494	1046
2494	1326
2495	1946
2495	3230
2495	798
2495	2328
2496	1671
2496	2367
2496	318
2496	4086
2497	4274
2497	793
2497	2622
2497	3918
2498	272
2498	4958
2498	3793
2498	627
2499	1200
2499	3232
2499	2528
2499	4633
2500	769
2500	3901
2500	728
2500	1422
2501	490
2501	3820
2501	2230
2501	2479
2502	4011
2502	2705
2502	1069
2502	2594
2503	2419
2503	312
2503	457
2503	158
2505	4211
2505	1244
2505	4817
2505	2292
2506	2771
2506	3418
2506	936
2506	4882
2507	4575
2507	2281
2507	2610
2507	4424
2508	4700
2508	1061
2508	2069
2508	2030
2509	854
2509	1598
2509	4835
2509	1933
2510	490
2510	2062
2510	4018
2510	1908
2511	4477
2511	2518
2511	858
2511	4795
2512	2769
2512	566
2512	485
2512	2027
2513	2426
2513	2031
2513	1507
2513	4562
2514	1745
2514	2033
2514	1419
2514	2733
2515	1693
2515	1919
2515	4852
2515	3561
2516	3373
2516	3073
2516	1086
2516	3960
2517	1976
2517	752
2517	2826
2517	765
2518	1314
2518	726
2518	10
2518	4893
2519	2860
2519	4949
2519	1111
2519	2803
2520	4700
2520	3227
2520	1492
2520	4384
2521	4264
2521	277
2521	3314
2521	2193
2522	1061
2522	2756
2522	3882
2522	1455
2523	1806
2523	650
2523	3676
2523	2444
2524	4811
2524	1320
2524	1409
2524	1857
2525	2373
2525	2048
2525	1225
2525	2674
2526	2440
2526	2631
2526	275
2526	3967
2527	2373
2527	1692
2527	3423
2527	1303
2528	775
2528	3155
2528	4161
2528	2799
2529	726
2529	233
2529	1642
2529	4682
2530	3834
2530	4028
2530	3629
2530	56
2531	3313
2531	1946
2531	2142
2531	3266
2532	3119
2532	2177
2532	696
2532	4901
2533	4296
2533	4720
2533	4830
2533	1876
2534	2079
2534	3840
2534	1260
2534	516
2535	1886
2535	4834
2535	3070
2535	3440
2536	4595
2536	1559
2536	798
2536	867
2537	4624
2537	2614
2537	474
2537	2443
2538	805
2538	4177
2538	3516
2538	1800
2539	4702
2539	3471
2539	1548
2539	5
2540	3352
2540	3576
2540	4566
2541	2640
2541	2104
2541	696
2541	193
2542	2440
2542	1061
2542	3191
2542	3319
2543	4100
2543	802
2543	3623
2543	1935
2544	4296
2544	3961
2544	4233
2544	1489
2545	2171
2545	76
2545	3073
2545	393
2546	3328
2546	4761
2546	521
2546	2888
2547	2543
2547	1856
2547	3084
2547	409
2548	2857
2548	4425
2548	3329
2548	3140
2549	1552
2549	1899
2549	45
2549	311
2550	1991
2550	649
2550	3101
2550	823
2551	706
2551	534
2551	4977
2551	4239
2552	2855
2552	854
2552	2120
2552	1771
2553	1078
2553	4651
2553	2367
2553	428
2554	4856
2554	1865
2554	4894
2554	3731
2555	573
2555	1367
2555	2256
2555	2719
2556	3065
2556	1703
2556	1776
2556	2404
2558	1043
2558	2100
2558	3448
2558	501
2559	589
2559	2769
2559	3917
2559	2252
2560	3342
2560	619
2560	1980
2560	3563
2561	2621
2561	483
2561	1342
2561	2559
2562	4214
2562	2728
2562	4034
2562	670
2563	4309
2563	168
2563	1485
2563	187
2565	1813
2565	4775
2565	271
2565	1747
2566	50
2566	3194
2566	257
2566	4119
2567	4865
2567	864
2567	884
2567	1152
2568	1779
2568	3789
2568	2265
2568	1317
2569	631
2569	3329
2569	3789
2569	3608
2570	1152
2570	4528
2570	1106
2570	3789
2571	76
2571	4347
2571	3849
2571	1870
2572	1671
2572	737
2572	3849
2572	586
2573	3961
2573	3849
2573	54
2573	4766
2574	3827
2574	1362
2574	1767
2574	1283
2575	3640
2575	3409
2575	4249
2575	1729
2576	3177
2576	2618
2576	396
2576	1649
2577	1012
2577	4004
2577	4157
2577	1983
2578	2544
2578	4765
2578	4204
2578	593
2579	3936
2579	2314
2579	4823
2579	3872
2580	1841
2580	3809
2580	604
2580	2689
2581	4480
2581	3858
2581	3425
2581	1290
2582	1940
2582	2007
2582	934
2582	2367
2583	3027
2583	1486
2583	262
2583	2703
2584	1502
2584	4700
2584	3513
2584	2896
2586	3471
2586	1520
2586	4315
2586	1921
2587	2878
2587	1812
2587	4720
2587	4130
2588	651
2588	2110
2588	4132
2588	1271
2589	3716
2589	1655
2589	1804
2589	3580
2590	1559
2590	4626
2590	1873
2591	3793
2591	3813
2591	4382
2591	1844
2592	3552
2592	3057
2592	696
2592	1056
2593	490
2593	1337
2593	3820
2593	681
2594	1152
2594	618
2594	1579
2594	3659
2595	1454
2595	55
2595	3606
2595	2360
2596	4524
2596	791
2596	3606
2596	1562
2597	3375
2597	4651
2597	2302
2597	3252
2598	1152
2598	3400
2598	1967
2598	4418
2599	3556
2599	3924
2599	1893
2599	4054
2600	1693
2600	215
2600	705
2600	115
2601	1611
2601	1963
2601	4054
2601	2129
2602	1806
2602	859
2602	896
2602	2627
2603	846
2603	2487
2603	3988
2603	4342
2604	3105
2604	2441
2604	3949
2604	2059
2605	3862
2605	3180
2605	1923
2605	2429
2606	33
2606	4045
2606	751
2606	2548
2607	2235
2607	1396
2607	1572
2607	1937
2608	1606
2608	834
2608	4306
2608	2409
2609	3604
2609	3351
2609	4944
2609	2322
2610	1059
2610	2754
2610	4052
2610	3530
2611	3959
2611	557
2611	4229
2611	2941
2612	1068
2612	2379
2612	2860
2612	1286
2613	663
2613	239
2613	3865
2613	2919
2614	4074
2614	326
2614	1824
2614	1219
2615	2308
2615	3176
2615	2276
2615	20
2616	2144
2616	1255
2616	2487
2616	1565
2617	1667
2617	1993
2617	2987
2617	4660
2618	1207
2618	1199
2618	1123
2618	2373
2619	1505
2619	1239
2619	1073
2619	4969
2620	2398
2620	3046
2620	3926
2620	280
2621	50
2621	3217
2621	1581
2621	2299
2622	1470
2622	3768
2622	3261
2622	3990
2623	86
2623	431
2623	3565
2623	1907
2624	3991
2624	2831
2624	690
2624	2927
2625	1515
2625	115
2625	1502
2625	2853
2626	2565
2626	1587
2626	3938
2626	305
2627	3179
2627	4064
2627	1185
2627	433
2628	3881
2628	3662
2628	3156
2628	1862
2629	22
2629	455
2629	1408
2629	4543
2630	4764
2630	3187
2630	2847
2630	4244
2631	1295
2631	2028
2631	4152
2631	2956
2632	2261
2632	822
2632	4841
2632	3920
2633	3898
2633	1212
2633	3384
2633	221
2634	3898
2634	1212
2634	3384
2634	221
2635	1224
2636	590
2636	4266
2636	2853
2636	1951
2637	2028
2637	2544
2637	1791
2637	2809
2638	4919
2638	1338
2638	3785
2638	287
2639	4868
2639	4112
2639	3638
2639	1459
2640	2244
2640	1253
2640	331
2640	4333
2641	2244
2641	1545
2641	448
2641	358
2642	4402
2642	4079
2642	818
2642	4895
2643	1948
2643	2138
2644	2045
2644	2749
2644	3374
2644	1545
2645	1528
2645	1323
2645	833
2645	705
2646	4067
2646	587
2646	4639
2646	65
2647	1350
2647	4022
2647	2381
2647	129
2648	152
2648	185
2648	2739
2648	4035
2649	4074
2649	1336
2649	4037
2649	1750
2650	1141
2650	3732
2650	25
2650	3190
2651	3950
2651	2338
2651	784
2651	486
2652	2085
2652	2414
2652	2626
2652	2525
2653	4008
2653	4317
2653	1982
2653	256
2654	2769
2654	1295
2654	910
2654	1595
2655	1552
2655	4844
2655	1210
2655	1517
2656	4848
2656	4187
2656	3709
2656	2645
2657	3581
2657	2165
2657	3877
2657	3383
2658	1828
2658	4149
2658	123
2658	3457
2659	183
2659	1128
2659	3383
2659	1966
2660	3068
2660	651
2660	3632
2660	1642
2661	3786
2661	2402
2661	3113
2661	715
2662	4783
2662	4062
2662	2807
2662	64
2663	4332
2663	4688
2663	4234
2663	2465
2664	3024
2664	3707
2664	551
2664	4343
2665	3800
2665	2164
2665	2713
2665	4319
2666	2406
2666	797
2666	2022
2667	2432
2667	966
2667	1466
2667	3973
2668	2457
2668	3125
2668	2860
2668	4206
2669	2457
2669	3125
2669	2794
2669	1498
2670	3079
2670	1054
2670	3989
2670	785
2671	4200
2671	4251
2671	2832
2672	2440
2672	1544
2672	1639
2672	21
2673	4907
2673	3501
2673	4528
2673	3396
2674	1211
2674	1940
2674	1401
2674	4458
2675	3798
2675	3836
2675	1619
2675	4245
2676	1553
2676	4490
2676	3636
2676	709
2677	1515
2677	1218
2677	4844
2677	4693
2678	2910
2678	2298
2678	284
2678	2025
2679	4101
2679	4967
2679	2235
2679	3766
2680	1145
2680	1275
2680	345
2680	2401
2681	4410
2681	734
2681	922
2681	4547
2682	4476
2682	4699
2682	1137
2682	4573
2683	4432
2683	1863
2683	2122
2683	2608
2684	4432
2684	1863
2684	2122
2684	3705
2685	4432
2685	3705
2685	3475
2685	4892
2686	886
2686	1631
2686	2691
2686	391
2687	1611
2687	1350
2687	211
2687	1714
2688	1797
2688	1866
2688	4356
2688	3595
2689	3837
2689	2804
2689	4633
2689	1635
2690	3717
2690	1170
2690	2015
2690	1755
2691	3026
2692	2039
2692	2011
2692	3243
2692	499
2694	3933
2694	3364
2694	2260
2694	1827
2695	3778
2695	371
2695	4088
2695	3270
2696	4929
2696	1493
2696	442
2696	2879
2697	4662
2697	2107
2697	1277
2697	1816
2698	797
2698	698
2699	3958
2699	3639
2699	4182
2699	2902
2700	199
2700	4929
2700	4680
2700	4504
2701	2415
2701	3262
2701	1846
2701	3815
2702	4074
2702	4054
2702	2661
2702	85
2703	2110
2703	2308
2703	693
2703	3957
2704	1946
2704	643
2704	529
2704	2001
2705	4180
2705	2169
2705	1800
2705	3552
2706	943
2706	2934
2706	4451
2706	1354
2707	943
2707	3917
2707	1304
2707	2379
2708	2855
2708	4713
2709	3412
2709	4091
2709	1075
2709	3395
2710	2405
2710	4584
2710	2732
2710	3998
2711	1206
2711	4151
2711	240
2711	2844
2712	1420
2712	1269
2712	2869
2712	3011
2713	2544
2713	4080
2713	2008
2713	2666
2714	1260
2714	1416
2714	2254
2714	799
2715	4568
2715	968
2715	1262
2715	675
2716	3615
2716	3985
2716	4559
2716	4298
2717	3854
2717	4668
2717	4371
2717	1765
2718	4061
2718	2602
2718	1051
2718	1384
2719	3251
2719	2602
2719	4844
2719	3945
2720	4074
2720	1605
2720	4604
2720	2980
2721	4035
2721	3036
2721	1999
2721	4423
2722	2561
2722	2003
2722	2358
2722	3232
2723	2358
2723	2970
2723	2289
2723	1177
2724	1773
2724	4643
2724	3393
2724	3131
2725	3341
2725	1885
2725	1734
2725	4968
2726	3800
2726	2682
2726	696
2726	1522
2727	4456
2727	2971
2727	4073
2727	679
2728	3038
2728	1989
2728	4457
2728	388
2729	1350
2729	802
2729	4509
2729	919
2730	4891
2730	272
2730	3964
2730	3939
2731	943
2731	1576
2731	2584
2731	418
2732	1202
2732	704
2732	2251
2732	4155
2733	356
2733	3937
2733	3043
2733	3094
2734	356
2734	1515
2734	2257
2734	4923
2735	2581
2735	4163
2735	3134
2735	1511
2736	4097
2736	4071
2736	1218
2736	1932
2737	1595
2737	2834
2737	521
2738	4742
2738	2934
2738	378
2738	1547
2739	2716
2739	4375
2739	2060
2739	206
2740	1105
2740	2111
2740	3117
2740	1912
2741	2015
2741	334
2741	3571
2741	4336
2742	4065
2742	4022
2742	2633
2742	4492
2743	3872
2743	2729
2743	1808
2743	3587
2744	3781
2744	441
2744	2857
2744	4217
2745	4952
2745	2469
2745	4473
2745	8
2746	1803
2746	775
2746	2673
2746	3932
2747	767
2747	451
2747	2161
2747	1467
2748	558
2748	3103
2748	1962
2748	2624
2749	4850
2749	2257
2749	1610
2749	2336
2750	4629
2750	3204
2750	2518
2750	3557
2751	3417
2751	1694
2751	4769
2751	4160
2752	1819
2752	3845
2752	4554
2752	4698
2753	4896
2753	4691
2753	2937
2754	3774
2754	3062
2754	1166
2754	3022
2755	3388
2755	2175
2755	3119
2755	3701
2756	2053
2756	3388
2756	4509
2756	1639
2757	360
2757	3388
2757	1412
2757	4922
2758	360
2758	3616
2758	2662
2758	4850
2759	3388
2759	1563
2759	1314
2759	4619
2760	705
2760	503
2760	4216
2760	3993
2761	3768
2761	1199
2761	1609
2762	2792
2762	587
2762	3728
2762	2032
2763	4985
2763	377
2763	2734
2763	1700
2764	2769
2764	4700
2764	1396
2764	2069
2765	3349
2765	2851
2765	2943
2765	4929
2766	2595
2766	2952
2766	4762
2766	1531
2767	1940
2767	4000
2767	2393
2767	744
2768	1624
2768	270
2768	3484
2768	417
2769	1037
2769	4350
2769	1639
2769	4101
2770	4589
2770	2545
2770	2245
2770	2931
2771	4937
2772	822
2772	3492
2772	4402
2772	2954
2773	4010
2773	4337
2773	3961
2773	1118
2774	1068
2774	3207
2774	3640
2774	3801
2775	3400
2775	597
2775	3604
2775	1489
2776	1552
2776	324
2776	3268
2776	2401
2777	1602
2777	3927
2777	236
2777	3935
2778	1671
2778	999
2778	2670
2778	2005
2779	4222
2779	2275
2779	3881
2779	15
2780	3954
2780	1218
2780	609
2780	470
2781	3337
2781	4198
2781	688
2781	4222
2782	1061
2782	4499
2782	4880
2782	3533
2783	2136
2783	909
2783	4629
2783	255
2784	1129
2784	4959
2784	4236
2784	2476
2785	4052
2785	1341
2785	4097
2785	1444
2786	3810
2786	423
2786	1872
2786	952
2787	569
2787	2563
2787	1566
2787	4001
2788	795
2788	4341
2788	1135
2788	3450
2789	1211
2789	2007
2789	3828
2789	4591
2790	1385
2790	1699
2790	456
2790	757
2791	3612
2791	1987
2791	2160
2791	4932
2792	726
2792	4396
2792	3858
2792	1579
2793	2373
2793	2284
2793	546
2793	4380
2794	4358
2794	1756
2794	4173
2794	609
2795	2321
2795	2993
2795	2330
2795	3534
2796	1512
2796	1063
2796	4532
2796	2926
2797	4532
2797	4811
2797	4498
2797	1049
2798	356
2798	589
2798	212
2798	2860
2799	3344
2799	3073
2799	1047
2799	2665
2800	1779
2800	1871
2800	2406
2800	3487
2801	2145
2801	3086
2801	3480
2801	3016
2803	2710
2803	1524
2803	2837
2803	846
2804	3579
2804	1115
2804	3396
2804	4068
2805	2544
2805	1512
2805	210
2805	3784
2806	1512
2806	4006
2806	25
2807	2261
2807	822
2808	2883
2808	237
2808	2433
2808	1193
2809	1813
2809	4811
2809	340
2809	208
2810	1943
2810	3221
2810	198
2810	2688
2811	3995
2811	2319
2811	4694
2811	4201
2812	2678
2812	664
2812	4021
2812	1580
2814	4676
2814	4054
2814	2073
2814	3312
2815	4676
2815	2549
2815	2232
2815	1513
2816	4135
2816	3625
2816	323
2816	1711
2817	1568
2817	347
2817	1287
2817	3718
2818	4074
2818	356
2818	2534
2818	1778
2819	3917
2819	3885
2819	4913
2819	3343
2820	4283
2820	2425
2820	1216
2820	3739
2822	3948
2822	1904
2822	1413
2822	3497
2823	554
2823	1058
2823	3452
2823	3761
2824	2977
2824	1177
2824	935
2824	307
2825	1105
2825	3226
2825	109
2825	4841
2826	3304
2826	1659
2826	2843
2826	4322
2827	3891
2827	1973
2827	96
2827	1065
2828	324
2828	4350
2828	2007
2828	2600
2829	4079
2829	949
2829	2150
2829	1842
2830	3939
2830	2560
2830	3954
2830	1815
2831	1063
2831	1771
2831	1254
2831	1705
2832	384
2832	2851
2832	4726
2832	1705
2833	2607
2833	3522
2833	3853
2833	3400
2834	4097
2834	835
2834	1712
2834	1951
2835	3660
2835	553
2835	2129
2835	3046
2836	4290
2836	2455
2836	3527
2836	1698
2837	2974
2837	2188
2837	3032
2837	2405
2838	1826
2838	4507
2838	1650
2838	2044
2839	3188
2839	267
2839	2327
2839	4506
2840	1550
2840	1188
2840	706
2840	3128
2841	4052
2841	2069
2841	4863
2841	1702
2842	4521
2842	3786
2842	1625
2842	2269
2843	705
2843	2406
2843	518
2843	982
2844	4499
2844	4082
2844	2055
2844	4007
2845	4728
2845	4738
2845	4026
2845	4425
2846	324
2846	397
2846	2423
2846	867
2847	2369
2847	4071
2847	2522
2847	4002
2848	2987
2848	2336
2848	3619
2848	3192
2849	3139
2849	1385
2849	850
2849	648
2850	3551
2850	1051
2850	4443
2850	2644
2852	3825
2852	4097
2852	693
2852	1640
2853	4024
2853	1361
2853	2243
2853	1603
2854	4742
2854	334
2854	3292
2854	1403
2855	1407
2855	2224
2855	1280
2855	1452
2856	691
2856	2856
2856	1199
2856	4739
2857	1693
2857	413
2858	2049
2858	2408
2858	2612
2858	4291
2859	1414
2859	4765
2859	4705
2859	2330
2860	1674
2860	4261
2860	271
2860	4296
2861	1061
2861	51
2861	4156
2861	4637
2862	4232
2862	4984
2862	4363
2862	4441
\.


--
-- Name: movies_movie_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('movies_movie_id_seq', 1, false);


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY venues (venue_id, name, street_adress, type, postal_code, country_code, active) FROM stdin;
1	Crystal Ballroom	\N	public 	97205	us	t
2	Voodoo Donuts	\N	public 	97205	us	t
3	Test	DEFAULTS	public 	\N	\N	t
4	My Place	Cranachstr. 63	private	12157	de	t
5	Run's House	\N	public 	97205	us	f
\.


--
-- Name: venues_venue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('venues_venue_id_seq', 5, true);


--
-- Name: actors_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY actors
    ADD CONSTRAINT actors_pkey PRIMARY KEY (actor_id);


--
-- Name: cities_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (country_code, postal_code);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (comment_id);


--
-- Name: countries_country_name_key; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY countries
    ADD CONSTRAINT countries_country_name_key UNIQUE (country_name);


--
-- Name: countries_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (country_code);


--
-- Name: events_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (event_id);


--
-- Name: genres_name_key; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY genres
    ADD CONSTRAINT genres_name_key UNIQUE (name);


--
-- Name: movies_actors_movie_id_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY movies_actors
    ADD CONSTRAINT movies_actors_movie_id_actor_id_key UNIQUE (movie_id, actor_id);


--
-- Name: movies_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY movies
    ADD CONSTRAINT movies_pkey PRIMARY KEY (movie_id);


--
-- Name: venues_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (venue_id);


--
-- Name: events_starts; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX events_starts ON events USING btree (starts);


--
-- Name: events_title; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX events_title ON events USING hash (title);


--
-- Name: movies_actors_actor_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX movies_actors_actor_id ON movies_actors USING btree (actor_id);


--
-- Name: movies_actors_movie_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX movies_actors_movie_id ON movies_actors USING btree (movie_id);


--
-- Name: movies_genres_cube; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX movies_genres_cube ON movies USING gist (genre);


--
-- Name: movies_title_pattern; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX movies_title_pattern ON movies USING btree (lower(title) text_pattern_ops);


--
-- Name: movies_title_searchable; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX movies_title_searchable ON movies USING gin (to_tsvector('english'::regconfig, title));


--
-- Name: movies_title_trigram; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX movies_title_trigram ON movies USING gist (title gist_trgm_ops);


--
-- Name: delete_venues; Type: RULE; Schema: public; Owner: vagrant
--

CREATE RULE delete_venues AS ON DELETE TO venues DO INSTEAD UPDATE venues SET active = false WHERE ((venues.name)::text = (old.name)::text);


--
-- Name: insert_holidays; Type: RULE; Schema: public; Owner: vagrant
--

CREATE RULE insert_holidays AS ON INSERT TO holidays DO INSTEAD INSERT INTO events (title, starts, colors) VALUES (new.name, new.date, new.colors);


--
-- Name: update_holidays; Type: RULE; Schema: public; Owner: vagrant
--

CREATE RULE update_holidays AS ON UPDATE TO holidays DO INSTEAD UPDATE events SET title = new.name, starts = new.date, colors = new.colors WHERE (events.title = old.name);


--
-- Name: log_events; Type: TRIGGER; Schema: public; Owner: vagrant
--

CREATE TRIGGER log_events AFTER UPDATE ON events FOR EACH ROW EXECUTE PROCEDURE log_event();


--
-- Name: cities_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY cities
    ADD CONSTRAINT cities_country_code_fkey FOREIGN KEY (country_code) REFERENCES countries(country_code);


--
-- Name: comments_movie_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_movie_id_fkey FOREIGN KEY (movie_id) REFERENCES movies(movie_id);


--
-- Name: events_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES venues(venue_id);


--
-- Name: movies_actors_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY movies_actors
    ADD CONSTRAINT movies_actors_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES actors(actor_id);


--
-- Name: movies_actors_movie_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY movies_actors
    ADD CONSTRAINT movies_actors_movie_id_fkey FOREIGN KEY (movie_id) REFERENCES movies(movie_id);


--
-- Name: venues_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY venues
    ADD CONSTRAINT venues_country_code_fkey FOREIGN KEY (country_code, postal_code) REFERENCES cities(country_code, postal_code) MATCH FULL;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

