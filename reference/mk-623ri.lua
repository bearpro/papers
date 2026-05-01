-- mk-623ri.lua
-- Pandoc Lua filter for DOCX articles formatted according to МК-623РИ.
-- Use with: pandoc paper.md --reference-doc=mk-623ri-reference.docx --lua-filter=mk-623ri.lua -o out.docx

local stringify = pandoc.utils.stringify

local meta_cache = {
  title = nil,
  authors = {},
  date = nil,
  udk = nil,
  use_title_block = true,
  uppercase_title = true,
  show_date = false,
  caption_prefixes = true,
}

local fig_no = 0
local tbl_no = 0

local function trim(s)
  return (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function meta_bool(meta, key, default)
  local v = meta[key]
  if v == nil then return default end
  local s = pandoc.text.lower(trim(stringify(v)))
  if s == '' then return default end
  return not (s == 'false' or s == '0' or s == 'no' or s == 'нет' or s == 'off')
end

local function meta_string(meta, key)
  if meta[key] == nil then return nil end
  local s = trim(stringify(meta[key]))
  if s == '' then return nil end
  return s
end

local function meta_list_to_strings(v)
  local result = {}
  if v == nil then return result end
  if type(v) == 'string' then
    table.insert(result, trim(v))
  elseif type(v) == 'table' and (#v > 0 or v.t == 'MetaList') then
    for _, item in ipairs(v) do
      local s = trim(stringify(item))
      if s ~= '' then table.insert(result, s) end
    end
  else
    local s = trim(stringify(v))
    if s ~= '' then table.insert(result, s) end
  end
  return result
end

local function styled_para(text, style_name, bold)
  local inlines = pandoc.List({pandoc.Str(text)})
  local para
  if bold then
    para = pandoc.Para({pandoc.Strong(inlines)})
  else
    para = pandoc.Para(inlines)
  end
  return pandoc.Div({para}, pandoc.Attr('', {}, {['custom-style'] = style_name}))
end

local function prepend_inlines(original, prefix)
  local new = pandoc.List(prefix)
  new:extend(original)
  return new
end

local function caption_starts_with_label(text, label)
  local t = pandoc.text.lower(trim(text))
  label = pandoc.text.lower(label)
  return t:match('^' .. label) ~= nil
end

function Meta(meta)
  meta_cache.use_title_block = meta_bool(meta, 'mk623ri-title-block', true)
  meta_cache.uppercase_title = meta_bool(meta, 'mk623ri-uppercase-title', true)
  meta_cache.show_date = meta_bool(meta, 'mk623ri-show-date', false)
  meta_cache.caption_prefixes = meta_bool(meta, 'mk623ri-caption-prefixes', true)

  meta_cache.title = meta_string(meta, 'title')
  meta_cache.authors = meta_list_to_strings(meta.author)
  meta_cache.date = meta_string(meta, 'date')
  meta_cache.udk = meta_string(meta, 'udk') or meta_string(meta, 'УДК')

  if meta_cache.use_title_block then
    -- Suppress pandoc's native title block; it is reconstructed in Pandoc()
    -- with styles that match the МК-623РИ layout and optional UDK support.
    meta.title = nil
    meta.author = nil
    meta.date = nil
  elseif not meta_cache.show_date then
    meta.date = nil
  end

  return meta
end

function Pandoc(doc)
  if not meta_cache.use_title_block then
    return doc
  end

  local blocks = pandoc.List()

  if meta_cache.udk then
    blocks:insert(styled_para(meta_cache.udk:match('^УДК') and meta_cache.udk or ('УДК ' .. meta_cache.udk), 'UDK', true))
  end

  if meta_cache.title then
    local title = meta_cache.title
    if meta_cache.uppercase_title then
      title = pandoc.text.upper(title)
    end
    blocks:insert(styled_para(title, 'Title', false))
  end

  for _, author in ipairs(meta_cache.authors) do
    blocks:insert(styled_para(author, 'Author', false))
  end

  if meta_cache.show_date and meta_cache.date then
    blocks:insert(styled_para(meta_cache.date, 'Date', false))
  end

  if #blocks > 0 then
    blocks:extend(doc.blocks)
    doc.blocks = blocks
  end

  return doc
end

local function prefix_block_caption(caption, label, number)
  local cap_text = trim(stringify(caption))
  if cap_text == '' then
    return caption, false
  end
  if caption_starts_with_label(cap_text, label) then
    return caption, true
  end

  local label_text
  if label == 'рис' then
    label_text = 'Рис.'
  else
    label_text = 'Таблица'
  end

  local prefix = {
    pandoc.Str(label_text), pandoc.Space(), pandoc.Str(tostring(number) .. '.'), pandoc.Space()
  }

  if caption.long == nil or #caption.long == 0 then
    caption.long = pandoc.Blocks({pandoc.Plain(prefix)})
  else
    local first = caption.long[1]
    if first.t == 'Plain' or first.t == 'Para' then
      first.content = prepend_inlines(first.content, prefix)
      caption.long[1] = first
    else
      caption.long:insert(1, pandoc.Plain(prefix))
    end
  end
  return caption, true
end

function Figure(fig)
  if not meta_cache.caption_prefixes then return nil end
  local cap_text = trim(stringify(fig.caption))
  if cap_text == '' then return nil end

  fig_no = fig_no + 1
  fig.caption = prefix_block_caption(fig.caption, 'рис', fig_no)
  return fig
end

function Image(img)
  -- Pandoc 3 represents captioned standalone images as Figure blocks.
  -- This fallback supports older pandoc ASTs where image captions were stored directly on Image.
  if PANDOC_VERSION[1] >= 3 then return nil end
  if not meta_cache.caption_prefixes then return nil end

  local cap_text = trim(stringify(img.caption))
  if cap_text == '' then return nil end

  fig_no = fig_no + 1
  if caption_starts_with_label(cap_text, 'рис') then return nil end

  img.caption = prepend_inlines(img.caption, {
    pandoc.Str('Рис.'), pandoc.Space(), pandoc.Str(tostring(fig_no) .. '.'), pandoc.Space()
  })
  return img
end

function Table(tbl)
  if not meta_cache.caption_prefixes then return nil end

  local cap_text = trim(stringify(tbl.caption))
  if cap_text == '' then
    return nil
  end

  tbl_no = tbl_no + 1
  tbl.caption = prefix_block_caption(tbl.caption, 'таблица', tbl_no)
  return tbl
end

function Para(para)
  if #para.content == 1 and para.content[1].t == 'Math' and para.content[1].mathtype == 'DisplayMath' then
    return pandoc.Div({para}, pandoc.Attr('', {}, {['custom-style'] = 'Formula'}))
  end
  return nil
end
