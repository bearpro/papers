-- Version: 2 (cs/ce/a and author aliases)
-- Expand compact Pandoc DOCX-comment syntax and make comment markers
-- work when they are wrapped in inline-code backticks.
--
-- Long forms supported by Pandoc:
--   [Comment text]{.comment-start author="Михаил Проказин"}text[]{.comment-end}
--   `[Comment text]{.comment-start author="Михаил Проказин"}`text`[]{.comment-end}`
--
-- Compact aliases added by this filter:
--   [Comment text]{.cs a=me}text[]{.ce}
--   `[Comment text]{.cs a=sg}`text`[]{.ce}`
--
-- Inside backticks, an empty marker may also omit []:
--   `[Comment text]{.cs a=me}`text`{.ce}`
--
-- Missing comment IDs are assigned and paired automatically.

local COMMENT_START = "comment-start"
local COMMENT_END = "comment-end"

-- Edit this table to add author aliases.
local AUTHORS = {
  me = "Михаил Проказин",
  sg = "Сергей Головин",
  -- aa = "Анна Авторова",
}

local CLASS_ALIASES = {
  cs = COMMENT_START,
  ce = COMMENT_END,
}

local ATTRIBUTE_ALIASES = {
  a = "author",
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_classes(span)
  local classes = pandoc.List()
  local seen = {}

  for _, class in ipairs(span.classes) do
    local expanded = CLASS_ALIASES[class] or class
    if not seen[expanded] then
      classes:insert(expanded)
      seen[expanded] = true
    end
  end

  span.classes = classes
end

local function normalize_attributes(span)
  local attributes = span.attributes

  for short, long in pairs(ATTRIBUTE_ALIASES) do
    local value = attributes[short]
    if value ~= nil then
      -- An explicitly written long attribute wins over its shorthand.
      if attributes[long] == nil or attributes[long] == "" then
        attributes[long] = value
      end
      attributes[short] = nil
    end
  end

  local author = attributes.author
  if author ~= nil and AUTHORS[author] ~= nil then
    attributes.author = AUTHORS[author]
  end
end

local function normalize_comment_span(span)
  if span.t ~= "Span" then
    return span
  end

  normalize_classes(span)
  normalize_attributes(span)
  return span
end

local function has_class(span, wanted)
  for _, class in ipairs(span.classes) do
    if class == wanted then
      return true
    end
  end
  return false
end

local function comment_kind(span)
  if span.t ~= "Span" then
    return nil
  end

  local is_start = has_class(span, COMMENT_START)
  local is_end = has_class(span, COMMENT_END)

  -- A marker cannot be both a start and an end marker.
  if is_start == is_end then
    return nil
  end

  return is_start and COMMENT_START or COMMENT_END
end

local function parse_single_span(source)
  local ok, fragment = pcall(
    pandoc.read,
    source,
    "markdown+bracketed_spans"
  )

  if not ok or #fragment.blocks ~= 1 then
    return nil
  end

  local block = fragment.blocks[1]
  if block.t ~= "Para" and block.t ~= "Plain" then
    return nil
  end

  if #block.content ~= 1 or block.content[1].t ~= "Span" then
    return nil
  end

  return block.content[1]
end

local function parse_comment_marker(source)
  local compact = trim(source)
  local span = parse_single_span(compact)

  -- Attribute-only markers are not Markdown spans by themselves.
  -- Inside a code span, allow {.ce} as shorthand for []{.ce}; the same
  -- also works for {.cs ...}, producing a comment with empty body text.
  if not span and compact:match("^%b{}$") then
    span = parse_single_span("[]" .. compact)
  end

  if not span then
    return nil
  end

  normalize_comment_span(span)
  local kind = comment_kind(span)
  if not kind then
    return nil
  end

  -- A closing marker must not contain comment text.
  if kind == COMMENT_END and #span.content ~= 0 then
    return nil
  end

  return span
end

local function get_comment_id(span)
  -- Markdown's #id normally becomes Span.identifier.
  if span.identifier and span.identifier ~= "" then
    return span.identifier
  end

  -- Keep compatibility with ASTs that store id as a key/value attribute.
  local id = span.attributes and span.attributes.id
  if id and id ~= "" then
    return id
  end

  return nil
end

local function set_comment_id(span, id)
  span.identifier = id

  -- Keep an existing id key/value attribute synchronized.
  if span.attributes and span.attributes.id ~= nil then
    span.attributes.id = id
  end

  return span
end

local function remove_open_id(open_ids, id)
  for i = #open_ids, 1, -1 do
    if open_ids[i] == id then
      table.remove(open_ids, i)
      return
    end
  end
end

function Pandoc(doc)
  -- Pass 1: turn complete inline-code markers into Spans.
  doc = doc:walk {
    traverse = "topdown",
    Code = function(code)
      local span = parse_comment_marker(code.text)
      if span then
        return span, false
      end
    end,
  }

  -- Pass 2: expand aliases in ordinary bracketed spans too.
  doc = doc:walk {
    traverse = "topdown",
    Span = function(span)
      return normalize_comment_span(span)
    end,
  }

  -- Collect explicit IDs first, so generated numeric IDs cannot collide.
  local used_ids = {}
  doc:walk {
    traverse = "topdown",
    Span = function(span)
      if comment_kind(span) then
        local id = get_comment_id(span)
        if id then
          used_ids[id] = true
        end
      end
    end,
  }

  local next_id = 0
  local function fresh_id()
    while used_ids[tostring(next_id)] do
      next_id = next_id + 1
    end

    local id = tostring(next_id)
    used_ids[id] = true
    next_id = next_id + 1
    return id
  end

  -- Pass 3: pair starts and ends and fill in IDs omitted in Markdown.
  local open_ids = {}
  doc = doc:walk {
    traverse = "topdown",
    Span = function(span)
      local kind = comment_kind(span)
      if not kind then
        return nil
      end

      local id = get_comment_id(span)

      if kind == COMMENT_START then
        if not id then
          id = fresh_id()
          set_comment_id(span, id)
        end
        open_ids[#open_ids + 1] = id
        return span
      end

      -- comment-end
      if not id then
        id = open_ids[#open_ids]
        if id then
          set_comment_id(span, id)
          table.remove(open_ids)
          return span
        end

        -- Leave an unmatched anonymous end marker untouched.
        return nil
      end

      remove_open_id(open_ids, id)
      return span
    end,
  }

  return doc
end
