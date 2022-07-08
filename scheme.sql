CREATE TABLE webpages(
  id serial PRIMARY KEY,
  category text,
  creation_date timestamp NOT NULL DEFAULT NOW(),
  header text NOT NULL DEFAULT '',
  page_text text NOT NULL DEFAULT ''
);

CREATE TABLE tags(
  id serial PRIMARY KEY,
  tag_name varchar(25) NOT NULL UNIQUE CHECK((tag_name = '') IS NOT TRUE)
);

CREATE TABLE tags_webpages(
  id serial PRIMARY KEY,
  webpage_id INT NOT NULL REFERENCES webpages(id) ON DELETE CASCADE,
  tag_id INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  UNIQUE(webpage_id, tag_id)
);

\set content `cat ./test/test_post_files/about.txt`
INSERT INTO webpages (category, header, page_text) VALUES ('about', 'Hello and Welcome to my web-site!', :'content');

INSERT INTO webpages (category, header, page_text)
VALUES
  ('photos', 'Flowers', E'<img src="https://live.staticflickr.com/65535/52099970287_88d68859ca_k.jpg" width="500"/>'),
  ('drawings', 'Not my drawing', E'<img src="https://drawpaintacademy.com/wp-content/uploads/2017/09/Best-Drawing-Books.jpg" width="500"/>'),
  ('blog_posts', 'Post number 1', 'This is my first post'),
  ('blog_posts', 'Post number 2','This is my second post'),
  ('software_projects', 'Stus', 'This will be explanation of my project');

INSERT INTO tags (tag_name)
VALUES
  ('my life'),
  ('nature'),
  ('art'),
  ('work of others'),
  ('helping others');

INSERT INTO tags_webpages (webpage_id, tag_id)
VALUES
  (2, 1),
  (2, 2),
  (3, 3),
  (3, 4),
  (4, 5),
  (4, 1),
  (5, 1),
  (6, 5);

\set content `cat ./test/test_post_files/post3.txt`
INSERT INTO webpages (category, header, page_text) VALUES ('blog_posts', '20,000 Leagues etc. book', :'content');

INSERT INTO tags_webpages (webpage_id, tag_id)
VALUES
(7, 3),
(7, 4);


\set content `cat ./test/test_post_files/post4.html`
INSERT INTO webpages (category, header, page_text) VALUES ('blog_posts', 'Sanitization test', :'content');

INSERT INTO tags_webpages (webpage_id, tag_id)
VALUES
(8, 1),
(8, 4);


INSERT INTO webpages (category, header, page_text)
VALUES
('blog_posts', 'Post number 5', 'Test text for pagination'),
('blog_posts', 'Post number 6','Another pagination text');

INSERT INTO tags_webpages (webpage_id, tag_id)
VALUES
  (9, 1),
  (10, 1);

CREATE TABLE users(
  id serial PRIMARY KEY,
  email text NOT NULL UNIQUE,
  password text NOT NULL,
  admin boolean NOT NULL
);

CREATE TABLE auth_tokens (
    id serial PRIMARY KEY,
    selector char(12),
    hashedValidator text,
    user_id INT NOT NULL REFERENCES users(id),
    expires timestamp
);

INSERT INTO users (email, password, admin)
VALUES ('vysh@gmail.com', '$2a$12$Xwqrah.O/GSieHa2bYdRn.maUNR6XcbOH6haFxkcdG2j55wHFAVwe', true);

INSERT INTO auth_tokens (selector, hashedValidator, user_id, expires)
VALUES ('testselector', '95d5b30858eca1f25cb94c64205522b5034a7ed7d907f5f9fff4fdc6fcaf8870', '1', '2023-07-01 9:30:20');

INSERT INTO auth_tokens (selector, hashedValidator, user_id, expires)
VALUES ('testselecto2', '95d5b30858eca1f25cb94c64205522b5034a7367d907f5f9fff4fdc6fcaf8870', '1', '2023-07-01 9:30:20');

INSERT INTO auth_tokens (selector, hashedValidator, user_id, expires)
VALUES ('expiredselec', 'bf434449496b02dd3de8c6b1b3057a0cd2f7f48fca41bafd57b9359dd29d9b31', '1', '2022-05-01 9:30:20');

INSERT INTO webpages (category, header, page_text)
VALUES
('blog_posts', 'test', 'initial text');

INSERT INTO tags_webpages (webpage_id, tag_id)
VALUES
  (11, 1),
  (11, 2);
