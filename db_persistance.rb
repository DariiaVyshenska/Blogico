# frozen_string_literal: true

require 'pg'
require 'redcarpet'

# this class is an interface for interacting with PSQL database for the CCW App
class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'mywebsite')
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  # in the end see if you can reduce result.values.first&.first to be a method
  def get_user_password(email)
    sql = 'SELECT password FROM users WHERE email = $1'
    result = query(sql, email)
    result.values.first&.first
  end

  def change_user_password(email, pwd)
    sql = 'UPDATE users SET password = $1 WHERE email = $2'
    query(sql, pwd, email)
  end

  def new_post(category, header, text, tags)
    sql_new_page = <<~MSG
      INSERT INTO webpages (category, header, page_text)
      VALUES ($1, $2, $3)
    MSG
    query(sql_new_page, category, header, text)

    add_new_tags_to_post(latest_post_id, tags)
  end

  def delete_post(post_id)
    sql = 'DELETE FROM webpages WHERE id = $1'
    query(sql, post_id)
  end

  def latest_post_id
    sql = 'SELECT MAX(id) FROM webpages'
    query(sql).values.first&.first
  end

  def update_post(post_id, new_category, new_header, new_text)
    sql = <<~MSG
      UPDATE webpages
      SET category = $1,
          header = $2,
          page_text = $3
      WHERE id = $4
    MSG
    query(sql, new_category, new_header, new_text, post_id)
  end

  def update_post_tags(post_id, new_tags)
    sql_delete_post_tags = 'DELETE FROM tags_webpages WHERE webpage_id = $1'
    query(sql_delete_post_tags, post_id)

    add_new_tags_to_post(post_id, new_tags)
  end

  def about_page
    sql = "SELECT * FROM webpages WHERE category = 'about'"
    result = query(sql)
    pageinfo_to_arr(result).first
  end

  def posts(type, limit, offset)
    sql = <<~MSG
      SELECT w.id, DATE(w.creation_date), w.header, w.page_text,
             w.category, string_agg(tags.tag_name, ';') AS tags
        FROM webpages AS w
          LEFT JOIN tags_webpages ON w.id = tags_webpages.webpage_id
          LEFT JOIN tags ON tags_webpages.tag_id = tags.id
      WHERE category = $1
      GROUP BY w.id
      ORDER BY creation_date DESC
      LIMIT $2 OFFSET $3
    MSG
    result = query(sql, type, limit, offset)
    pageinfo_to_arr(result)
  end

  def find_posts(query)
    sql = <<~MSG
      SELECT w.id, DATE(w.creation_date), w.header, w.page_text,
             w.category, string_agg(tags.tag_name, ';') AS tags
        FROM webpages AS w
          LEFT JOIN tags_webpages ON w.id = tags_webpages.webpage_id
          LEFT JOIN tags ON tags_webpages.tag_id = tags.id
      WHERE w.header LIKE '%#{@db.escape_string(query)}%' OR w.page_text LIKE '%#{@db.escape_string(query)}%'
      GROUP BY w.id
      ORDER BY creation_date DESC
    MSG
    result = query(sql)
    pageinfo_to_arr(result)
  end

  def all_tags_for_post_type(post_type)
    sql = <<~MSG
      SELECT DISTINCT tags.tag_name, tags.id FROM tags
        JOIN tags_webpages ON tags.id = tags_webpages.tag_id
        WHERE tags_webpages.webpage_id IN
          (SELECT id FROM webpages WHERE category = $1);
    MSG
    result = query(sql, post_type)
    tag_info_to_arr(result)
  end

  def posts_by_tag(post_type, tag_id, limit, offset)
    sql = <<~MSG
      SELECT w.id, DATE(w.creation_date), w.header, w.page_text,
             w.category, string_agg(tags.tag_name, ';') AS tags
        FROM webpages AS w
          LEFT JOIN tags_webpages ON w.id = tags_webpages.webpage_id
          LEFT JOIN tags ON tags_webpages.tag_id = tags.id
      WHERE w.id IN (SELECT webpage_id FROM tags_webpages
        WHERE tag_id IN (SELECT id FROM tags WHERE tags.id = $2))
        AND w.category = $1
      GROUP BY w.id
      ORDER BY creation_date DESC
      LIMIT $3 OFFSET $4
    MSG
    result = query(sql, post_type, tag_id, limit, offset)
    pageinfo_to_arr(result)
  end

  def post(post_id)
    sql = <<~MSG
      SELECT w.id, DATE(w.creation_date), w.header, w.page_text,
             w.category, string_agg(tags.tag_name, ';') AS tags
        FROM webpages AS w
          LEFT JOIN tags_webpages ON w.id = tags_webpages.webpage_id
          LEFT JOIN tags ON tags_webpages.tag_id = tags.id
      WHERE w.id = $1
      GROUP BY w.id
      ORDER BY creation_date DESC
    MSG
    result = query(sql, post_id)
    pageinfo_to_arr(result).first
  end

  def post_unrendered(post_id)
    sql = <<~MSG
      SELECT w.id, DATE(w.creation_date), w.header, w.page_text,
             w.category, string_agg(tags.tag_name, ';') AS tags
        FROM webpages AS w
          LEFT JOIN tags_webpages ON w.id = tags_webpages.webpage_id
          LEFT JOIN tags ON tags_webpages.tag_id = tags.id
      WHERE w.id = $1
      GROUP BY w.id
      ORDER BY creation_date DESC
    MSG
    result = query(sql, post_id)
    pageinfo_to_arr_unrendered(result).first
  end

  def ntuple_posts(type, tag_id = nil)
    result = if tag_id
               sql = <<~MSG
                 SELECT 1
                   FROM webpages AS w
                     LEFT JOIN tags_webpages ON w.id = tags_webpages.webpage_id
                     LEFT JOIN tags ON tags_webpages.tag_id = tags.id
                 WHERE w.category = $1 AND tags.id = $2
               MSG
               query(sql, type, tag_id)
             else
               sql = 'SELECT 1 FROM webpages WHERE category = $1'
               query(sql, type)
             end
    result.ntuples
  end

  def post_exists?(post_id)
    sql = 'SELECT 1 FROM webpages WHERE id = $1'
    !query(sql, post_id).ntuples.zero?
  end

  def all_categories
    sql = 'SELECT DISTINCT category FROM webpages'
    result = query(sql)
    result.values.flatten.sort
  end

  def get_user_id_by_email(email)
    sql = 'SELECT id FROM users WHERE email = $1'
    result = query(sql, email)
    result.values.first&.first
  end

  def find_token(selector)
    sql = 'SELECT * FROM auth_tokens WHERE selector = $1 AND expires > NOW()'
    result = query(sql, selector)
    token = token_to_arr(result)
    token.empty? ? nil : token.first
  end

  def user_id_by_token_selector(selector)
    sql = 'SELECT user_id FROM auth_tokens WHERE selector = $1'
    result = query(sql, selector)
    result.values.first&.first
  end

  def get_user_email(user_id)
    sql = 'SELECT email FROM users WHERE id = $1'
    result = query(sql, user_id)
    result.values.first&.first
  end

  def delete_all_user_tokens(user_id)
    sql = 'DELETE FROM auth_tokens WHERE user_id = $1'
    query(sql, user_id)
  end

  def new_token(token, user_id, expiration_info)
    sql = <<~MSG
      INSERT INTO auth_tokens (selector, hashedValidator, user_id, expires)
        VALUES ($1, $2, $3, $4)
    MSG
    query(sql, token[:selector], token[:validator], user_id, expiration_info)
  end

  def delete_token(selector)
    sql = 'DELETE FROM auth_tokens WHERE selector = $1'
    query(sql, selector)
  end

  private

  def token_to_arr(result)
    result.map do |tuple|
      {
        id: tuple['id'],
        selector: tuple['selector'],
        validator: tuple['hashedvalidator'],
        user_id: tuple['user_id'],
        expiration: tuple['expires']
      }
    end
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def add_new_tags_to_post(post_id, new_tags)
    update_all_tags(new_tags)
    new_tags.each do |tag_name|
      sql = <<~MSG
        INSERT INTO tags_webpages (webpage_id, tag_id)
          VALUES ($1, (SELECT id FROM tags WHERE tag_name = $2))
      MSG
      query(sql, post_id, tag_name)
    end
  end

  def pageinfo_to_arr(result)
    result.map do |tuple|
      {
        id: tuple['id'],
        category: tuple['category'],
        date: tuple['date'],
        header: tuple['header'],
        body: render_md(tuple['page_text']),
        tags: tags_to_arr(tuple['tags'])
      }
    end
  end

  def pageinfo_to_arr_unrendered(result)
    result.map do |tuple|
      {
        id: tuple['id'],
        category: tuple['category'],
        date: tuple['date'],
        header: tuple['header'],
        body: tuple['page_text'],
        tags: tags_to_arr(tuple['tags'])
      }
    end
  end

  def tags_to_arr(tags_str)
    tags_str ? tags_str.split(';') : []
  end

  def render_md(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end

  def update_all_tags(new_tags)
    existing_tag_names = tags.map { |tag| tag[:name] }
    absent_tag_names = new_tags - existing_tag_names
    absent_tag_names.map do |tag|
      sql = <<~MSG
        INSERT INTO tags (tag_name) VALUES ($1)
      MSG
      query(sql, tag)
    end
  end

  def tags
    sql = 'SELECT DISTINCT tags.tag_name, tags.id FROM tags'
    result = query(sql)
    tag_info_to_arr(result)
  end

  def tag_info_to_arr(result)
    result.map do |tuple|
      {
        id: tuple['id'],
        name: tuple['tag_name']
      }
    end
  end
end
