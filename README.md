# Blogico
This is a small application for a personal website that hosts an art gallery, a personal blog with articles, and a big projects section.

## What you can do using this app:
- Login and log out as admin
- under admin login, you can create new posts, modify or delete existing posts and pages
- remember me cookie is implemented
- Change your personal user information (password)
- as a not logged-in user you can brows the website, filter posts by tags.

## Information on how to start this application
- To run this application (in a development mode), you’ll need to have PostgreSQL, Ruby, and bundler installed on your computer.
- Run `bundler install` to install any gems specified in Gemfile (the archive contains Gemfile.lock, you’ll need to delete it before running bundle).
- After gems have been successfully installed, you should be ok to run the application using `ruby ccw.rb` command. The application was designed to create postgresql database (if missing) and upload seed data. You then should be able to access the functionality by typing ‘http://localhost:4567/’ in your browser's address bar. I tested it multiple times. However, I do not have a separate computer to test it from scratch.
- To test existing admin feature use the following credentials: username - vysh@gmail.com, password - 1234


The version of Ruby you used to run this application - ruby v3.1.2
The browser (including version number) that I used to test this application - Brave Web Browser (Version 1.41.96 Chromium: 103.0.5060.114 (Official Build) (64-bit))
The version of PostgreSQL I used to create any databases - psql (PostgreSQL) 12.11 (Ubuntu 12.11-0ubuntu0.20.04.1)

## Additional details:
- tests are also included in the repo for your convenience.
